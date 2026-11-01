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

  RangeTrip({
    required this.id,
    required this.dateMs,
    this.place = '',
    List<String>? gunNames,
    this.ammoNote = '',
    List<String>? scoreIds,
    this.note = '',
  })  : gunNames = gunNames ?? [],
        scoreIds = scoreIds ?? [];

  Map<String, dynamic> toJson() => {
        'id': id,
        'dateMs': dateMs,
        'place': place,
        'gunNames': gunNames,
        'ammoNote': ammoNote,
        'scoreIds': scoreIds,
        'note': note,
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
    );
  }
}
