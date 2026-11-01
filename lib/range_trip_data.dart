import 'dart:convert';

import 'package:flutter/services.dart';

/// 备忘清单一项：preset 为预设项 id（'' = 用户自加项，text 为自填文字）；
/// 预设项显示走 i18n（memo_preset_<id>），中文不写进存储。
class MemoItem {
  String text;
  String preset;
  bool done;

  MemoItem({this.text = '', this.preset = '', this.done = false});

  Map<String, dynamic> toJson() =>
      {'text': text, 'preset': preset, 'done': done};

  factory MemoItem.fromJson(Map<String, dynamic> j) => MemoItem(
        text: j['text'] as String? ?? '',
        preset: j['preset'] as String? ?? '',
        done: j['done'] as bool? ?? false,
      );
}

/// 预设备忘项 id（顺序即默认清单顺序）。
const memoPresetIds = <String>[
  'gun',
  'ammo',
  'mag',
  'ear',
  'eye',
  'target',
  'case',
  'bipod',
  'chrono',
  'tools',
  'cleaning',
  'firstaid',
  'water',
  'id',
];

List<MemoItem> defaultMemoItems() =>
    memoPresetIds.map((id) => MemoItem(preset: id)).toList();

/// 行程本机存取（多页共用：天气快照、传感器填地点、行程页本身）。
/// key 与行程页一致（range_trips_v1），行程页自己的私有存取不动。
const rangeTripsKey = 'range_trips_v1';
const _tripsChannel = MethodChannel('gunsmap/prefs');

Future<List<RangeTrip>> loadRangeTrips() async {
  try {
    final raw = await _tripsChannel
        .invokeMethod<String>('getString', {'key': rangeTripsKey}).timeout(
            const Duration(seconds: 2));
    if (raw == null || raw.isEmpty) return [];
    final list = jsonDecode(raw) as List;
    return list
        .whereType<Map<String, dynamic>>()
        .map(RangeTrip.fromJson)
        .toList();
  } catch (_) {
    return [];
  }
}

Future<void> saveRangeTrips(List<RangeTrip> trips) async {
  try {
    await _tripsChannel.invokeMethod('setString', {
      'key': rangeTripsKey,
      'value': jsonEncode(trips.map((t) => t.toJson()).toList()),
    }).timeout(const Duration(seconds: 2));
  } catch (_) {}
}

/// 靶场行程：一次出行的容器，只包起枪、弹药备注与关联成绩。
/// 行程本身不产生经验、不喂勋章、不重复计分：它只存本机 prefs，
/// 不经过 communityStore 的成绩/勋章逻辑。
class RangeTrip {
  String id;
  int dateMs;
  String place; // '' = 未填
  List<String> gunNames;
  String ammoNote;
  List<String> scoreIds; // 关联的 RangeScore.id
  String note;
  // 2.2.5 备忘清单与系统提醒标记：存在行程模型里，不另起存储。
  // 提醒走系统日历 intent 与系统闹钟 intent，App 不自建通知通道：
  // calendarAdded 只是“已加入日历”标记（intent 方式无可靠回执，
  // 行程改期或删除后日历里的旧事件由用户自己在日历里管）；
  // alarmMs 是上次设闹钟的时间（毫秒，0 = 未设），仅作预填回显。
  List<MemoItem> memoItems;
  bool calendarAdded;
  int alarmMs;

  RangeTrip({
    required this.id,
    required this.dateMs,
    this.place = '',
    List<String>? gunNames,
    this.ammoNote = '',
    List<String>? scoreIds,
    this.note = '',
    List<MemoItem>? memoItems,
    this.calendarAdded = false,
    this.alarmMs = 0,
  })  : gunNames = gunNames ?? [],
        scoreIds = scoreIds ?? [],
        memoItems = memoItems ?? defaultMemoItems();

  /// 已勾选数（列表与详情页显示“备忘 n/m”用）。
  int get memoDone => memoItems.where((m) => m.done).length;

  /// 默认提醒时间：行程前一天晚上 20:00（本地时间）。
  static int defaultReminderMs(int tripDateMs) {
    final d = DateTime.fromMillisecondsSinceEpoch(tripDateMs);
    final base = DateTime(d.year, d.month, d.day, 20);
    return base.subtract(const Duration(days: 1)).millisecondsSinceEpoch;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'dateMs': dateMs,
        'place': place,
        'gunNames': gunNames,
        'ammoNote': ammoNote,
        'scoreIds': scoreIds,
        'note': note,
        'memoItems': memoItems.map((m) => m.toJson()).toList(),
        'calendarAdded': calendarAdded,
        'alarmMs': alarmMs,
      };

  factory RangeTrip.fromJson(Map<String, dynamic> j) {
    List<String> strList(dynamic v) {
      final out = <String>[];
      if (v is List) {
        for (final e in v) {
          if (e is String) out.add(e);
        }
      }
      return out;
    }

    return RangeTrip(
      id: j['id'] as String? ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      dateMs: (j['dateMs'] as num?)?.toInt() ??
          DateTime.now().millisecondsSinceEpoch,
      place: j['place'] as String? ?? '',
      gunNames: strList(j['gunNames']),
      ammoNote: j['ammoNote'] as String? ?? '',
      scoreIds: strList(j['scoreIds']),
      note: j['note'] as String? ?? '',
      // 老行程无 memoItems 字段时默认给整套预设清单（未勾选），不丢数据。
      memoItems: j['memoItems'] == null
          ? defaultMemoItems()
          : (j['memoItems'] as List)
              .whereType<Map<String, dynamic>>()
              .map(MemoItem.fromJson)
              .toList(),
      calendarAdded: j['calendarAdded'] as bool? ?? false,
      alarmMs: (j['alarmMs'] as num?)?.toInt() ?? 0,
    );
  }
}
