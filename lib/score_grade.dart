import 'dart:math' as math;

/// 靶场成绩档位与散布换算（纯函数，不依赖界面）：
/// 档位只看可测数据——散布 MOA；不做主观评价，不引外部标准，
/// 区间是本应用自定档位，界面上公开说明。
/// 散布 = 弹着点间最大距离（落点图）或手填分组（厘米）；
/// 1 MOA ≈ 距离米 × 0.02909 厘米，1 密位 = 距离米 × 0.1 厘米
/// （与靶场换算页同一公式）。

const double scoreMoaCmPerMeter = 0.02909;

double spreadMoa(double spreadCm, int distanceM) {
  if (distanceM <= 0 || spreadCm <= 0) return 0;
  return spreadCm / (distanceM * scoreMoaCmPerMeter);
}

double spreadMil(double spreadCm, int distanceM) {
  if (distanceM <= 0 || spreadCm <= 0) return 0;
  return spreadCm / (distanceM * 0.1);
}

/// 落点图散布（厘米）：弹着点（归一化坐标 [-1,1]）间最大距离换算。
/// 靶纸 5 环，每环一步 = gridCm 厘米，半径 = 5 × gridCm 厘米，
/// 故归一化距离 1.0 对应 5 × gridCm 厘米。
double plotSpreadCm(List<List<double>> points, double gridCm) {
  if (points.length < 2 || gridCm <= 0) return 0;
  var maxSq = 0.0;
  for (var i = 0; i < points.length; i++) {
    for (var j = i + 1; j < points.length; j++) {
      final dx = points[i][0] - points[j][0];
      final dy = points[i][1] - points[j][1];
      final sq = dx * dx + dy * dy;
      if (sq > maxSq) maxSq = sq;
    }
  }
  return math.sqrt(maxSq) * 5 * gridCm;
}

/// 有效散布：有落点图（≥2 点）时以落点图为准，否则用手填分组。
double effectiveSpreadCm({
  required List<List<double>> points,
  required double gridCm,
  required double groupSize,
}) =>
    points.length >= 2
        ? plotSpreadCm(points, gridCm)
        : groupSize;

/// 档位区间（本应用自定）：S ≤1 MOA，A ≤2，B ≤3，C ≤5，D >5。
String? gradeForMoa(double moa) {
  if (moa <= 0) return null;
  if (moa <= 1) return 'S';
  if (moa <= 2) return 'A';
  if (moa <= 3) return 'B';
  if (moa <= 5) return 'C';
  return 'D';
}

/// 成绩档位：3 发以下样本不足（返回 null，调用方单独提示）；
/// 无散布也返回 null（无档）。
String? gradeForScore({
  required int shots,
  required int distance,
  required double groupSize,
  required List<List<double>> points,
  required double gridCm,
}) {
  if (shots < 3) return null;
  final cm = effectiveSpreadCm(
      points: points, gridCm: gridCm, groupSize: groupSize);
  if (cm <= 0) return null;
  return gradeForMoa(spreadMoa(cm, distance));
}
