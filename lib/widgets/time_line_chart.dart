import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 时间折线图：CustomPaint 手画，零第三方包。
/// 横轴是真实时间（按日期线性映射），不是序号；多序列各画一条线，
/// 多于一条时上方显示图例。空数据时父级不渲染本组件。
class TimePoint {
  final DateTime date;
  final double value;
  const TimePoint(this.date, this.value);
}

class TimeSeries {
  final String label;
  final Color color;
  final List<TimePoint> points;
  const TimeSeries({
    required this.label,
    required this.color,
    required this.points,
  });
}

class TimeLineChart extends StatelessWidget {
  final List<TimeSeries> series;
  final String unit;
  final double height;
  const TimeLineChart({
    super.key,
    required this.series,
    required this.unit,
    this.height = 220,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final labelColor =
        dark ? const Color(0xFFB8B2A4) : const Color(0xFF6B655A);
    final gridColor = dark
        ? Colors.white.withValues(alpha: 0.12)
        : Colors.black.withValues(alpha: 0.08);
    final axisColor = dark
        ? Colors.white.withValues(alpha: 0.25)
        : Colors.black.withValues(alpha: 0.25);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (series.length > 1)
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: series
                .map((s) => Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                                color: s.color, shape: BoxShape.circle)),
                        const SizedBox(width: 4),
                        Text(s.label, style: TextStyle(
                            color: labelColor, fontSize: 12)),
                      ],
                    ))
                .toList(),
          ),
        if (series.length > 1) const SizedBox(height: 4),
        CustomPaint(
          size: Size(double.infinity, height),
          painter: _TimeLinePainter(
            series: series,
            unit: unit,
            labelColor: labelColor,
            gridColor: gridColor,
            axisColor: axisColor,
          ),
        ),
      ],
    );
  }
}

class _TimeLinePainter extends CustomPainter {
  final List<TimeSeries> series;
  final String unit;
  final Color labelColor;
  final Color gridColor;
  final Color axisColor;

  const _TimeLinePainter({
    required this.series,
    required this.unit,
    required this.labelColor,
    required this.gridColor,
    required this.axisColor,
  });

  static const _leftPad = 52.0;
  static const _rightPad = 8.0;
  static const _topPad = 20.0;
  static const _bottomPad = 24.0;

  String _valueLabel(double v, bool whole) {
    if (whole) return v.toStringAsFixed(0);
    var s = v.toStringAsFixed(2);
    while (s.endsWith('0')) {
      s = s.substring(0, s.length - 1);
    }
    if (s.endsWith('.')) s = s.substring(0, s.length - 1);
    return s;
  }

  String _dateLabel(DateTime d) =>
      '${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  void paint(Canvas canvas, Size size) {
    final all = series.expand((s) => s.points).toList();
    if (all.isEmpty) return;
    final plotW = size.width - _leftPad - _rightPad;
    final plotH = size.height - _topPad - _bottomPad;
    if (plotW <= 0 || plotH <= 0) return;

    var lo = all.first.value;
    var hi = all.first.value;
    var minMs = all.first.date.millisecondsSinceEpoch;
    var maxMs = minMs;
    var whole = true;
    for (final p in all) {
      if (p.value < lo) lo = p.value;
      if (p.value > hi) hi = p.value;
      final ms = p.date.millisecondsSinceEpoch;
      if (ms < minMs) minMs = ms;
      if (ms > maxMs) maxMs = ms;
      if (p.value != p.value.truncateToDouble()) whole = false;
    }
    var span = hi - lo;
    if (span <= 0) span = 10;
    final pad = math.max(span * 0.15, whole ? 5 : 0.5);
    final minV = lo - pad;
    final maxV = hi + pad;
    final range = maxV - minV;
    var timeSpan = (maxMs - minMs).toDouble();
    if (timeSpan <= 0) timeSpan = 86400000;

    double yOf(double v) => _topPad + plotH - (v - minV) / range * plotH;
    double xOf(DateTime d) => _leftPad +
        plotW *
            (d.millisecondsSinceEpoch - minMs) /
            timeSpan;

    final gridPaint = Paint()..color = gridColor..strokeWidth = 1;
    for (var i = 0; i <= 3; i++) {
      final v = minV + range * i / 3;
      final y = yOf(v);
      canvas.drawLine(Offset(_leftPad, y), Offset(size.width - _rightPad, y),
          gridPaint);
      _drawText(canvas, _valueLabel(v, whole), Offset(_leftPad - 4, y - 7),
          labelColor, 11,
          rightAlign: true);
    }
    final axisPaint = Paint()..color = axisColor..strokeWidth = 1;
    final baseY = _topPad + plotH;
    canvas.drawLine(Offset(_leftPad, baseY), Offset(size.width - _rightPad, baseY),
        axisPaint);
    _drawText(canvas, unit, Offset(size.width - _rightPad, _topPad - 16),
        labelColor, 11,
        rightAlign: true);

    // 横轴日期：最多 5 个，不重叠。
    final firstDate = DateTime.fromMillisecondsSinceEpoch(minMs);
    final lastDate = DateTime.fromMillisecondsSinceEpoch(maxMs);
    final marks = <DateTime>[firstDate];
    for (var i = 1; i < 4; i++) {
      marks.add(DateTime.fromMillisecondsSinceEpoch(
          minMs + (timeSpan * i / 4).round()));
    }
    marks.add(lastDate);
    for (final d in marks) {
      final label = _dateLabel(d);
      final w = _measure(label, 11);
      final dx = (xOf(d) - w / 2)
          .clamp(_leftPad, size.width - _rightPad - w)
          .toDouble();
      _drawText(canvas, label, Offset(dx, baseY + 6), labelColor, 11);
    }

    for (final s in series) {
      if (s.points.isEmpty) continue;
      final color = s.color;
      final pts = s.points;
      if (pts.length > 1) {
        final path = Path()
          ..moveTo(xOf(pts.first.date), yOf(pts.first.value));
        for (var i = 1; i < pts.length; i++) {
          path.lineTo(xOf(pts[i].date), yOf(pts[i].value));
        }
        canvas.drawPath(
            path,
            Paint()
              ..color = color
              ..strokeWidth = 2
              ..style = PaintingStyle.stroke
              ..strokeJoin = StrokeJoin.round);
      }
      final dotPaint = Paint()..color = color;
      for (final p in pts) {
        canvas.drawCircle(Offset(xOf(p.date), yOf(p.value)), 3.5, dotPaint);
      }
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
  bool shouldRepaint(covariant _TimeLinePainter old) =>
      old.series != series || old.unit != unit;
}
