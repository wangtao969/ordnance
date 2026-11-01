import 'dart:convert';

import 'package:flutter/services.dart';

/// 每支枪的个人配置（本批新增，key gun_setup_v1，按枪名存）：
/// 初速、归零距离、瞄高、Sg 全部是用户自己填的值，App 只显示、
/// 只保存，绝不计算、不推导、不给默认值。空串 = 未填。
/// 与 2.2.5 的弹道档案（ballistic_profiles_v1）分开：那是导入存档，
/// 这里是图鉴详情页“枪械数据”栏的个人配置。
class GunSetup {
  String velocity;
  String zeroDistance;
  String sightHeight;
  String sg;

  GunSetup({
    this.velocity = '',
    this.zeroDistance = '',
    this.sightHeight = '',
    this.sg = '',
  });

  Map<String, dynamic> toJson() => {
        'velocity': velocity,
        'zeroDistance': zeroDistance,
        'sightHeight': sightHeight,
        'sg': sg,
      };

  static GunSetup fromJson(Map<String, dynamic> j) => GunSetup(
        velocity: j['velocity'] as String? ?? '',
        zeroDistance: j['zeroDistance'] as String? ?? '',
        sightHeight: j['sightHeight'] as String? ?? '',
        sg: j['sg'] as String? ?? '',
      );
}

const _setupChannel = MethodChannel('gunsmap/prefs');
const _setupKey = 'gun_setup_v1';

/// 读全部枪械配置（枪名 → 配置），读不到返回空表。
Future<Map<String, GunSetup>> loadGunSetups() async {
  try {
    final raw = await _setupChannel
        .invokeMethod<String>('getString', {'key': _setupKey}).timeout(
            const Duration(seconds: 2));
    if (raw == null || raw.isEmpty) return {};
    final map = jsonDecode(raw) as Map<String, dynamic>;
    return map.map((k, v) => MapEntry(
        k, GunSetup.fromJson(v as Map<String, dynamic>)));
  } catch (_) {
    return {};
  }
}

Future<void> saveGunSetups(Map<String, GunSetup> setups) async {
  try {
    await _setupChannel.invokeMethod('setString', {
      'key': _setupKey,
      'value': jsonEncode(
          setups.map((k, v) => MapEntry(k, v.toJson()))),
    });
  } catch (_) {}
}
