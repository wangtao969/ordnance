import 'dart:math' as math;

/// 测速记录 + AB 存档的数据模型与 CSV 解析。
/// 只记实测速度与 AB 原文存档，不做任何弹道计算、不插值、不推算。

String chronoNewId() =>
    DateTime.now().microsecondsSinceEpoch.toString();

class ChronoSession {
  String id;
  String gunName;
  int dateMs;
  List<double> velocities;
  String unit; // 'fps' 或 'm/s'
  String note;
  String source; // 如 'CSV导入' / '手动录入'

  ChronoSession({
    required this.id,
    required this.gunName,
    required this.dateMs,
    required this.velocities,
    this.unit = 'fps',
    this.note = '',
    this.source = '',
  });

  int get count => velocities.length;

  double get avg {
    if (velocities.isEmpty) return 0;
    var sum = 0.0;
    for (final v in velocities) {
      sum += v;
    }
    return sum / velocities.length;
  }

  /// 样本标准差：分母 n-1；发数不足 2 时不算，返回 null，界面显示“—”。
  double? get sd {
    if (velocities.length < 2) return null;
    final m = avg;
    var sum = 0.0;
    for (final v in velocities) {
      sum += (v - m) * (v - m);
    }
    return math.sqrt(sum / (velocities.length - 1));
  }

  double get es {
    if (velocities.isEmpty) return 0;
    var lo = velocities.first;
    var hi = velocities.first;
    for (final v in velocities) {
      if (v < lo) lo = v;
      if (v > hi) hi = v;
    }
    return hi - lo;
  }

  double get minV {
    if (velocities.isEmpty) return 0;
    var lo = velocities.first;
    for (final v in velocities) {
      if (v < lo) lo = v;
    }
    return lo;
  }

  double get maxV {
    if (velocities.isEmpty) return 0;
    var hi = velocities.first;
    for (final v in velocities) {
      if (v > hi) hi = v;
    }
    return hi;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'gunName': gunName,
        'dateMs': dateMs,
        'velocities': velocities,
        'unit': unit,
        'note': note,
        'source': source,
      };

  factory ChronoSession.fromJson(Map<String, dynamic> j) {
    final rawList = j['velocities'] as List?;
    final vs = <double>[];
    if (rawList != null) {
      for (final e in rawList) {
        final d = (e as num?)?.toDouble();
        if (d != null) vs.add(d);
      }
    }
    return ChronoSession(
      id: j['id'] as String? ?? chronoNewId(),
      gunName: j['gunName'] as String? ?? '',
      dateMs: (j['dateMs'] as num?)?.toInt() ??
          DateTime.now().millisecondsSinceEpoch,
      velocities: vs,
      unit: j['unit'] as String? ?? 'fps',
      note: j['note'] as String? ?? '',
      source: j['source'] as String? ?? '',
    );
  }
}

/// AB 存档：只存 AB Quantum 导出的原文，不解析、不计算、不重绘。
class ABArchive {
  String id;
  String title;
  String gunName; // 可空，空 = 不绑枪
  int dateMs;
  String rawText;

  ABArchive({
    required this.id,
    required this.title,
    this.gunName = '',
    required this.dateMs,
    required this.rawText,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'gunName': gunName,
        'dateMs': dateMs,
        'rawText': rawText,
      };

  factory ABArchive.fromJson(Map<String, dynamic> j) => ABArchive(
        id: j['id'] as String? ?? chronoNewId(),
        title: j['title'] as String? ?? '',
        gunName: j['gunName'] as String? ?? '',
        dateMs: (j['dateMs'] as num?)?.toInt() ??
            DateTime.now().millisecondsSinceEpoch,
        rawText: j['rawText'] as String? ?? '',
      );
}

class ChronoCsvResult {
  final List<double> velocities;
  final int skippedNonNumeric;
  final int skippedOutOfRange;
  final bool hasHeader;
  const ChronoCsvResult({
    required this.velocities,
    required this.skippedNonNumeric,
    required this.skippedOutOfRange,
    required this.hasHeader,
  });

  int get skipped => skippedNonNumeric + skippedOutOfRange;
}

/// 测速仪 CSV 解析（宽容版）：
/// - 去 BOM；分隔符支持逗号、分号、制表符（按首个非空行含字段最多的判定）；
/// - 跳过空行；表头行含 velocity|speed|fps|m/s|速度 之一时跳过该行，
///   并用表头定位速度列，否则每行取第一个能解析的数值；
/// - 速度只收 50–5000 区间内的数，其余行计入跳过数（分非数字 / 超范围两类）。
/// 单位不在这里换算：速度按导入页用户选的单位原样存。
ChronoCsvResult parseChronoCsv(String raw) {
  var text = raw;
  if (text.startsWith('\uFEFF')) text = text.substring(1);
  final lines = text.split(RegExp(r'\r\n|\n|\r'));
  final rows = <String>[];
  for (final l in lines) {
    if (l.trim().isNotEmpty) rows.add(l);
  }
  if (rows.isEmpty) {
    return const ChronoCsvResult(
        velocities: [],
        skippedNonNumeric: 0,
        skippedOutOfRange: 0,
        hasHeader: false);
  }

  String delimiter(String line) {
    var best = ',';
    var bestCount = 0;
    for (final d in ['\t', ';', ',']) {
      final c = line.split(d).length;
      if (c > bestCount) {
        bestCount = c;
        best = d;
      }
    }
    return best;
  }

  final delim = delimiter(rows.first);
  final headerRe = RegExp(r'velocity|speed|fps|m/s|速度', caseSensitive: false);
  var start = 0;
  var hasHeader = false;
  var velocityCol = -1;
  final firstCells = rows.first.split(delim);
  if (headerRe.hasMatch(rows.first)) {
    hasHeader = true;
    start = 1;
    for (var i = 0; i < firstCells.length; i++) {
      if (headerRe.hasMatch(firstCells[i].trim())) {
        velocityCol = i;
        break;
      }
    }
  }

  final velocities = <double>[];
  var skippedNonNumeric = 0;
  var skippedOutOfRange = 0;
  for (var i = start; i < rows.length; i++) {
    final cells = rows[i].split(delim);
    double? value;
    if (velocityCol >= 0) {
      if (velocityCol < cells.length) {
        value = double.tryParse(cells[velocityCol].trim());
      }
    } else {
      for (final c in cells) {
        value = double.tryParse(c.trim());
        if (value != null) break;
      }
    }
    if (value == null) {
      skippedNonNumeric++;
      continue;
    }
    if (value < 50 || value > 5000) {
      skippedOutOfRange++;
      continue;
    }
    velocities.add(value);
  }
  return ChronoCsvResult(
    velocities: velocities,
    skippedNonNumeric: skippedNonNumeric,
    skippedOutOfRange: skippedOutOfRange,
    hasHeader: hasHeader,
  );
}
