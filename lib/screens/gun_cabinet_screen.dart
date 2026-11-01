import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_log.dart';
import '../community_store.dart';
import '../data.dart';
import '../gun_cabinet_data.dart';
import '../i18n.dart';
import '../models.dart';
import '../widgets/app_toast.dart';
import '../widgets/app_top_bar.dart';

/// 我的枪柜：首页“我的枪柜”点进来的一页。
/// 拥有状态复用收藏柜 status == 'owned'，不另起体系，不动勋章逻辑。
/// 个人档案字段全部可空，没有就不显示，绝不编数据；
/// 射弹数读收藏柜 rounds；配件装机存 accessoryId + gunName + 装机日期。
/// 经 gunsmap/prefs 存本机（key gun_profiles_v1、gun_mounts_v1）。
String _dateText(int ms) {
  final d = DateTime.fromMillisecondsSinceEpoch(ms);
  return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

String _todayText() {
  final now = DateTime.now();
  return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
}

class GunCabinetScreen extends StatefulWidget {
  const GunCabinetScreen({super.key});

  @override
  State<GunCabinetScreen> createState() => _GunCabinetScreenState();
}

class _GunCabinetScreenState extends State<GunCabinetScreen> {
  static const _prefsChannel = MethodChannel('gunsmap/prefs');
  static const _profilesKey = 'gun_profiles_v1';
  static const _mountsKey = 'gun_mounts_v1';
  final _profiles = <GunProfile>[];
  final _mounts = <GunMount>[];
  String? _mountGun;
  String _mountAccessory = '';
  String _mountDate = '';

  @override
  void initState() {
    super.initState();
    _mountDate = _todayText();
    _load();
  }

  List<CollectionItem> get _ownedGuns =>
      communityStore.current?.collection
          .where((c) => c.kind == 'gun' && c.status == 'owned')
          .toList() ??
      [];

  GunProfile? _profile(String gunName) {
    for (final p in _profiles) {
      if (p.gunName == gunName) return p;
    }
    return null;
  }

  List<GunMount> _mountsOf(String gunName) =>
      _mounts.where((m) => m.gunName == gunName).toList();

  Future<void> _load() async {
    try {
      final raw = await _prefsChannel
          .invokeMethod<String>('getString', {'key': _profilesKey})
          .timeout(const Duration(seconds: 2));
      if (raw != null && raw.isNotEmpty && mounted) {
        final list = (jsonDecode(raw) as List)
            .map((e) => GunProfile.fromJson(e as Map<String, dynamic>))
            .toList();
        setState(() {
          _profiles
            ..clear()
            ..addAll(list);
        });
      }
    } catch (e) {
      appLog('prefs', '枪柜档案读取失败：$e');
    }
    try {
      final raw = await _prefsChannel
          .invokeMethod<String>('getString', {'key': _mountsKey})
          .timeout(const Duration(seconds: 2));
      if (raw != null && raw.isNotEmpty && mounted) {
        final list = (jsonDecode(raw) as List)
            .map((e) => GunMount.fromJson(e as Map<String, dynamic>))
            .toList();
        setState(() {
          _mounts
            ..clear()
            ..addAll(list);
        });
      }
    } catch (e) {
      appLog('prefs', '装机记录读取失败：$e');
    }
  }

  void _saveProfiles() {
    try {
      _prefsChannel.invokeMethod('setString', {
        'key': _profilesKey,
        'value': jsonEncode(_profiles.map((e) => e.toJson()).toList()),
      });
    } catch (e) {
      appLog('prefs', '枪柜档案保存失败：$e');
    }
  }

  void _saveMounts() {
    try {
      _prefsChannel.invokeMethod('setString', {
        'key': _mountsKey,
        'value': jsonEncode(_mounts.map((e) => e.toJson()).toList()),
      });
    } catch (e) {
      appLog('prefs', '装机记录保存失败：$e');
    }
  }

  Future<void> _pickMountDate() async {
    final initial = DateTime.tryParse(_mountDate) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked == null) return;
    setState(() {
      _mountDate =
          '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
    });
  }

  Future<void> _pickAccessory() async {
    final ctrl = TextEditingController();
    var query = '';
    final picked = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (_, setDialogState) {
          final names = <String>{};
          for (final a in accessories) {
            names.add(a.name);
          }
          final mine = communityStore.current?.collection
                  .where((c) => c.kind == 'accessory')
                  .map((c) => c.gunName) ??
              [];
          for (final n in mine) {
            names.add(n);
          }
          final q = query.trim().toLowerCase();
          final results = names
              .where((n) => q.isEmpty || n.toLowerCase().contains(q))
              .toList()
            ..sort();
          AccessoryItem? catalogOf(String name) {
            for (final a in accessories) {
              if (a.name == name) return a;
            }
            return null;
          }

          return AlertDialog(
            title: Text(tr('cab_pick_accessory')),
            content: SizedBox(
              width: double.maxFinite,
              height: 420,
              child: Column(
                children: [
                  TextField(
                    controller: ctrl,
                    onChanged: (v) => setDialogState(() => query = v),
                    decoration: InputDecoration(
                      hintText: tr('cab_search_accessory'),
                      prefixIcon: const Icon(Icons.search),
                      border: const OutlineInputBorder(
                          borderRadius:
                              BorderRadius.all(Radius.circular(12))),
                      enabledBorder: OutlineInputBorder(
                        borderRadius:
                            const BorderRadius.all(Radius.circular(12)),
                        borderSide: BorderSide(
                            color: Colors.grey.withValues(alpha: 0.35)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius:
                            const BorderRadius.all(Radius.circular(12)),
                        borderSide: BorderSide(
                            color: Colors.grey.withValues(alpha: 0.35)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView(
                      children: [
                        if (q.isNotEmpty && !names.contains(query.trim()))
                          ListTile(
                            title: Text(
                                '${tr('cab_use_name')}“${query.trim()}”'),
                            onTap: () => Navigator.of(dialogContext)
                                .pop(query.trim()),
                          ),
                        for (final n in results)
                          ListTile(
                            title: Text(n),
                            subtitle: catalogOf(n) == null
                                ? null
                                : Text(
                                    '${catalogOf(n)!.vendor} · ${catalogOf(n)!.type}'),
                            onTap: () =>
                                Navigator.of(dialogContext).pop(n),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text(tr('cancel')),
              ),
            ],
          );
        },
      ),
    );
    ctrl.dispose();
    if (picked != null && picked.isNotEmpty && mounted) {
      setState(() => _mountAccessory = picked);
    }
  }

  void _addMount() {
    final gun = _mountGun;
    if (gun == null || gun.isEmpty || _mountAccessory.isEmpty) {
      showAppToast(context, tr('cab_mount_need'));
      return;
    }
    final date = DateTime.tryParse(_mountDate) ?? DateTime.now();
    setState(() {
      _mounts.insert(
          0,
          GunMount(
              accessoryId: _mountAccessory,
              gunName: gun,
              mountDateMs: date.millisecondsSinceEpoch));
      _mountAccessory = '';
    });
    _saveMounts();
    showAppToast(context, tr('chrono_saved'));
  }

  Future<void> _editProfile(CollectionItem gun) async {
    final existing = _profile(gun.gunName);
    final purchaseCtrl =
        TextEditingController(text: existing?.purchaseDate ?? '');
    final priceCtrl = TextEditingController(text: existing?.price ?? '');
    final zeroCtrl = TextEditingController(text: existing?.zeroStatus ?? '');
    final maintCtrl =
        TextEditingController(text: existing?.maintenanceNote ?? '');
    final faultCtrl = TextEditingController(text: existing?.faultNote ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('${gun.gunName} · ${tr('cab_edit')}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                  controller: purchaseCtrl,
                  decoration: InputDecoration(
                      labelText: tr('cab_purchase'),
                      hintText: '如 2024-05-01')),
              TextField(
                  controller: priceCtrl,
                  decoration:
                      InputDecoration(labelText: tr('cab_price'))),
              TextField(
                  controller: zeroCtrl,
                  decoration:
                      InputDecoration(labelText: tr('cab_zero'))),
              TextField(
                  controller: maintCtrl,
                  decoration: InputDecoration(
                      labelText: tr('cab_maintenance'))),
              TextField(
                  controller: faultCtrl,
                  decoration:
                      InputDecoration(labelText: tr('cab_fault'))),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(tr('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(tr('save')),
          ),
        ],
      ),
    );
    final purchase = purchaseCtrl.text.trim();
    final price = priceCtrl.text.trim();
    final zero = zeroCtrl.text.trim();
    final maint = maintCtrl.text.trim();
    final fault = faultCtrl.text.trim();
    purchaseCtrl.dispose();
    priceCtrl.dispose();
    zeroCtrl.dispose();
    maintCtrl.dispose();
    faultCtrl.dispose();
    if (ok != true || !mounted) return;
    setState(() {
      _profiles.removeWhere((p) => p.gunName == gun.gunName);
      _profiles.add(GunProfile(
        gunName: gun.gunName,
        purchaseDate: purchase,
        price: price,
        zeroStatus: zero,
        maintenanceNote: maint,
        faultNote: fault,
      ));
    });
    _saveProfiles();
    showAppToast(context, tr('chrono_saved'));
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: communityStore,
      builder: (_, __) {
        final owned = _ownedGuns;
        final mountGroups = <String, List<GunMount>>{};
        for (final m in _mounts) {
          mountGroups.putIfAbsent(m.gunName, () => []).add(m);
        }
        return ValueListenableBuilder<String>(
          valueListenable: localeNotifier,
          builder: (_, ___, ____) => Scaffold(
            appBar: SubPageAppBar(title: tr('cab_title')),
            body: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(tr('cab_guns'),
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                if (owned.isEmpty)
                  Text(tr('cab_empty'),
                      style: const TextStyle(color: Colors.grey))
                else
                  ...owned.map((g) {
                    final p = _profile(g.gunName);
                    final mountedNames =
                        _mountsOf(g.gunName).map((m) => m.accessoryId).toList();
                    final lines = <String>[];
                    if (p != null) {
                      if (p.purchaseDate.isNotEmpty) {
                        lines.add(
                            '${tr('cab_purchase')} ${p.purchaseDate}');
                      }
                      if (p.price.isNotEmpty) {
                        lines.add('${tr('cab_price')} ${p.price}');
                      }
                      if (p.zeroStatus.isNotEmpty) {
                        lines.add('${tr('cab_zero')} ${p.zeroStatus}');
                      }
                      if (p.maintenanceNote.isNotEmpty) {
                        lines.add(
                            '${tr('cab_maintenance')} ${p.maintenanceNote}');
                      }
                      if (p.faultNote.isNotEmpty) {
                        lines.add('${tr('cab_fault')} ${p.faultNote}');
                      }
                    }
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                      '${g.gunName} · ${g.caliber}',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold)),
                                ),
                                TextButton(
                                  onPressed: () => _editProfile(g),
                                  child: Text(tr('cab_edit')),
                                ),
                              ],
                            ),
                            Text(
                                '${tr('cab_rounds')} ${g.rounds}',
                                style: const TextStyle(
                                    color: Colors.grey, fontSize: 12)),
                            for (final line in lines) ...[
                              const SizedBox(height: 2),
                              Text(line,
                                  style: const TextStyle(fontSize: 13)),
                            ],
                            if (mountedNames.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                children: mountedNames
                                    .map((n) => Chip(
                                          label: Text(n,
                                              style: const TextStyle(
                                                  fontSize: 12)),
                                          visualDensity:
                                              VisualDensity.compact,
                                        ))
                                    .toList(),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  }),
                const SizedBox(height: 20),
                Text(tr('cab_mounts'),
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                if (owned.isEmpty)
                  Text(tr('cab_no_owned_hint'),
                      style: const TextStyle(color: Colors.grey))
                else ...[
                  OutlinedButton.icon(
                    onPressed: _pickAccessory,
                    icon: const Icon(Icons.build_outlined, size: 18),
                    label: Text(_mountAccessory.isEmpty
                        ? tr('cab_pick_accessory')
                        : _mountAccessory),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: owned
                            .any((g) => g.gunName == _mountGun)
                        ? _mountGun
                        : null,
                    decoration: InputDecoration(
                        labelText: tr('cab_pick_gun_owned')),
                    items: [
                      for (final g in owned)
                        DropdownMenuItem(
                            value: g.gunName, child: Text(g.gunName)),
                    ],
                    onChanged: (v) {
                      if (v != null) setState(() => _mountGun = v);
                    },
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: _pickMountDate,
                    child: InputDecorator(
                      decoration: InputDecoration(
                          labelText: tr('cab_mount_date')),
                      child: Text(_mountDate),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFE86A1C)),
                    onPressed: _addMount,
                    child: Text(tr('cab_mount_add'),
                        style: const TextStyle(color: Colors.white)),
                  ),
                ],
                const SizedBox(height: 12),
                if (mountGroups.isEmpty)
                  Text(tr('cab_mounts_empty'),
                      style: const TextStyle(color: Colors.grey))
                else
                  ...mountGroups.entries.map((entry) => Card(
                        child: ExpansionTile(
                          title: Text(entry.key),
                          subtitle: Text(
                              '${entry.value.length} ${tr('cab_mount_unit')}'),
                          children: entry.value.map((m) {
                            return ListTile(
                              title: Text(m.accessoryId),
                              subtitle:
                                  Text(_dateText(m.mountDateMs)),
                              trailing: IconButton(
                                icon:
                                    const Icon(Icons.delete_outline),
                                onPressed: () {
                                  setState(() => _mounts.remove(m));
                                  _saveMounts();
                                },
                              ),
                            );
                          }).toList(),
                        ),
                      )),
              ],
            ),
          ),
        );
      },
    );
  }
}
