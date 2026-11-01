import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../community_store.dart';
import '../data.dart';
import '../english_terms.dart';
import '../i18n.dart';
import '../models.dart';
import '../widgets/app_toast.dart';
import '../widgets/app_top_bar.dart';
import '../widgets/bar_chart.dart';
import '../widgets/glass_dialog.dart';
import '../widgets/zero_assistant_card.dart';
import 'ammo_inventory_screen.dart';
import 'maintenance_screen.dart';

/// 单枪射击数据本（DOPE）：归零卡 + 该枪靶场成绩趋势 + 常用弹药 +
/// 收藏柜发数与上次保养。归零记录只存本机，不用登录；成绩、收藏、
/// 保养来自本机已有数据，没有就明示、不编。
class DopeScreen extends StatefulWidget {
  final Gun gun;
  const DopeScreen({super.key, required this.gun});

  @override
  State<DopeScreen> createState() => _DopeScreenState();
}

class _ZeroRecord {
  final String gunName;
  final int distance;
  final String ammo;
  final String clicks;
  final String note;
  final String date;
  _ZeroRecord({
    required this.gunName,
    required this.distance,
    required this.ammo,
    required this.clicks,
    required this.note,
    required this.date,
  });
  Map<String, dynamic> toJson() => {
        'gunName': gunName,
        'distance': distance,
        'ammo': ammo,
        'clicks': clicks,
        'note': note,
        'date': date,
      };
  static _ZeroRecord fromJson(Map<String, dynamic> j) => _ZeroRecord(
        gunName: j['gunName'] as String? ?? '',
        distance: (j['distance'] as num? ?? 100).toInt(),
        ammo: j['ammo'] as String? ?? '',
        clicks: j['clicks'] as String? ?? '',
        note: j['note'] as String? ?? '',
        date: j['date'] as String? ?? '',
      );
}

