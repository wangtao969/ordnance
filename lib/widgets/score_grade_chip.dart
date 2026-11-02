import 'package:flutter/material.dart';

import '../i18n.dart';

/// 系统档位徽章：S/A/B/C/D 按档位着色；3 发以下显示“样本不足”
/// 灰色片；无档（无散布）时不渲染。成绩卡片与公开动态卡片共用。
class ScoreGradeChip extends StatelessWidget {
  final String? grade;
  final bool insufficient;
  const ScoreGradeChip({
    super.key,
    this.grade,
    this.insufficient = false,
  });

  static Color colorFor(String grade) {
    switch (grade) {
      case 'S':
        return const Color(0xFFD4A017);
      case 'A':
        return const Color(0xFFE86A1C);
      case 'B':
        return const Color(0xFF2E7D32);
      case 'C':
        return const Color(0xFF5C7A99);
      default:
        return const Color(0xFF9A917F);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (insufficient) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(
          color: const Color(0xFF9A917F),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(tr('score_grade_insufficient'),
            style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.bold)),
      );
    }
    final g = grade ?? '';
    if (g.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
      decoration: BoxDecoration(
        color: colorFor(g),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(g,
          style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold)),
    );
  }
}
