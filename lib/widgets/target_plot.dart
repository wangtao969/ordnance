import 'package:flutter/material.dart';

/// 靶纸落点图：5 环靶纸，点按标弹着点（可拖动调整），弹着点坐标
/// 归一化到 [-1,1]（中心 0，边缘 ±1），每环一步 = gridCm 厘米。
/// 本组件只画图与处理手势，散布换算在 score_grade.dart；父级
/// 用 RepaintBoundary 包裹本组件即可把落点图导出为图片。
class TargetPlot extends StatefulWidget {
  final List<List<double>> points;
  final ValueChanged<List<List<double>>>? onChanged;
  final bool editable;
  final double size;

  /// 选中点下标（父级受控，用于“删除选中点”）；-1 = 未选中。
  final int selected;
  final ValueChanged<int>? onSelectedChanged;
  const TargetPlot({
    super.key,
    required this.points,
    this.onChanged,
    this.editable = true,
    this.size = 220,
    this.selected = -1,
    this.onSelectedChanged,
  });

  @override
  State<TargetPlot> createState() => _TargetPlotState();
}

class _TargetPlotState extends State<TargetPlot> {
  bool _dragging = false;

  List<double> _toNorm(Offset local, double size) {
    final nx = (local.dx / size * 2 - 1).clamp(-1.0, 1.0);
    final ny = (local.dy / size * 2 - 1).clamp(-1.0, 1.0);
    return [nx, ny];
  }

  int _nearest(Offset local, double size) {
    var best = -1;
    var bestD = 1e9;
    for (var i = 0; i < widget.points.length; i++) {
      final px = (widget.points[i][0] + 1) / 2 * size;
      final py = (widget.points[i][1] + 1) / 2 * size;
      final d = (local.dx - px) * (local.dx - px) +
          (local.dy - py) * (local.dy - py);
      if (d < bestD) {
        bestD = d;
        best = i;
      }
    }
    if (bestD > 28 * 28) return -1;
    return best;
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    return SizedBox(
      width: size,
      height: size,
      child: GestureDetector(
        onTapUp: widget.editable
            ? (d) {
                final idx = _nearest(d.localPosition, size);
                if (idx >= 0) {
                  widget.onSelectedChanged?.call(idx);
                } else {
                  final p = _toNorm(d.localPosition, size);
                  widget.onChanged?.call([...widget.points, p]);
                  widget.onSelectedChanged?.call(widget.points.length);
                }
              }
            : null,
        onPanStart: widget.editable
            ? (d) {
                final idx = _nearest(d.localPosition, size);
                if (idx >= 0) {
                  widget.onSelectedChanged?.call(idx);
                  _dragging = true;
                }
              }
            : null,
        onPanUpdate: widget.editable
            ? (d) {
                if (!_dragging || widget.selected < 0) return;
                final next = widget.points
                    .map((e) => <double>[e[0], e[1]])
                    .toList();
                next[widget.selected] = _toNorm(d.localPosition, size);
                widget.onChanged?.call(next);
              }
            : null,
        onPanEnd: widget.editable
            ? (_) {
                _dragging = false;
              }
            : null,
        child: CustomPaint(
          size: Size(size, size),
          painter: _TargetPainter(widget.points, widget.selected),
        ),
      ),
    );
  }
}

class _TargetPainter extends CustomPainter {
  final List<List<double>> points;
  final int selected;
  _TargetPainter(this.points, this.selected);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 2;
    final paper = Paint()
      ..color = const Color(0xFFF7F2E9)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, paper);
    final ring = Paint()
      ..color = const Color(0xFF9A917F)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (var i = 1; i <= 5; i++) {
      canvas.drawCircle(center, radius * i / 5, ring);
    }
    final cross = Paint()
      ..color = const Color(0xFF9A917F).withValues(alpha: 0.6)
      ..strokeWidth = 1;
    canvas.drawLine(Offset(center.dx - radius, center.dy),
        Offset(center.dx + radius, center.dy), cross);
    canvas.drawLine(Offset(center.dx, center.dy - radius),
        Offset(center.dx, center.dy + radius), cross);
    for (var i = 0; i < points.length; i++) {
      final px = center.dx + points[i][0] * radius;
      final py = center.dy + points[i][1] * radius;
      final isSel = i == selected;
      final dot = Paint()
        ..color = isSel
            ? const Color(0xFFD32F2F)
            : const Color(0xFFE86A1C)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(px, py), isSel ? 9 : 7, dot);
      final rim = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.drawCircle(Offset(px, py), isSel ? 9 : 7, rim);
    }
  }

  @override
  bool shouldRepaint(_TargetPainter old) =>
      old.points != points || old.selected != selected;
}