class _DopeScreenState extends State<DopeScreen> {
  static const _prefsChannel = MethodChannel('gunsmap/prefs');
  static const _zeroKey = 'dope_zero_v1';
  var _zeros = <_ZeroRecord>[];
  var _lastMaintenance = '';
  var _maintenanceDays = -1;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final raw = await _prefsChannel
          .invokeMethod<String>('getString', {'key': _zeroKey})
          .timeout(const Duration(seconds: 2));
      if (raw != null && raw.isNotEmpty && mounted) {
        setState(() {
          _zeros = (jsonDecode(raw) as List)
              .map((e) => _ZeroRecord.fromJson(e as Map<String, dynamic>))
              .where((z) => z.gunName == widget.gun.name)
              .toList();
        });
      }
    } catch (_) {}
    try {
      final raw = await _prefsChannel
          .invokeMethod<String>(
              'getString', {'key': 'maintenance_log_v1'})
          .timeout(const Duration(seconds: 2));
      if (raw != null && raw.isNotEmpty && mounted) {
        final recs = (jsonDecode(raw) as List)
            .map((e) => MaintenanceRecord.fromJson(e as Map<String, dynamic>))
            .where((r) => r.gunName == widget.gun.name)
            .toList();
        if (recs.isNotEmpty) {
          recs.sort((a, b) => b.date.compareTo(a.date));
          final latest = DateTime.tryParse(recs.first.date);
          setState(() {
            _lastMaintenance = recs.first.date;
            _maintenanceDays = latest == null
                ? -1
                : DateTime.now().difference(latest).inDays;
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _saveZeros() async {
    try {
      final raw = await _prefsChannel
          .invokeMethod<String>('getString', {'key': _zeroKey})
          .timeout(const Duration(seconds: 2));
      var all = <_ZeroRecord>[];
      if (raw != null && raw.isNotEmpty) {
        all = (jsonDecode(raw) as List)
            .map((e) => _ZeroRecord.fromJson(e as Map<String, dynamic>))
            .where((z) => z.gunName != widget.gun.name)
            .toList();
      }
      all.addAll(_zeros);
      await _prefsChannel.invokeMethod(
          'setString', {'key': _zeroKey, 'value': jsonEncode(all)});
    } catch (_) {}
  }

  /// 归零卡填写：距离与弹药点选、调节方向+格数步进、日期可改；
  /// 卡片点按进同一框改，旧自由文本调节串解析不了的原样保留。
  Future<void> _editZero({
    _ZeroRecord? existing,
    int? initialDistance,
    String? initialHDir,
    int? initialHClicks,
    String? initialVDir,
    int? initialVClicks,
  }) async {
    // 弹药点选：该枪成绩用过的弹 + 同口径库存名 + 口径常用弹，去重取 8。
    final ammoChips = <String>[];
    void addChip(String v) {
      final t = v.trim();
      if (t.isNotEmpty && !ammoChips.contains(t)) ammoChips.add(t);
    }

    final account = communityStore.current;
    for (final sc in account?.rangeScores ?? []) {
      if (sc.gunName == widget.gun.name) addChip(sc.ammo);
    }
    try {
      final items = await loadAmmoItems();
      for (final it in items) {
        if (it.caliber == widget.gun.caliber) addChip(it.name);
      }
    } catch (_) {}
    for (final c in caliberInfos) {
      if (c.caliber == widget.gun.caliber) {
        for (final b in c.bullets) addChip(b);
      }
    }
    final chips = ammoChips.take(8).toList();

    // 旧调节串回填方向与格数；解析不了的旧串留着不丢。
    var hDir = '不动';
    var hClicks = 0;
    var vDir = '不动';
    var vClicks = 0;
    var legacyClicks = '';
    final oldClicks = existing?.clicks ?? '';
    if (oldClicks.isNotEmpty) {
      final hm = RegExp(r'水平向(左|右)\s*(\d+)\s*格').firstMatch(oldClicks);
      final vm = RegExp(r'垂直向(上|下)\s*(\d+)\s*格').firstMatch(oldClicks);
      if (hm != null) {
        hDir = '向${hm.group(1)}';
        hClicks = int.tryParse(hm.group(2)!) ?? 0;
      }
      if (vm != null) {
        vDir = '向${vm.group(1)}';
        vClicks = int.tryParse(vm.group(2)!) ?? 0;
      }
      if (hm == null && vm == null) legacyClicks = oldClicks;
    }
    // 助手带入：新卡直接用算出的距离与格数，不用再手填一遍。
    if (existing == null) {
      if (initialHDir != null) hDir = initialHDir;
      if (initialHClicks != null) hClicks = initialHClicks;
      if (initialVDir != null) vDir = initialVDir;
      if (initialVClicks != null) vClicks = initialVClicks;
    }
    final now = DateTime.now();
    final today =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final distCtrl = TextEditingController(
        text: '${existing?.distance ?? initialDistance ?? 100}');
    final ammoCtrl = TextEditingController(text: existing?.ammo ?? '');
    final noteCtrl = TextEditingController(text: existing?.note ?? '');
    var date = existing?.date ?? today;

    String _dirLabel(String v) {
      switch (v) {
        case '不动':
          return tr('dope_dir_none');
        case '向左':
          return tr('zero_dir_left');
        case '向右':
          return tr('zero_dir_right');
        case '向上':
          return tr('zero_dir_up');
        case '向下':
          return tr('zero_dir_down');
        default:
          return v;
      }
    }

    Widget dirRow(
      String label,
      List<String> options,
      String dir,
      int clicks,
      void Function(String) onDir,
      void Function(int) onClicks,
    ) {
      return Row(
        children: [
          SizedBox(width: 40, child: Text(label)),
          for (final o in options)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: ChoiceChip(
                label: Text(_dirLabel(o), style: const TextStyle(fontSize: 12)),
                selected: dir == o,
                onSelected: (_) => onDir(o),
              ),
            ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.remove, size: 18),
            onPressed: clicks > 0 ? () => onClicks(clicks - 1) : null,
          ),
          Text('$clicks' + tr('dope_clicks_suffix'), style: const TextStyle(fontSize: 13)),
          IconButton(
            icon: const Icon(Icons.add, size: 18),
            onPressed: () => onClicks(clicks + 1),
          ),
        ],
      );
    }

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => GlassDialog(
          title: existing == null ? tr('dope_new_card') : tr('dope_edit_card'),
          subtitle: gunDisplayName(widget.gun),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: distCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: tr('dope_zero_dist_label'),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(12))),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                children: [
                  for (final d in [50, 100, 200, 300])
                    ActionChip(
                      label: Text('$d' + tr('range_unit_m')),
                      onPressed: () =>
                          setDialogState(() => distCtrl.text = '$d'),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ammoCtrl,
                decoration: InputDecoration(
                  labelText: tr('dope_ammo_label'),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(12))),
                ),
              ),
              if (chips.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final c in chips)
                      ActionChip(
                        label: Text(c),
                        onPressed: () =>
                            setDialogState(() => ammoCtrl.text = c),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              Text(tr('dope_clicks_title'),
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              dirRow(tr('dope_dir_h'), ['不动', '向左', '向右'], hDir, hClicks,
                  (v) => setDialogState(() => hDir = v),
                  (v) => setDialogState(() => hClicks = v)),
              dirRow(tr('dope_dir_v'), ['不动', '向上', '向下'], vDir, vClicks,
                  (v) => setDialogState(() => vDir = v),
                  (v) => setDialogState(() => vClicks = v)),
              if (legacyClicks.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(tr('dope_legacy_prefix') + legacyClicks + tr('dope_legacy_suffix'),
                      style: const TextStyle(color: Colors.grey, fontSize: 12)),
                ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Text(tr('dope_date_prefix') + date),
                  TextButton(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: DateTime.tryParse(date) ?? now,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        setDialogState(() => date =
                            '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}');
                      }
                    },
                    child: Text(tr('dope_change_date')),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              TextField(
                controller: noteCtrl,
                decoration: InputDecoration(
                  labelText: tr('dope_note_label'),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(12))),
                ),
              ),
            ],
          ),
          actions: [
            glassCancelButton(ctx, tr('cancel')),
            glassPrimaryButton(ctx, tr('save'), popTrue: true),
          ],
        ),
      ),
    );
    if (saved == true && mounted) {
      final parts = <String>[];
      if (hDir != '不动' && hClicks > 0) parts.add('水平$hDir $hClicks 格');
      if (vDir != '不动' && vClicks > 0) parts.add('垂直$vDir $vClicks 格');
      var clicks = parts.join(' · ');
      if (clicks.isEmpty && legacyClicks.isNotEmpty) clicks = legacyClicks;
      final rec = _ZeroRecord(
        gunName: widget.gun.name,
        distance: int.tryParse(distCtrl.text) ?? 100,
        ammo: ammoCtrl.text.trim(),
        clicks: clicks,
        note: noteCtrl.text.trim(),
        date: date,
      );
      setState(() {
        if (existing == null) {
          _zeros.insert(0, rec);
        } else {
          final i = _zeros.indexOf(existing);
          if (i >= 0) {
            _zeros[i] = rec;
          } else {
            _zeros.insert(0, rec);
          }
        }
      });
      await _saveZeros();
      showAppToast(context, existing == null ? tr('dope_saved') : tr('dope_updated'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final grey = dark ? const Color(0xFF8A8578) : const Color(0xFF9A917F);
    final gun = widget.gun;
    final account = communityStore.current;
    final scores = (account?.rangeScores ?? [])
        .where((s) => s.gunName == gun.name)
        .toList();
    // 分组 MOA 趋势图：取可算 MOA 的成绩按日期正序，最近 20 组。
    final moaScores = scores
        .where((s) => s.groupSize > 0 && s.distance > 0)
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    final moaChartScores = moaScores.length > 20
        ? moaScores.sublist(moaScores.length - 20)
        : moaScores;
    // 常用弹药：按该枪成绩里的弹药名计频，前 5。
    final ammoCount = <String, int>{};
    for (final s in scores) {
      if (s.ammo.trim().isNotEmpty) {
        ammoCount[s.ammo.trim()] = (ammoCount[s.ammo.trim()] ?? 0) + 1;
      }
    }
    final topAmmo = ammoCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    CollectionItem? collection;
    for (final c in account?.collection ?? []) {
      if (c.gunName == gun.name && c.kind == 'gun') collection = c;
    }
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: SubPageAppBar(title: '${gunDisplayName(gun)} · ' + tr('tool_dope')),
      body: SafeArea(
        top: true,
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8 + kToolbarHeight, 16, 110),
          children: [
            Text(gun.vendor.isNotEmpty
                ? '${vendorDisplay(gun.vendor)} · ${gun.caliber}'
                : gun.caliber,
                style: TextStyle(color: grey, fontSize: 13)),
            const SizedBox(height: 16),
            ZeroAssistantCard(
              onRecord: (r) => _editZero(
                initialDistance: r.distanceM,
                initialHDir: r.hDir,
                initialHClicks: r.hClicks,
                initialVDir: r.vDir,
                initialVClicks: r.vClicks,
              ),
            ),
            const SizedBox(height: 16),
            // 归零卡
            Row(
              children: [
                Text(tr('dope_cards_title'),
                    style:
                        TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => _editZero(),
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(tr('dope_add_card')),
                ),
              ],
            ),
            const SizedBox(height: 4),
            if (_zeros.isEmpty)
              Text(tr('dope_no_cards'),
                  style: TextStyle(color: grey, fontSize: 13))
            else
              Text(tr('dope_cards_hint'),
                  style: TextStyle(color: grey, fontSize: 12)),
            for (final z in _zeros)
              Card(
                margin: const EdgeInsets.only(bottom: 6),
                child: ListTile(
                  title: Text('${z.distance}' + tr('range_unit_m') + tr('dope_zeroed_suffix') + ' · ${z.date}'),
                  subtitle: Text(
                      [
                        if (z.ammo.isNotEmpty) tr('dope_ammo_prefix') + z.ammo,
                        if (z.clicks.isNotEmpty) tr('dope_clicks_prefix') + z.clicks,
                        if (z.note.isNotEmpty) z.note,
                      ].join(' · '),
                      style: TextStyle(color: grey, fontSize: 12)),
                  onTap: () => _editZero(existing: z),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20),
                    onPressed: () async {
                      setState(() => _zeros.remove(z));
                      await _saveZeros();
                    },
                  ),
                ),
              ),
            const SizedBox(height: 16),
            // 分组趋势：该枪成绩按时间倒序，带 MOA。
            Text(tr('dope_trend_title'),
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            if (account == null)
              Text(tr('dope_trend_login_note'),
                  style: TextStyle(color: grey, fontSize: 13))
            else if (scores.isEmpty)
              Text(tr('dope_trend_empty'),
                  style: TextStyle(color: grey, fontSize: 13)),
            if (moaChartScores.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(tr('chart_moa_title'),
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 6),
                  Text('（${tr('chart_moa_unit')}）',
                      style: TextStyle(color: grey, fontSize: 12)),
                ],
              ),
              const SizedBox(height: 4),
              SimpleBarChart(
                entries: moaChartScores
                    .map((s) => BarChartEntry(
                          label:
                              '${s.date.month.toString().padLeft(2, '0')}-${s.date.day.toString().padLeft(2, '0')}',
                          value: s.groupSize / (s.distance * 0.02909),
                          valueText: (s.groupSize / (s.distance * 0.02909))
                              .toStringAsFixed(2),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 8),
            ],
            for (final s in scores.take(20))
              Card(
                margin: const EdgeInsets.only(bottom: 6),
                child: ListTile(
                  title: Text(s.groupSize > 0
                      ? tr('dope_group_prefix') + '${s.groupSize.toStringAsFixed(1)}' + tr('dope_group_suffix_cm') +
                          '${s.distance > 0 ? '（${(s.groupSize / (s.distance * 0.02909)).toStringAsFixed(2)} MOA）' : ''}'
                      : tr('dope_no_group')),
                  subtitle: Text(
                      '${s.date.toString().substring(0, 10)} · ${s.distance}' + tr('range_unit_m') + ' · ${s.shots}' + tr('ammo_rounds_suffix') +
                      '${s.ammo.isNotEmpty ? ' · ${s.ammo}' : ''}',
                      style: TextStyle(color: grey, fontSize: 12)),
                ),
              ),
            const SizedBox(height: 16),
            Text(tr('dope_common_ammo'),
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            if (topAmmo.isEmpty)
              Text(tr('dope_no_ammo_stats'),
                  style: TextStyle(color: grey, fontSize: 13)),
            for (final e in topAmmo.take(5))
              Card(
                margin: const EdgeInsets.only(bottom: 6),
                child: ListTile(
                  title: Text(e.key),
                  trailing: Text('${e.value}' + tr('dope_times_suffix'),
                      style: TextStyle(color: grey, fontSize: 13)),
                ),
              ),
            const SizedBox(height: 16),
            Text(tr('dope_collect_maint'),
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(
                collection == null
                    ? tr('dope_no_collection')
                    : tr('dope_collection_prefix') + '${collection.rounds}' + tr('ammo_rounds_suffix'),
                style: TextStyle(color: grey, fontSize: 13)),
            const SizedBox(height: 4),
            Text(
                _lastMaintenance.isEmpty
                    ? tr('dope_no_maintenance')
                    : tr('dope_last_maint_prefix') + _lastMaintenance +
                        '${_maintenanceDays >= 0 ? tr('dope_days_ago_prefix') + '$_maintenanceDays' + tr('dope_days_ago_suffix') : ''}',
                style: TextStyle(color: grey, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}
