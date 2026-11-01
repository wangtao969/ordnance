import 'dart:convert';

import 'package:flutter/services.dart';

import 'models.dart';

/// 弹道档案本机存储（gunsmap/prefs，key ballistic_profiles_v1）。
/// 只存数据：Sg 只存导入或用户填写的值，App 内任何地方都不计算 Sg；
/// 不做弹道计算、不画弹道曲线、不做风偏与落点推算。
const _profilesKey = 'ballistic_profiles_v1';
const _prefsChannel = MethodChannel('gunsmap/prefs');

Future<List<BallisticProfile>> loadBallisticProfiles() async {
  try {
    final raw = await _prefsChannel
        .invokeMethod<String>('getString', {'key': _profilesKey}).timeout(
            const Duration(seconds: 2));
    if (raw == null || raw.isEmpty) return [];
    final list = jsonDecode(raw) as List;
    return list
        .whereType<Map<String, dynamic>>()
        .map(BallisticProfile.fromJson)
        .toList();
  } catch (_) {
    return [];
  }
}

Future<void> saveBallisticProfiles(List<BallisticProfile> profiles) async {
  try {
    await _prefsChannel.invokeMethod('setString', {
      'key': _profilesKey,
      'value': jsonEncode(profiles.map((p) => p.toJson()).toList()),
    }).timeout(const Duration(seconds: 2));
  } catch (_) {}
}

/// AB Quantum 导出文本结构化导入：按标签行匹配，导不进来的字段留空，
/// 绝不硬猜。返回字段名 -> 值（仅成功解析的字段）。
Map<String, String> parseAbExport(String text) {
  final out = <String, String>{};
  String? numOf(String line) {
    final m = RegExp(r'-?\d+(?:\.\d+)?').firstMatch(line);
    return m?.group(0);
  }

  for (final rawLine in text.split('\n')) {
    final line = rawLine.trim();
    if (line.isEmpty) continue;
    final low = line.toLowerCase();
    // 自定义阻力必须先于阻力模型判断（'Custom Drag Model' 含 'drag model'）。
    if (low.contains('custom drag')) {
      final v = numOf(line);
      if (v != null) out['customDrag'] = v;
      continue;
    }
    if (low.contains('drag model')) {
      if (low.contains('g7')) {
        out['dragModel'] = 'G7';
      } else if (low.contains('g1')) {
        out['dragModel'] = 'G1';
      }
      continue;
    }
    if (low.contains('bullet diameter') || low.contains('diameter')) {
      final v = numOf(line);
      if (v != null) out['diameterIn'] = v;
      continue;
    }
    if (low.contains('bullet weight')) {
      final v = numOf(line);
      if (v != null) out['bulletWeightGr'] = v;
      continue;
    }
    if (low.contains('ballistic coefficient') ||
        RegExp(r'\bbc\b').hasMatch(low)) {
      final v = numOf(line);
      if (v != null) out['bc'] = v;
      continue;
    }
    if (low.contains('bullet length')) {
      final v = numOf(line);
      if (v != null) out['bulletLengthIn'] = v;
      continue;
    }
    if (low.contains('muzzle velocity')) {
      final v = numOf(line);
      if (v != null) out['muzzleVelocityFps'] = v;
      continue;
    }
    if (low.contains('zero distance') ||
        low.contains('zero range') ||
        low == 'zero' ||
        low.startsWith('zero ')) {
      final v = numOf(line);
      if (v != null) out['zeroDistanceY'] = v;
      continue;
    }
    if (low.contains('sight height')) {
      final v = numOf(line);
      if (v != null) out['sightHeightIn'] = v;
      continue;
    }
    if (low.contains('twist direction')) {
      if (low.contains('left')) {
        out['twistDirection'] = 'L';
      } else if (low.contains('right')) {
        out['twistDirection'] = 'R';
      } else if (RegExp(r'\bl\b').hasMatch(low)) {
        out['twistDirection'] = 'L';
      } else if (RegExp(r'\br\b').hasMatch(low)) {
        out['twistDirection'] = 'R';
      }
      continue;
    }
    if (low.contains('twist rate') || low.contains('twist')) {
      final v = numOf(line);
      if (v != null) out['twistIn'] = v;
      continue;
    }
    // Sg：只搬运导入值，绝不计算。
    if (low.contains('stability factor') || RegExp(r'^sg\b').hasMatch(low)) {
      final v = numOf(line);
      if (v != null) out['sg'] = v;
      continue;
    }
  }
  return out;
}
