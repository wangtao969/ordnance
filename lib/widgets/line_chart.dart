import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme_accent.dart';

/// 速度-发数折线图：CustomPaint 手画，零第三方包，仿 bar_chart.dart 写法。
/// 只画传入的实测速度序列，不读任何存储；空数据时父级不渲染本组件。
/// 纵轴按数据范围加留白（不从 0 起，否则高速段会被压成一条直线）。
class VelocityLineChart extends StatelessWidget {
  final List<double> values;
  final String unit;
  final double height;
  const VelocityLineChart({
    super.key,
    required this.values,
    required this.unit,
    this.height = 220,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return ValueListenableBuilder<Color>(
      valueListenable: accentNotifier,
      builder: (_, accent, __) {
        return CustomPaint(
          size: Size(double.infinity, height),
          painter: _VelocityLinePainter(
            values: values,
            unit: unit,
            lineColor: dark ? lightenedAccent(accent) : accent,
            dotColor: dark ? lightenedAccent(accent) : accent,
            labelColor:
                dark ? const Color(0xFFB8B2A4) : const Color(0xFF6B655A),
            gridColor: dark
                ? Colors.white.withValues(alpha: 0.12)
                : Colors.black.withValues(alpha: 0.08),
            axisColor: dark
                ? Colors.white.withValues(alpha: 0.25)
                : Colors.black.withValues(alpha: 0.25),
          ),
        );
      },
    );
  }
}

class _VelocityLinePainter extends CustomPainter {
  final List<double> values;
  final String unit;
  final Color lineColor;
  final Color dotColor;
  final Color labelColor;
  final Color gridColor;
  final Color axisColor;

  const _VelocityLinePainter({
    required this.values,
    required this.unit,
    required this.lineColor,
    required this.dotColor,
    required this.labelColor,
    required this.gridColor,
    required this.axisColor,
  });

  static const _leftPad = 46.0;
  static const _rightPad = 8.0;
  static const _topPad = 20.0;
  static const _bottomPad = 24.0;

  String _axisLabel(double v) {
    final s = v.toStringAsFixed(0);
    return s;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final plotW = size.width - _leftPad - _rightPad;
    final plotH = size.height - _topPad - _bottomPad;
    if (plotW <= 0 || plotH <= 0) return;

    var lo = values.first;
    var hi = values.first;
    for (final v in values) {
      if (v < lo) lo = v;
      if (v > hi) hi = v;
    }
    var span = hi - lo;
    if (span <= 0) span = 10;
    final pad = math.max(span * 0.15, 5);
    final minV = lo - pad;
    final maxV = hi + pad;
    final range = maxV - minV;

    double yOf(double v) => _topPad + plotH - (v - minV) / range * plotH;
    double xOf(int i) => values.length == 1
        ? _leftPad + plotW / 2
        : _leftPad + plotW * i / (values.length - 1);

    // 网格线 + 左侧刻度：0、1/3、2/3、最大值四档。
    final gridPaint = Paint()..color = gridColor..strokeWidth = 1;
    for (var i = 0; i <= 3; i++) {
      final v = minV + range * i / 3;
      final y = yOf(v);
      canvas.drawLine(Offset(_leftPad, y), Offset(size.width - _rightPad, y),
          gridPaint);
      _drawText(canvas, _axisLabel(v), Offset(_leftPad - 4, y - 7),
          labelColor, 11,
          rightAlign: true);
    }
    // 基线与单位。
    final axisPaint = Paint()..color = axisColor..strokeWidth = 1;
    final baseY = _topPad + plotH;
    canvas.drawLine(Offset(_leftPad, baseY), Offset(size.width - _rightPad, baseY),
        axisPaint);
    _drawText(canvas, unit, Offset(size.width - _rightPad, _topPad - 16),
        labelColor, 11,
        rightAlign: true);

    // 折线。
    if (values.length > 1) {
      final path = Path()..moveTo(xOf(0), yOf(values.first));
      for (var i = 1; i < values.length; i++) {
        path.lineTo(xOf(i), yOf(values[i]));
      }
      canvas.drawPath(
          path,
          Paint()
            ..color = lineColor
            ..strokeWidth = 2
            ..style = PaintingStyle.stroke
            ..strokeJoin = StrokeJoin.round);
    }
    // 数据点。
    final dotPaint = Paint()..color = dotColor;
    for (var i = 0; i < values.length; i++) {
      canvas.drawCircle(Offset(xOf(i), yOf(values[i])), 3.5, dotPaint);
    }
    // 横轴发数标签：拥挤时隔行显示，不重叠。
    final stride = math.max(
        1, ((28.0 * values.length) / plotW).ceil());
    for (var i = 0; i < values.length; i++) {
      if (i % stride != 0 && i != values.length - 1) continue;
      final label = '${i + 1}';
      final w = _measure(label, 11);
      final dx = (xOf(i) - w / 2)
          .clamp(_leftPad, size.width - _rightPad - w)
          .toDouble();
      _drawText(canvas, label, Offset(dx, baseY + 6), labelColor, 11);
    }
  }

  double _measure(String text, double size) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: TextStyle(fontSize: size)),
      textDirection: TextDirection.ltr,
    )..layout();
    return tp.width;
  }

  void _drawText(Canvas canvas, String text, Offset offset, Color color,
      double size,
      {bool rightAlign = false}) {
    final tp = TextPainter(
      text: TextSpan(
          text: text, style: TextStyle(color: color, fontSize: size)),
      textDirection: TextDirection.ltr,
    )..layout();
    var dx = offset.dx;
    if (rightAlign) dx -= tp.width;
    tp.paint(canvas, Offset(dx, offset.dy));
  }

  @override
  bool shouldRepaint(covariant _VelocityLinePainter old) =>
      old.values != values ||
      old.unit != unit ||
      old.lineColor != lineColor ||
      old.dotColor != dotColor ||
      old.labelColor != labelColor ||
      old.gridColor != gridColor ||
      old.axisColor != axisColor;
}
