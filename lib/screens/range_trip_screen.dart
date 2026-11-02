import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_log.dart';
import '../community_store.dart';
import '../i18n.dart';
import '../range_trip_data.dart';
import '../system_actions.dart';
import '../weather_api.dart';
import '../notify_api.dart';
import '../sensors_api.dart';
import '../location_flow.dart';
import '../widgets/app_toast.dart';
import '../widgets/map_preview.dart';
import '../widgets/app_top_bar.dart';
import 'community_range_screen.dart';
import 'gun_picker_dialog.dart';

/// 靶场行程：一次出行的容器，只包起枪、弹药备注与关联成绩。
/// 经 gunsmap/prefs 存本机（key range_trips_v1），不产生经验、
/// 不喂勋章、不重复计分；成绩仍以靶场成绩页为准，行程只引用。
/// 2.2.5 备忘清单：详情页可勾选/删除/自加，列表项显示“备忘 n/m”；
/// 提醒走系统日历 intent 与系统闹钟 intent，App 不自建通知通道：
/// 删除行程不谎称同步取消系统事件（日历旧事件由用户自己在日历里管）。
String _dateText(int ms) {
  final d = DateTime.fromMillisecondsSinceEpoch(ms);
  return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

class RangeTripScreen extends StatefulWidget {
  const RangeTripScreen({super.key});

  @override
  State<RangeTripScreen> createState() => _RangeTripScreenState();
}

class _RangeTripScreenState extends State<RangeTripScreen> {
  static const _prefsChannel = MethodChannel('gunsmap/prefs');
  static const _tripsKey = 'range_trips_v1';
  final _trips = <RangeTrip>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final raw = await _prefsChannel
          .invokeMethod<String>('getString', {'key': _tripsKey})
          .timeout(const Duration(seconds: 2));
      if (raw != null && raw.isNotEmpty && mounted) {
        final list = (jsonDecode(raw) as List)
            .map((e) => RangeTrip.fromJson(e as Map<String, dynamic>))
            .toList();
        list.sort((a, b) => b.dateMs.compareTo(a.dateMs));
        setState(() {
          _trips
            ..clear()
            ..addAll(list);
        });
      }
    } catch (e) {
      appLog('prefs', '靶场行程读取失败：$e');
    }
  }

  void _save() {
    try {
      _prefsChannel.invokeMethod('setString', {
        'key': _tripsKey,
        'value': jsonEncode(_trips.map((e) => e.toJson()).toList()),
      });
    } catch (e) {
      appLog('prefs', '靶场行程保存失败：$e');
    }
  }

  Future<void> _openAdd() async {
    final result = await Navigator.push<RangeTrip>(
      context,
      MaterialPageRoute(builder: (_) => const RangeTripAddPage()),
    );
    if (result != null && mounted) {
      setState(() {
        _trips.insert(0, result);
        _trips.sort((a, b) => b.dateMs.compareTo(a.dateMs));
      });
      _save();
      showAppToast(context, tr('chrono_saved'));
    }
  }

  Future<void> _confirmDelete(RangeTrip t) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(tr('trip_delete_confirm')),
        content: t.calendarAdded
            ? Text(tr('trip_delete_calendar_note'))
            : null,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(tr('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(tr('trip_delete')),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      if (t.notifyEnabled) await cancelTripNotification(t.notifyId);
      setState(() => _trips.remove(t));
      _save();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: localeNotifier,
      builder: (_, __, ___) => Scaffold(
        appBar: SubPageAppBar(title: tr('trip_title')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(tr('trip_note'),
                style: const TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _openAdd,
              icon: const Icon(Icons.add_outlined, size: 18),
              label: Text(tr('trip_add')),
            ),
            const SizedBox(height: 8),
            if (_trips.isEmpty)
              Text(tr('trip_list_empty'),
                  style: const TextStyle(color: Colors.grey))
            else
              ..._trips.map((t) => Card(
                    child: ListTile(
                      title: Text(
                          '${_dateText(t.dateMs)}${t.place.isNotEmpty ? ' · ${t.place}' : ''}'),
                      subtitle: Text(
                          '${tr('trip_guns')} ${t.gunNames.length} · ${tr('trip_scores')} ${t.scoreIds.length} · ${tr('trip_memo_progress')} ${t.memoDone}/${t.memoItems.length}'),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _confirmDelete(t),
                      ),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => RangeTripDetailScreen(
                                  trip: t,
                                  onChanged: () {
                                    _save();
                                    if (mounted) setState(() {});
                                  },
                                )),
                      ),
                    ),
                  )),
          ],
        ),
      ),
    );
  }
}

