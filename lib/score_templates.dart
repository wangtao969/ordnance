import 'dart:convert';

import 'package:flutter/services.dart';

/// 快速录入模板：常用组合（枪 + 距离 + 弹药），存在 gunsmap/prefs
/// 新 key score_templates_v1；模板只是录入快捷方式，不动成绩数据。
class ScoreTemplate {
  final String gunName;
  final int distance;
  final String ammo;
  const ScoreTemplate({
    required this.gunName,
    required this.distance,
    this.ammo = '',
  });

  Map<String, dynamic> toJson() => {
        'gunName': gunName,
        'distance': distance,
        'ammo': ammo,
      };

  static ScoreTemplate fromJson(Map<String, dynamic> j) => ScoreTemplate(
        gunName: j['gunName'] as String? ?? '',
        distance: j['distance'] as int? ?? 100,
        ammo: j['ammo'] as String? ?? '',
      );
}

const _templatesChannel = MethodChannel('gunsmap/prefs');

Future<List<ScoreTemplate>> loadScoreTemplates() async {
  try {
    final raw = await _templatesChannel
        .invokeMethod<String>('getString', {'key': 'score_templates_v1'})
        .timeout(const Duration(seconds: 2));
    if (raw == null || raw.isEmpty) return [];
    return (jsonDecode(raw) as List)
        .map((e) => ScoreTemplate.fromJson(e as Map<String, dynamic>))
        .where((t) => t.gunName.isNotEmpty)
        .toList();
  } catch (_) {
    return [];
  }
}

Future<void> saveScoreTemplates(List<ScoreTemplate> templates) async {
  try {
    await _templatesChannel.invokeMethod('setString', {
      'key': 'score_templates_v1',
      'value': jsonEncode(templates.map((t) => t.toJson()).toList()),
    }).timeout(const Duration(seconds: 2));
  } catch (_) {}
}
