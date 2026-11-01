import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 单位设置（第 8 项）：左标签 + 右分段 pill，分组为长度、重量、
/// 速度、温度、气压、能量、显示类（靶名、指示方式）。
/// 存本机（gunsmap/prefs，key tools_units_v1 不变），重启不丢。
/// 旧版只存 'imperial'/'metric' 一个字符串，首次读取时按该预设
/// 展开为分维度表（长度/重量/能量跟随旧预设；温度/气压/风速
/// 默认沿用天气现有显示 °C/hPa/km/h，不擅自改动天气显示）。
/// 长度维度驱动旧的 unitSystemNotifier（装药工具、靶场换算、
/// 归零助手仍按英制/公制分支），其余维度由各显示处按需取用。
const String toolsUnitsPrefsKey = 'tools_units_v1';
const _unitsChannel = MethodChannel('gunsmap/prefs');

/// 维度 → 取值。length: m/yd；weight: kg/lb；velocity: ms/fps/kmh；
/// temperature: c/f；pressure: hpa/inhg；energy: j/ftlb；
/// targetName: alpha/numeric；holdIndicator: udlr/plusminus。
const Map<String, String> unitPrefsDefaults = {
  'length': 'yd',
  'weight': 'lb',
  'velocity': 'kmh',
  'temperature': 'c',
  'pressure': 'hpa',
  'energy': 'ftlb',
  'targetName': 'alpha',
  'holdIndicator': 'udlr',
};

final ValueNotifier<Map<String, String>> unitPrefsNotifier =
    ValueNotifier<Map<String, String>>(Map.of(unitPrefsDefaults));

String unitPref(String dim) =>
    unitPrefsNotifier.value[dim] ?? unitPrefsDefaults[dim]!;

final ValueNotifier<String> unitSystemNotifier =
    ValueNotifier<String>('imperial');

bool get isMetricUnits => unitSystemNotifier.value == 'metric';

void _applyToLegacy(Map<String, String> prefs) {
  unitSystemNotifier.value = prefs['length'] == 'm' ? 'metric' : 'imperial';
}

Future<void> loadUnitSystem() async {
  try {
    final v = await _unitsChannel
        .invokeMethod<String>('getString', {'key': toolsUnitsPrefsKey})
        .timeout(const Duration(seconds: 2));
    if (v == null || v.isEmpty) return;
    if (v == 'metric' || v == 'imperial') {
      // 旧版单值：按预设展开。
      final prefs = Map<String, String>.of(unitPrefsDefaults);
      if (v == 'metric') {
        prefs['length'] = 'm';
        prefs['weight'] = 'kg';
        prefs['energy'] = 'j';
      }
      unitPrefsNotifier.value = prefs;
      _applyToLegacy(prefs);
      return;
    }
    final m = jsonDecode(v) as Map<String, dynamic>;
    final prefs = Map<String, String>.of(unitPrefsDefaults);
    for (final e in m.entries) {
      if (e.value is String && prefs.containsKey(e.key)) {
        prefs[e.key] = e.value as String;
      }
    }
    unitPrefsNotifier.value = prefs;
    _applyToLegacy(prefs);
  } catch (_) {}
}

Future<void> _persistPrefs() async {
  try {
    await _unitsChannel.invokeMethod('setString', {
      'key': toolsUnitsPrefsKey,
      'value': jsonEncode(unitPrefsNotifier.value),
    });
  } catch (_) {}
}

Future<void> saveUnitPref(String dim, String value) async {
  final prefs = Map<String, String>.of(unitPrefsNotifier.value);
  prefs[dim] = value;
  unitPrefsNotifier.value = prefs;
  if (dim == 'length') _applyToLegacy(prefs);
  await _persistPrefs();
}

/// 旧版单值保存（兼容旧调用处）：按预设展开为分维度表。
Future<void> saveUnitSystem(String system) async {
  final prefs = Map<String, String>.of(unitPrefsDefaults);
  if (system == 'metric') {
    prefs['length'] = 'm';
    prefs['weight'] = 'kg';
    prefs['energy'] = 'j';
  }
  unitPrefsNotifier.value = prefs;
  _applyToLegacy(prefs);
  await _persistPrefs();
}

// ---------------------------------------------------------------------------
// 天气显示换算（第 8 项接线）：原始值一律是 °C / km/h / hPa，
// 显示时按温度/速度/气压偏好换算；已存快照文本（复装记录、
// 行程）是历史字符串，不动。

String _f1(double v) {
  var s = v.toStringAsFixed(1);
  while (s.contains('.') && s.endsWith('0')) {
    s = s.substring(0, s.length - 1);
  }
  if (s.endsWith('.')) s = s.substring(0, s.length - 1);
  return s;
}

/// 温度显示：偏好 f 时转 °F，否则 °C。
String fmtTemp(double tempC) {
  if (unitPref('temperature') == 'f') {
    return '${_f1(tempC * 9 / 5 + 32)}°F';
  }
  return '${_f1(tempC)}°C';
}

/// 风速显示：偏好 ms 时转 m/s，fps 时转 fps，否则 km/h。
String fmtWind(double kmh) {
  final u = unitPref('velocity');
  if (u == 'ms') return '${_f1(kmh / 3.6)} m/s';
  if (u == 'fps') return '${_f1(kmh * 0.911344)} fps';
  return '${_f1(kmh)} km/h';
}

/// 气压显示：偏好 inhg 时转英寸汞柱，否则 hPa。
String fmtPressure(double hpa) {
  if (unitPref('pressure') == 'inhg') {
    return '${(hpa * 0.02953).toStringAsFixed(2)} inHg';
  }
  return '${_f1(hpa)} hPa';
}