/// 行程详情：行程信息 + 被关联的成绩（按 id 从当前靶场成绩里找，
/// 已删除的成绩只计条数、不显示）+ 备忘清单 + 提醒（系统闹钟 /
/// 系统日历 / App 通知三选项并列）+ 指南针射向。
/// 备忘改动直接改 trip 对象（与列表页同一实例），再经 onChanged 回写。
class RangeTripDetailScreen extends StatefulWidget {
  final RangeTrip trip;
  final VoidCallback onChanged;
  const RangeTripDetailScreen(
      {super.key, required this.trip, required this.onChanged});

  @override
  State<RangeTripDetailScreen> createState() =>
      _RangeTripDetailScreenState();
}

class _RangeTripDetailScreenState extends State<RangeTripDetailScreen> {
  final _memoCtrl = TextEditingController();

  @override
  void dispose() {
    _memoCtrl.dispose();
    super.dispose();
  }

  String _memoLabel(MemoItem m) =>
      m.preset.isNotEmpty ? tr('memo_preset_${m.preset}') : m.text;

  void _addCustomMemo() {
    final text = _memoCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() {
      widget.trip.memoItems.add(MemoItem(text: text));
      _memoCtrl.clear();
    });
    widget.onChanged();
  }

  /// 加入系统日历：全天事件（当天 00:00 至次日 00:00），标题=地点
  /// 或“靶场行程”，描述带枪/弹药与备忘进度；跳到用户自己的日历 App
  /// 里由用户确认。成功只记 calendarAdded 标记；无日历 App 接 intent
  /// 时给可读提示。App 不追踪日历事件 ID。
  Future<void> _addCalendar() async {
    final t = widget.trip;
    final d = DateTime.fromMillisecondsSinceEpoch(t.dateMs);
    final begin = DateTime(d.year, d.month, d.day);
    final end = begin.add(const Duration(days: 1));
    final title = t.place.isNotEmpty ? t.place : tr('trip_title');
    final desc = [
      if (t.gunNames.isNotEmpty)
        '${tr('trip_guns')} ${t.gunNames.join(tr('trip_list_sep'))}',
      if (t.ammoNote.isNotEmpty) '${tr('trip_ammo')} ${t.ammoNote}',
      '${tr('trip_memo_progress')} ${t.memoDone}/${t.memoItems.length}',
    ].join('\n');
    final ok = await addCalendarEvent(
      title: title,
      beginMs: begin.millisecondsSinceEpoch,
      endMs: end.millisecondsSinceEpoch,
      description: desc,
    );
    if (!mounted) return;
    if (ok) {
      setState(() => t.calendarAdded = true);
      widget.onChanged();
      showAppToast(context, tr('chrono_saved'));
    } else {
      showAppToast(context, tr('trip_calendar_failed'));
    }
  }

  /// 设闹钟提醒：先弹时间选择器（默认行程前一天 20:00，已设过则预填
  /// 上次时间），再跳系统时钟 App 预填时间与文案（行程名 + 未带数）
  /// 由用户确认；无时钟 App 接 intent 时给可读提示。
  Future<void> _setAlarm() async {
    final t = widget.trip;
    final base = t.alarmMs > 0
        ? DateTime.fromMillisecondsSinceEpoch(t.alarmMs)
        : DateTime.fromMillisecondsSinceEpoch(
            RangeTrip.defaultReminderMs(t.dateMs));
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: base.hour, minute: base.minute),
    );
    if (picked == null || !mounted) return;
    final d = DateTime.fromMillisecondsSinceEpoch(t.dateMs);
    final alarmDay =
        DateTime(d.year, d.month, d.day).subtract(const Duration(days: 1));
    final alarmMs = DateTime(alarmDay.year, alarmDay.month, alarmDay.day,
            picked.hour, picked.minute)
        .millisecondsSinceEpoch;
    final unpacked = t.memoItems.where((m) => !m.done).length;
    final title = t.place.isNotEmpty ? t.place : tr('trip_title');
    final message =
        '$title · ${tr('trip_alarm_unpacked_prefix')}$unpacked${tr('trip_alarm_unpacked_suffix')}';
    final ok = await setAlarmClock(
        hour: picked.hour, minute: picked.minute, message: message);
    if (!mounted) return;
    if (ok) {
      setState(() => t.alarmMs = alarmMs);
      widget.onChanged();
      showAppToast(context, tr('chrono_saved'));
    } else {
      showAppToast(context, tr('trip_alarm_failed'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final trip = widget.trip;
    final scores = communityStore.current?.rangeScores ?? [];
    final byId = <String, RangeScore>{};
    for (final s in scores) {
      byId[s.id] = s;
    }
    final linked = <RangeScore>[];
    var missing = 0;
    for (final id in trip.scoreIds) {
      final s = byId[id];
      if (s == null) {
        missing++;
      } else {
        linked.add(s);
      }
    }
    return ValueListenableBuilder<String>(
      valueListenable: localeNotifier,
      builder: (_, __, ___) => Scaffold(
        appBar: SubPageAppBar(title: tr('trip_detail')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
                _dateText(trip.dateMs) +
                    (trip.startMs > 0
                        ? ' ${_timeText(trip.startMs)}'
                        : ''),
                style:
                    const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            if (trip.place.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(trip.place),
              Builder(
                builder: (_) {
                  final coords = parseLatLon(trip.place);
                  if (coords == null) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: MapPreview(lat: coords.lat, lon: coords.lon),
                  );
                },
              ),
            ],
            if (trip.gunNames.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                  '${tr('trip_guns')} ${trip.gunNames.join(tr('trip_list_sep'))}'),
            ],
            if (trip.ammoNote.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('${tr('trip_ammo')} ${trip.ammoNote}'),
            ],
            if (trip.note.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(trip.note,
                  style: const TextStyle(color: Colors.grey)),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(trip.heading.isEmpty
                      ? tr('trip_heading')
                      : '${tr('trip_heading')} ${trip.heading}'),
                ),
                OutlinedButton(
                  onPressed: _recordHeading,
                  child: Text(tr('trip_record_heading')),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(tr('trip_scores'),
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.bold)),
                ),
                OutlinedButton.icon(
                  onPressed: () async {
                    if (communityStore.current == null) {
                      showAppToast(
                          context, tr('login_required_body'));
                      return;
                    }
                    final result =
                        await showScoreDialog(context, presetTrip: trip);
                    if (result == null || !mounted) return;
                    await handleSavedScore(context, result,
                        tripLink: trip, onTripChanged: widget.onChanged);
                    if (mounted) setState(() {});
                  },
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(tr('trip_add_score')),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (linked.isEmpty && missing == 0)
              Text(tr('trip_scores_empty'),
                  style: const TextStyle(color: Colors.grey))
            else ...[
              ...linked.map((s) => Card(
                    child: ListTile(
                      title: Text(
                          '${s.gunName} · ${s.distance} ${tr('trip_meter')}'),
                      subtitle: Text(
                          '${s.shots} ${tr('trip_shots_unit')} · ${tr('trip_group_label')} ${s.groupSize.toStringAsFixed(1)} ${tr('trip_cm')}${s.score.isNotEmpty ? ' · ${s.score}' : ''}'),
                    ),
                  )),
              if (missing > 0)
                Text('$missing ${tr('trip_scores_missing')}',
                    style: const TextStyle(color: Colors.grey, fontSize: 12)),
            ],
            const SizedBox(height: 16),
            Text(
                '${tr('trip_memo')} ${tr('trip_memo_progress')} ${trip.memoDone}/${trip.memoItems.length}',
                style:
                    const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...trip.memoItems.map((m) => CheckboxListTile(
                  dense: true,
                  title: Text(_memoLabel(m)),
                  value: m.done,
                  secondary: IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20),
                    onPressed: () {
                      setState(() => trip.memoItems.remove(m));
                      widget.onChanged();
                    },
                  ),
                  onChanged: (v) {
                    setState(() => m.done = v == true);
                    widget.onChanged();
                  },
                )),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _memoCtrl,
                    onSubmitted: (_) => _addCustomMemo(),
                    decoration: InputDecoration(
                      hintText: tr('trip_memo_add_hint'),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: _addCustomMemo,
                  child: Text(tr('trip_memo_add')),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(tr('trip_reminder'),
                style:
                    const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            InkWell(
              onTap: _pickReminderTime,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                        '${tr('trip_reminder_time')} ${_reminderText()}'),
                  ),
                  const Icon(Icons.edit, size: 16),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _setAlarm,
                    icon: const Icon(Icons.alarm_outlined, size: 18),
                    label: Text(tr('trip_set_alarm')),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _addCalendar,
                    icon: const Icon(Icons.calendar_month_outlined, size: 18),
                    label: Text(trip.calendarAdded
                        ? tr('trip_calendar_added')
                        : tr('trip_add_calendar')),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _toggleNotify,
                    icon:
                        const Icon(Icons.notifications_outlined, size: 18),
                    label: Text(trip.notifyEnabled
                        ? tr('trip_notify_on')
                        : tr('trip_notify')),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _timeText(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  /// 提醒时刻文案：已设用已设值，未设用默认（行程前一天 20:00）。
  String _reminderText() {
    final t = widget.trip;
    final ms = t.reminderMs > 0 ? t.reminderMs : RangeTrip.defaultReminderMs(t.dateMs);
    return CommunityStore.formatTime(DateTime.fromMillisecondsSinceEpoch(ms));
  }

  String _notifyTitle(RangeTrip t) =>
      t.place.isNotEmpty ? t.place : _dateText(t.dateMs);

  /// App 通知正文：与系统闹钟同一口径（未带备忘数 / 全部已勾选）。
  String _notifyBody(RangeTrip t) {
    final unpacked = t.memoItems.where((m) => !m.done).length;
    return unpacked > 0
        ? '${tr('trip_alarm_unpacked_prefix')}$unpacked${tr('trip_alarm_unpacked_suffix')}'
        : tr('trip_alarm_all_packed');
  }

  /// 指南针记射向：读数成功写入行程，失败只给提示。
  Future<void> _recordHeading() async {
    final r = await getCompassHeading();
    if (!mounted) return;
    if (r.value != null) {
      final deg = r.value!;
      setState(() =>
          widget.trip.heading = '${deg.toStringAsFixed(0)}° ${compassDir(deg)}');
      widget.onChanged();
      showAppToast(context, tr('trip_heading_saved'));
    } else {
      showAppToast(context, tr('trip_heading_failed'));
    }
  }

  /// 改提醒时间：只改时刻（日期沿用原提醒日期）；App 通知已开时
  /// 取消旧通知、按新时刻重设，失败则关掉开关并提示。
  Future<void> _pickReminderTime() async {
    final t = widget.trip;
    final base = DateTime.fromMillisecondsSinceEpoch(
        t.reminderMs > 0 ? t.reminderMs : RangeTrip.defaultReminderMs(t.dateMs));
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(base),
    );
    if (picked == null || !mounted) return;
    final next = DateTime(base.year, base.month, base.day, picked.hour,
            picked.minute)
        .millisecondsSinceEpoch;
    final wasOn = t.notifyEnabled;
    if (wasOn) await cancelTripNotification(t.notifyId);
    t.reminderMs = next;
    if (wasOn) {
      final ok = await scheduleTripNotification(
        id: t.notifyId,
        title: _notifyTitle(t),
        body: _notifyBody(t),
        timeMs: next,
      );
      if (!ok) {
        t.notifyEnabled = false;
        showAppToast(context, tr('trip_notify_failed'));
      }
    }
    setState(() {});
    widget.onChanged();
  }

  /// App 通知开关：开时先要通知权限（被拒只给提示），按提醒时刻设
  /// AlarmManager 通知；关时取消已设通知与通知栏同条。
  Future<void> _toggleNotify() async {
    final t = widget.trip;
    if (t.notifyEnabled) {
      await cancelTripNotification(t.notifyId);
      if (!mounted) return;
      setState(() => t.notifyEnabled = false);
      widget.onChanged();
      showAppToast(context, tr('trip_notify_off'));
      return;
    }
    final granted = await ensureNotifyPermission();
    if (!mounted) return;
    if (!granted) {
      showAppToast(context, tr('trip_notify_denied'));
      return;
    }
    final when =
        t.reminderMs > 0 ? t.reminderMs : RangeTrip.defaultReminderMs(t.dateMs);
    final ok = await scheduleTripNotification(
      id: t.notifyId,
      title: _notifyTitle(t),
      body: _notifyBody(t),
      timeMs: when,
    );
    if (!mounted) return;
    if (!ok) {
      showAppToast(context, tr('trip_notify_failed'));
      return;
    }
    setState(() {
      t.notifyEnabled = true;
      t.reminderMs = when;
    });
    widget.onChanged();
    showAppToast(context, tr('trip_notify_on'));
  }
}

/// 新增行程：日期 + 地点 + 带的枪（选枪加入）+ 弹药备注 +
/// 从已有靶场成绩里多选关联 + 备注。
class RangeTripAddPage extends StatefulWidget {
  const RangeTripAddPage({super.key});

  @override
  State<RangeTripAddPage> createState() => _RangeTripAddPageState();
}

class _RangeTripAddPageState extends State<RangeTripAddPage> {
  final _placeCtrl = TextEditingController();
  final _ammoCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final _guns = <String>[];
  final _scoreIds = <String>{};
  String _date = '';
  TimeOfDay? _time;
  bool _locating = false;
  ({double lat, double lon})? _locCoords;
  String? _locName;

  /// 地点栏改动时：手动填了经纬度就跟手填的走；改成别的文字且
  /// 不是定位填的地名时，丢掉旧定位，避免预览停留在旧坐标上。
  void _onPlaceChanged() {
    final text = _placeCtrl.text.trim();
    if (_locCoords != null &&
        text != _locName &&
        parseLatLon(text) == null) {
      _locCoords = null;
      _locName = null;
    }
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _date =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    _placeCtrl.addListener(_onPlaceChanged);
  }

  @override
  void dispose() {
    _placeCtrl.dispose();
    _ammoCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final initial = DateTime.tryParse(_date) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null) return;
    setState(() {
      _date =
          '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
    });
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time ?? const TimeOfDay(hour: 9, minute: 0),
    );
    if (picked == null) return;
    setState(() => _time = picked);
  }

  /// 定位填地点：拉系统授权（用途说明 + 拒绝后去设置入口），
  /// 成功后填地名（反查不到回落经纬度），并在下方显示地图预览。
  Future<void> _locate() async {
    if (_locating) return;
    setState(() => _locating = true);
    try {
      final ok = await ensureLocationPermission(context);
      if (!mounted) return;
      if (!ok) return;
      final pos = await fetchCurrentFix();
      if (!mounted) return;
      final fix = pos.value;
      if (fix == null) {
        showAppToast(context, tr(locErrorKey(pos.error)));
        return;
      }
      final name = await reverseGeocode(fix.latitude, fix.longitude);
      if (!mounted) return;
      final text = name ??
          '${fix.latitude.toStringAsFixed(5)}, ${fix.longitude.toStringAsFixed(5)}';
      setState(() {
        _locCoords = (lat: fix.latitude, lon: fix.longitude);
        _locName = text;
        _placeCtrl.text = text;
      });
      showAppToast(context, tr('trip_located'));
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _addGun() async {
    final gun = await showGunPickerDialog(context);
    if (gun == null || !mounted) return;
    if (!_guns.contains(gun.name)) {
      setState(() => _guns.add(gun.name));
    }
  }

  void _save() {
    final date = DateTime.tryParse(_date) ?? DateTime.now();
    final startMs = _time == null
        ? 0
        : DateTime(date.year, date.month, date.day, _time!.hour,
                _time!.minute)
            .millisecondsSinceEpoch;
    Navigator.of(context).pop(RangeTrip(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      dateMs: date.millisecondsSinceEpoch,
      startMs: startMs,
      place: _placeCtrl.text.trim(),
      gunNames: List.of(_guns),
      ammoNote: _ammoCtrl.text.trim(),
      scoreIds: _scoreIds.toList(),
      note: _noteCtrl.text.trim(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final scores = communityStore.current?.rangeScores ?? [];
    return ValueListenableBuilder<String>(
      valueListenable: localeNotifier,
      builder: (_, __, ___) => Scaffold(
        appBar: SubPageAppBar(title: tr('trip_add')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            InkWell(
              onTap: _pickDate,
              child: InputDecorator(
                decoration: InputDecoration(labelText: tr('trip_date')),
                child: Text(_date),
              ),
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: _pickTime,
              child: InputDecorator(
                decoration: InputDecoration(labelText: tr('trip_time')),
                child: Text(_time == null
                    ? ''
                    : '${_time!.hour.toString().padLeft(2, '0')}:${_time!.minute.toString().padLeft(2, '0')}'),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _placeCtrl,
                    decoration:
                        InputDecoration(labelText: tr('trip_place')),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: _locating ? null : _locate,
                  child: _locating
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child:
                              CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(tr('trip_locate')),
                ),
              ],
            ),
            Builder(
              builder: (_) {
                final text = _placeCtrl.text.trim();
                final coords = text.isEmpty
                    ? null
                    : (parseLatLon(text) ?? _locCoords);
                if (coords == null) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: MapPreview(
                    lat: coords.lat,
                    lon: coords.lon,
                    showLabel: false,
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            Text(tr('trip_guns'),
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            OutlinedButton.icon(
              onPressed: _addGun,
              icon: const Icon(Icons.add_outlined, size: 18),
              label: Text(tr('trip_add_gun')),
            ),
            ..._guns.map((g) => ListTile(
                  dense: true,
                  title: Text(g),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20),
                    onPressed: () => setState(() => _guns.remove(g)),
                  ),
                )),
            const SizedBox(height: 12),
            TextField(
              controller: _ammoCtrl,
              decoration: InputDecoration(labelText: tr('trip_ammo')),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _noteCtrl,
              decoration: InputDecoration(
                  labelText: tr('chrono_note_label')),
            ),
            const SizedBox(height: 16),
            Text(tr('trip_scores'),
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            if (scores.isEmpty)
              Text(tr('trip_scores_none'),
                  style: const TextStyle(color: Colors.grey))
            else
              ...scores.map((s) => CheckboxListTile(
                    dense: true,
                    title: Text(
                        '${s.gunName} · ${s.distance} ${tr('trip_meter')}'),
                    subtitle: Text(
                        '${s.shots} ${tr('trip_shots_unit')} · ${tr('trip_group_label')} ${s.groupSize.toStringAsFixed(1)} ${tr('trip_cm')}'),
                    value: _scoreIds.contains(s.id),
                    onChanged: (v) {
                      setState(() {
                        if (v == true) {
                          _scoreIds.add(s.id);
                        } else {
                          _scoreIds.remove(s.id);
                        }
                      });
                    },
                  )),
            const SizedBox(height: 16),
            FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFE86A1C)),
              onPressed: _save,
              child: Text(tr('chrono_confirm_save'),
                  style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}
