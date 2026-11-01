import 'dart:convert';

import 'package:flutter/services.dart';

import 'community_store.dart';

/// 我的枪柜数据：个人档案（字段全部可空）+ 配件装机记录。
/// 2.2.5 起枪柜自有拥有体系，不再读收藏柜：首次启动时
/// migrateCabinetFromCollection() 把旧收藏里 status == 'owned' 的枪
/// （含 rounds 发数）幂等迁入 gun_profiles_v1，旧 community_store_v1
/// 原样保留不动；迁完枪柜只读自有存储。勋章逻辑不动。

/// 枪柜档案本机存储 key（与枪柜页一致）。
const gunProfilesKey = 'gun_profiles_v1';
const gunMountsKey = 'gun_mounts_v1';

/// 迁移完成标记（prefs 字符串，'1' = 已迁过，跳过）。
const cabinetMigrationKey = 'gun_cabinet_migrated_v1';

/// 首页等同步读取方用的内存镜像：null = 尚未加载（枪柜页未打开且迁移
/// 未跑出结果），非 null（含空列表）= 已加载的最新档案。
/// 枪柜页加载/保存、启动迁移都会同步它；首页优先读它，null 时才回落
/// 旧收藏快照（迁移前的冻结数据），避免枪柜改动后首页仍显示旧数。
List<GunProfile>? cabinetProfilesCache;

const _cabinetChannel = MethodChannel('gunsmap/prefs');

Future<List<GunProfile>> loadGunProfiles() async {
  try {
    final raw = await _cabinetChannel
        .invokeMethod<String>('getString', {'key': gunProfilesKey}).timeout(
            const Duration(seconds: 2));
    if (raw == null || raw.isEmpty) return [];
    final list = jsonDecode(raw) as List;
    return list
        .whereType<Map<String, dynamic>>()
        .map(GunProfile.fromJson)
        .toList();
  } catch (_) {
    return [];
  }
}

Future<void> saveGunProfiles(List<GunProfile> profiles) async {
  try {
    await _cabinetChannel.invokeMethod('setString', {
      'key': gunProfilesKey,
      'value': jsonEncode(profiles.map((p) => p.toJson()).toList()),
    }).timeout(const Duration(seconds: 2));
  } catch (_) {}
}

/// 首次启动迁移：旧收藏的拥有枪 → 枪柜自有档案（幂等）。
/// 规则：缺档案则新建（rounds 照搬收藏发数）；已有档案且 rounds 为 0
/// 时补填收藏发数（不覆盖用户已手动填过的非零值）；旧收藏数据不写、
/// 不删。任一步失败不写标记，下次启动重试，绝不阻塞启动。
Future<void> migrateCabinetFromCollection() async {
  try {
    final done = await _cabinetChannel
        .invokeMethod<String>('getString', {'key': cabinetMigrationKey}).timeout(
            const Duration(seconds: 2));
    if (done == '1') {
      // 已迁过：仍把档案读进内存镜像，供首页同步读取。
      cabinetProfilesCache = await loadGunProfiles();
      return;
    }
    final account = communityStore.current;
    if (account == null) return;
    final owned = account.collection
        .where((c) => c.kind == 'gun' && c.status == 'owned')
        .toList();
    final profiles = await loadGunProfiles();
    var changed = false;
    for (final item in owned) {
      final idx = profiles.indexWhere((p) => p.gunName == item.gunName);
      if (idx < 0) {
        profiles.add(GunProfile(gunName: item.gunName, rounds: item.rounds));
        changed = true;
      } else if (profiles[idx].rounds == 0 && item.rounds > 0) {
        profiles[idx].rounds = item.rounds;
        changed = true;
      }
    }
    if (changed) await saveGunProfiles(profiles);
    cabinetProfilesCache = profiles;
    await _cabinetChannel.invokeMethod('setString', {
      'key': cabinetMigrationKey,
      'value': '1',
    }).timeout(const Duration(seconds: 2));
  } catch (_) {}
}

class GunProfile {
  String gunName;
  String purchaseDate; // '' = 未填
  String price; // '' = 未填，自由文本
  String zeroStatus; // '' = 未填
  String maintenanceNote; // '' = 未填
  String faultNote; // '' = 未填
  int rounds; // 2.2.5 起自有发数（由旧收藏迁移而来，缺失默认 0）

  GunProfile({
    required this.gunName,
    this.purchaseDate = '',
    this.price = '',
    this.zeroStatus = '',
    this.maintenanceNote = '',
    this.faultNote = '',
    this.rounds = 0,
  });

  Map<String, dynamic> toJson() => {
        'gunName': gunName,
        'purchaseDate': purchaseDate,
        'price': price,
        'zeroStatus': zeroStatus,
        'maintenanceNote': maintenanceNote,
        'faultNote': faultNote,
        'rounds': rounds,
      };

  factory GunProfile.fromJson(Map<String, dynamic> j) => GunProfile(
        gunName: j['gunName'] as String? ?? '',
        purchaseDate: j['purchaseDate'] as String? ?? '',
        price: j['price'] as String? ?? '',
        zeroStatus: j['zeroStatus'] as String? ?? '',
        maintenanceNote: j['maintenanceNote'] as String? ?? '',
        faultNote: j['faultNote'] as String? ?? '',
        rounds: (j['rounds'] as num?)?.toInt() ?? 0,
      );
}

class GunMount {
  /// 配件标识：取配件目录名（目录内唯一）；手动登记的配件同样用名标识。
  String accessoryId;
  String gunName;
  int mountDateMs;

  GunMount({
    required this.accessoryId,
    required this.gunName,
    required this.mountDateMs,
  });

  Map<String, dynamic> toJson() => {
        'accessoryId': accessoryId,
        'gunName': gunName,
        'mountDateMs': mountDateMs,
      };

  factory GunMount.fromJson(Map<String, dynamic> j) => GunMount(
        accessoryId: j['accessoryId'] as String? ?? '',
        gunName: j['gunName'] as String? ?? '',
        mountDateMs: (j['mountDateMs'] as num?)?.toInt() ??
            DateTime.now().millisecondsSinceEpoch,
      );
}
