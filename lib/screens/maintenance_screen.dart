import 'dart:convert';
import '../i18n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../app_log.dart';
import '../community_store.dart';
import '../widgets/app_top_bar.dart';

/// 保养清洁换件记录：工具向，不用登录，纯本机记录。
/// 经 gunsmap/prefs 存本机（key maintenance_log_v1），重启不丢。
/// 设计原则：射手记得住“上次保养后又打了多少”，记不住“这把枪
/// 一辈子累计打了多少”，所以发数一律记“间隔”不记“累计”：
/// - 枪在收藏柜里且记了发数：保养时自动拍一张收藏柜发数快照，
///   间隔 = 本次快照 - 上次快照，射手什么都不用填；
/// - 没进收藏柜：只填“自上次保养后约打了”，约数即可，不知道可空。
/// 旧版字段 roundsAt（语义不清的“当时已打发数”）只用于展示旧记录，
/// 新记录不再写它；不教拆解、不教改装、不涉及制造与交易内容。
class MaintenanceRecord {
  String gunName;
  String date;
  String type;
  String detail;
  int roundsAt;
  int roundsSince;
  int snapshotRounds;
  MaintenanceRecord(
      {required this.gunName,
      required this.date,
      required this.type,
      required this.detail,
      this.roundsAt = 0,
      this.roundsSince = -1,
      this.snapshotRounds = -1});

  Map<String, dynamic> toJson() => {
        'gunName': gunName,
        'date': date,
        'type': type,
        'detail': detail,
        'roundsAt': roundsAt,
        'roundsSince': roundsSince,
        'snapshotRounds': snapshotRounds,
      };

  factory MaintenanceRecord.fromJson(Map<String, dynamic> j) =>
      MaintenanceRecord(
        gunName: j['gunName'] as String? ?? '',
        date: j['date'] as String? ?? '',
        type: j['type'] as String? ?? '清洁',
        detail: j['detail'] as String? ?? '',
        roundsAt: (j['roundsAt'] as num?)?.toInt() ?? 0,
        roundsSince: (j['roundsSince'] as num?)?.toInt() ?? -1,
        snapshotRounds: (j['snapshotRounds'] as num?)?.toInt() ?? -1,
      );
}

class MaintenanceScreen extends StatefulWidget {
  const MaintenanceScreen({super.key});

  @override
  State<MaintenanceScreen> createState() => _MaintenanceScreenState();
}

String _maintTypeLabel(String t) {
  switch (t) {
    case '清洁':
      return tr('maint_type_clean');
    case '换件':
      return tr('maint_type_parts');
    case '检查':
      return tr('maint_type_check');
    default:
      return t;
  }
}

class _MaintenanceScreenState extends State<MaintenanceScreen> {
  static const _prefsChannel = MethodChannel('gunsmap/prefs');
  static const _prefsKey = 'maintenance_log_v1';
  static const _manualGun = '__manual__';
  final _records = <MaintenanceRecord>[];
  final _gunCtrl = TextEditingController();
  final _detailCtrl = TextEditingController();
  final _roundsCtrl = TextEditingController();
  String _type = '清洁';
  String _date = '';
  String _selectedGun = _manualGun;

  @override
  void initState() {
    super.initState();
    _date = _today();
    if (_collectionGuns.isNotEmpty) {
      _selectedGun = _collectionGuns.first.gunName;
    }
    _load();
  }

  @override
  void dispose() {
    _gunCtrl.dispose();
    _detailCtrl.dispose();
    _roundsCtrl.dispose();
    super.dispose();
  }

  List<CollectionItem> get _collectionGuns =>
      communityStore.current?.collection
          .where((i) => i.kind == 'gun')
          .toList() ??
      [];

  CollectionItem? _collectionGun(String name) {
    for (final g in _collectionGuns) {
      if (g.gunName == name) return g;
    }
    return null;
  }

  Future<void> _load() async {
    try {
      final raw = await _prefsChannel
          .invokeMethod<String>('getString', {'key': _prefsKey})
          .timeout(const Duration(seconds: 2));
      if (raw == null || raw.isEmpty || !mounted) return;
      final list = (jsonDecode(raw) as List)
          .map((e) => MaintenanceRecord.fromJson(e as Map<String, dynamic>))
          .toList();
      list.sort((a, b) => b.date.compareTo(a.date));
      setState(() {
        _records
          ..clear()
          ..addAll(list);
      });
    } catch (e) {
      appLog('prefs', '保养记录读取失败：$e');
    }
  }

  void _save() {
    try {
      _prefsChannel.invokeMethod('setString', {
        'key': _prefsKey,
        'value': jsonEncode(_records.map((e) => e.toJson()).toList()),
      });
    } catch (e) {
      appLog('prefs', '保养记录保存失败：$e');
    }
  }

  String _today() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  int _daysAgo(String date) {
    final d = DateTime.tryParse(date);
    if (d == null) return -1;
    return DateTime.now().difference(d).inDays;
  }

  Future<void> _pickDate() async {
    final initial = DateTime.tryParse(_date) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked == null) return;
    setState(() {
      _date =
          '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
    });
  }

  String get _resolvedGun {
    if (_selectedGun != _manualGun &&
        _collectionGuns.any((g) => g.gunName == _selectedGun)) {
      return _selectedGun;
    }
    return _gunCtrl.text.trim();
  }

  void _add() {
    final gun = _resolvedGun;
    final detail = _detailCtrl.text.trim();
    if (gun.isEmpty || detail.isEmpty) return;
    var roundsSince = -1;
    var snapshot = -1;
    final linked = _collectionGun(gun);
    if (linked != null) {
      // 收藏柜已记发数：拍快照，间隔自动算，不用射手填。
      snapshot = linked.rounds;
      MaintenanceRecord? prior;
      for (final r in _records) {
        if (r.gunName == gun && r.snapshotRounds >= 0) {
          prior = r;
          break;
        }
      }
      if (prior != null) {
        roundsSince = snapshot - prior.snapshotRounds;
        if (roundsSince < 0) roundsSince = 0;
      }
    } else {
      final manual = int.tryParse(_roundsCtrl.text.trim());
      if (manual != null && manual >= 0) roundsSince = manual;
    }
    setState(() {
      _records.insert(
          0,
          MaintenanceRecord(
              gunName: gun,
              date: _date,
              type: _type,
              detail: detail,
              roundsSince: roundsSince,
              snapshotRounds: snapshot));
      _records.sort((a, b) => b.date.compareTo(a.date));
      _detailCtrl.clear();
      _roundsCtrl.clear();
    });
    _save();
  }

  String _roundsLine(MaintenanceRecord r) {
    if (r.snapshotRounds >= 0) {
      var line = tr('maint_snapshot_prefix') + '${r.snapshotRounds}' + tr('ammo_rounds_suffix');
      if (r.roundsSince >= 0) line += tr('maint_since_mid') + '${r.roundsSince}' + tr('maint_since_mid_suffix');
      return line;
    }
    if (r.roundsSince >= 0) return tr('maint_since_prefix') + '${r.roundsSince}' + tr('maint_since_suffix');
    if (r.roundsAt > 0) return tr('maint_legacy_prefix') + '${r.roundsAt}' + tr('maint_legacy_suffix');
    return '';
  }

  String get _detailHint {
    switch (_type) {
      case '换件':
        return tr('maint_hint_parts');
      case '检查':
        return tr('maint_hint_check');
      default:
        return tr('maint_hint_default');
    }
  }

  @override
  Widget build(BuildContext context) {
    final guns = _collectionGuns;
    final gunValue =
        guns.any((g) => g.gunName == _selectedGun) ? _selectedGun : _manualGun;
    final linked = gunValue != _manualGun ? _collectionGun(gunValue) : null;
    MaintenanceRecord? priorSnapshot;
    if (linked != null) {
      for (final r in _records) {
        if (r.gunName == linked.gunName && r.snapshotRounds >= 0) {
          priorSnapshot = r;
          break;
        }
      }
    }
    final groups = <String, List<MaintenanceRecord>>{};
    for (final r in _records) {
      groups.putIfAbsent(r.gunName, () => []).add(r);
    }
    return Scaffold(
      appBar: SubPageAppBar(title: tr('maint_title')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(tr('maint_note'),
              style: TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 16),
          Text(tr('maint_add_title'),
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (guns.isNotEmpty) ...[
            DropdownButtonFormField<String>(
              initialValue: gunValue,
              decoration: InputDecoration(labelText: tr('maint_gun_label')),
              items: [
                for (final g in guns)
                  DropdownMenuItem(value: g.gunName, child: Text(g.gunName)),
                DropdownMenuItem(
                    value: _manualGun, child: Text(tr('maint_other_manual'))),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _selectedGun = v);
              },
            ),
            const SizedBox(height: 8),
          ],
          if (gunValue == _manualGun) ...[
            TextField(
                controller: _gunCtrl,
                decoration: InputDecoration(labelText: tr('maint_gun_name'))),
            const SizedBox(height: 8),
          ],
          InkWell(
            onTap: _pickDate,
            child: InputDecorator(
              decoration: InputDecoration(
                  labelText: tr('maint_date_label')),
              child: Text(_date),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            children: ['清洁', '换件', '检查']
                .map((t) => ChoiceChip(
                      label: Text(_maintTypeLabel(t)),
                      selected: _type == t,
                      onSelected: (_) => setState(() => _type = t),
                    ))
                .toList(),
          ),
          const SizedBox(height: 8),
          TextField(
              controller: _detailCtrl,
              decoration: InputDecoration(labelText: _detailHint)),
          const SizedBox(height: 8),
          if (linked != null) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tr('maint_linked_prefix') + '${linked.rounds}' + tr('maint_linked_suffix'),
                        style: const TextStyle(fontSize: 13)),
                    const SizedBox(height: 4),
                    Text(
                        priorSnapshot == null
                            ? tr('maint_first_note')
                            : tr('maint_auto_prefix') + '${_clampDelta(linked.rounds, priorSnapshot.snapshotRounds)}' + tr('maint_auto_suffix'),
                        style:
                            const TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
              ),
            ),
          ] else ...[
            TextField(
                controller: _roundsCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                    labelText: tr('maint_since_input'))),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              children: [
                ('未记', ''),
                ('约 50 发', '50'),
                ('约 100 发', '100'),
                ('约 300 发', '300'),
                ('约 500 发', '500'),
              ]
                  .map((e) => ChoiceChip(
                        label: Text(e.$1 == '未记' ? tr('maint_quick_none') : tr('maint_quick_prefix') + e.$2 + tr('ammo_rounds_suffix')),
                        selected:
                            e.$2.isNotEmpty && _roundsCtrl.text == e.$2,
                        onSelected: (_) =>
                            setState(() => _roundsCtrl.text = e.$2),
                      ))
                  .toList(),
            ),
          ],
          const SizedBox(height: 12),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFE86A1C)),
            onPressed: _add,
            child:
                Text(tr('maint_add_btn'), style: TextStyle(color: Colors.white)),
          ),
          const SizedBox(height: 20),
          if (_records.isEmpty)
            Text(tr('maint_empty'),
                style: TextStyle(color: Colors.grey))
          else
            ...groups.entries.map((entry) {
              final latest = entry.value.first;
              final days = _daysAgo(latest.date);
              final current = _collectionGun(entry.key);
              var sinceLine = '';
              if (current != null && latest.snapshotRounds >= 0) {
                sinceLine =
                    tr('maint_since_more_prefix') + '${_clampDelta(current.rounds, latest.snapshotRounds)}' + tr('maint_since_more_suffix');
              }
              return Card(
                child: ExpansionTile(
                  title: Text(entry.key),
                  subtitle: Text(
                      tr('maint_last_prefix') + latest.date + (days >= 0 ? tr('dope_days_ago_prefix') + '$days' + tr('dope_days_ago_suffix') : '') + tr('maint_last_mid') + '${entry.value.length}' + tr('maint_last_suffix') + sinceLine),
                  children: entry.value.map((r) {
                    final line = _roundsLine(r);
                    return ListTile(
                      title: Text('${_maintTypeLabel(r.type)} · ${r.detail}'),
                      subtitle: Text(
                          line.isEmpty ? r.date : '${r.date} · $line'),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () {
                          setState(() => _records.remove(r));
                          _save();
                        },
                      ),
                    );
                  }).toList(),
                ),
              );
            }),
        ],
      ),
    );
  }

  int _clampDelta(int now, int before) =>
      now - before < 0 ? 0 : now - before;
}
