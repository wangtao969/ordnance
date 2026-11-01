import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../data.dart';
import '../models.dart';
import '../widgets/app_toast.dart';
import '../widgets/glass_dialog.dart';
import '../community_store.dart';
import '../gun_cabinet_data.dart';
import '../i18n.dart';
import '../widgets/app_top_bar.dart';
import '../widgets/community_theme.dart';
import 'community_account_dialogs.dart';
import 'gun_picker_dialog.dart';
import 'ammo_inventory_screen.dart';
import 'reload_log_screen.dart';
import 'range_tools_screen.dart';
import '../sensors_api.dart';
import '../weather_api.dart';

/// 靶场成绩：分组、距离、发数，绑定枪种；成绩直接喂靶场勋章。
/// 顶部统计卡 + 按枪筛选 + 结构化卡片，成绩不再是一长串字；
/// 录入框里可勾选同步：从弹药库存扣发数、计入枪柜已打发数。
class CommunityRangeScreen extends StatefulWidget {
  const CommunityRangeScreen({super.key});

  @override
  State<CommunityRangeScreen> createState() => _CommunityRangeScreenState();
}

class _CommunityRangeScreenState extends State<CommunityRangeScreen> {
  String _filter = '全部';

  String _fmt(double v, [int digits = 2]) {
    var s = v.toStringAsFixed(digits);
    while (s.contains('.') && s.endsWith('0')) {
      s = s.substring(0, s.length - 1);
    }
    if (s.endsWith('.')) s = s.substring(0, s.length - 1);
    return s;
  }

  /// 姿势 / 靶型 / 天气显示映射：存量仍是中文原文（老记录不断裂），
  /// 只换显示；自由填写的天气文字不在固定表里，原样显示。
  String _trPosition(String v) {
    switch (v) {
      case '站姿':
        return tr('range_position_stand');
      case '跪姿':
        return tr('range_position_kneel');
      case '卧姿':
        return tr('range_position_prone');
      case '依托':
        return tr('range_position_supported');
      case '坐姿':
        return tr('range_position_sitting');
      default:
        return v;
    }
  }

  String _trTarget(String v) {
    switch (v) {
      case '胸环靶':
        return tr('range_target_chest');
      case '精度靶':
        return tr('range_target_precision');
      case '人形靶':
        return tr('range_target_silhouette');
      case '钢靶':
        return tr('range_target_steel');
      case '其他':
        return tr('range_target_other');
      default:
        return v;
    }
  }

  String _trWeather(String v) {
    switch (v) {
      case '晴':
        return tr('range_weather_sunny');
      case '阴':
        return tr('range_weather_cloudy');
      case '雨':
        return tr('range_weather_rainy');
      case '雪':
        return tr('range_weather_snowy');
      case '室内':
        return tr('range_weather_indoor');
      default:
        return v;
    }
  }

  Future<void> _addScore(BuildContext context,
      {Gun? presetGun, int? presetDist}) async {
    final gun = presetGun ?? await showGunPickerDialog(context);
    if (gun == null || !context.mounted) return;
    final distanceCtrl =
        TextEditingController(text: '${presetDist ?? 100}');
    // 弹药优先从库存选：该口径有库存时下拉点选，没有再手填。
    final stockItems = await loadAmmoItems();
    if (!context.mounted) return;
    final stockNames = stockItems
        .where((e) => e.caliber == gun.caliber)
        .map((e) => e.name)
        .toSet()
        .toList();
    var ammoChoice = stockNames.isNotEmpty ? stockNames.first : '手动填';
    // 已放行批次：成绩录入时可手选关联，配方卡靠批次号找实测成绩。
    var releasedBatches = <ReloadLogEntry>[];
    try {
      final raw = await const MethodChannel('gunsmap/prefs')
          .invokeMethod<String>('getString', {'key': 'reload_log_v1'})
          .timeout(const Duration(seconds: 2));
      if (raw != null && raw.isNotEmpty) {
        releasedBatches = (jsonDecode(raw) as List)
            .map((e) => ReloadLogEntry.fromJson(e as Map<String, dynamic>))
            .where((e) => e.released && e.batchNo.isNotEmpty)
            .toList();
      }
    } catch (_) {}
    var batchChoice = '不关联';
    // 同步勾选：扣库存只对同口径库存，计入枪柜只对已在枪柜档案里的枪。
    AmmoItem? deductItem;
    for (final item in stockItems) {
      if (item.caliber == gun.caliber) {
        deductItem = item;
        break;
      }
    }
    final deductItemFinal = deductItem;
    var deductStock = false;
    // 2.2.5 起发数归枪柜档案：先读枪柜档案，勾选与写回都走它，不再写收藏柜。
    final cabinetProfiles = await loadGunProfiles();
    final inCabinet =
        cabinetProfiles.any((p) => p.gunName == gun.name);
    var addToCollection = false;
    final shotsCtrl = TextEditingController(text: '5');
    final groupCtrl = TextEditingController(text: '');
    final scoreCtrl = TextEditingController(text: '');
    final ammoCtrl = TextEditingController(text: '');
    final weatherCtrl = TextEditingController(text: '');
    final windCtrl = TextEditingController(text: '');
    final noteCtrl = TextEditingController();
    // 传感器融合：指南针记射向（随成绩保存），水平仪只显示角度（不保存）。
    var heading = '';
    var levelText = '';
    var position = '站姿';
    var target = '胸环靶';
    const positions = ['站姿', '跪姿', '卧姿', '依托', '坐姿'];
    const targets = ['胸环靶', '精度靶', '人形靶', '钢靶', '其他'];
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (ctx, setDialogState) => GlassDialog(
          title: gun.name,
          subtitle: gun.caliber.isNotEmpty ? tr('range_caliber_prefix') + gun.caliber : null,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: distanceCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: tr('range_distance_label'),
                  border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: shotsCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: tr('range_shots_label'),
                  border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: groupCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: tr('range_group_label'),
                  border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: scoreCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: tr('range_score_label'),
                  border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: position,
                decoration: InputDecoration(
                  labelText: tr('range_position_label'),
                  border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                ),
                items: positions
                    .map((e) => DropdownMenuItem(value: e, child: Text(_trPosition(e))))
                    .toList(),
                onChanged: (v) =>
                    setDialogState(() => position = v ?? position),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: target,
                decoration: InputDecoration(
                  labelText: tr('range_target_label'),
                  border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                ),
                items: targets
                    .map((e) => DropdownMenuItem(value: e, child: Text(_trTarget(e))))
                    .toList(),
                onChanged: (v) =>
                    setDialogState(() => target = v ?? target),
              ),
              const SizedBox(height: 12),
              if (stockNames.isNotEmpty) ...[
                Row(
                  children: [
                    Text(tr('range_ammo_label')),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButton<String>(
                        value: ammoChoice,
                        isExpanded: true,
                        items: [
                          ...stockNames.map((n) =>
                              DropdownMenuItem(value: n, child: Text(n))),
                          DropdownMenuItem(
                              value: '手动填', child: Text(tr('range_manual'))),
                        ],
                        onChanged: (v) => setDialogState(
                            () => ammoChoice = v ?? ammoChoice),
                      ),
                    ),
                  ],
                ),
                if (ammoChoice == '手动填') ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: ammoCtrl,
                    decoration: InputDecoration(
                      labelText: tr('range_ammo_hint'),
                      border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                    ),
                  ),
                ],
              ] else
                TextField(
                  controller: ammoCtrl,
                  decoration: InputDecoration(
                    labelText: tr('range_ammo_hint'),
                    border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                  ),
                ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                children: ['晴', '阴', '雨', '雪', '室内']
                    .map((w) => ActionChip(
                          label: Text(_trWeather(w)),
                          onPressed: () =>
                              setDialogState(() => weatherCtrl.text = w),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: weatherCtrl,
                      decoration: InputDecoration(
                        labelText: tr('range_weather_label'),
                        border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: windCtrl,
                      decoration: InputDecoration(
                        labelText: tr('range_wind_label'),
                        border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(heading.isEmpty
                        ? tr('trip_heading')
                        : '${tr('trip_heading')} $heading'),
                  ),
                  OutlinedButton(
                    onPressed: () async {
                      final r = await getCompassHeading();
                      if (r.value != null) {
                        final deg = r.value!;
                        setDialogState(() => heading =
                            '${deg.toStringAsFixed(0)}° ${compassDir(deg)}');
                        showAppToast(context, tr('trip_heading_saved'));
                      } else {
                        showAppToast(context, tr('trip_heading_failed'));
                      }
                    },
                    child: Text(tr('trip_record_heading')),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(levelText.isEmpty
                        ? tr('trip_level')
                        : '${tr('trip_level')} $levelText'),
                  ),
                  OutlinedButton(
                    onPressed: () async {
                      final r = await getRollDegrees();
                      if (r.value != null) {
                        setDialogState(() => levelText =
                            '${r.value!.toStringAsFixed(1)}°');
                      } else {
                        showAppToast(context, tr('trip_level_failed'));
                      }
                    },
                    child: Text(tr('trip_level_read')),
                  ),
                ],
              ),
              if (releasedBatches.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(tr('range_batch_label'),
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                DropdownButton<String>(
                  value: batchChoice,
                  isExpanded: true,
                  items: [
                    DropdownMenuItem(
                        value: '不关联', child: Text(tr('range_none'))),
                    for (final b in releasedBatches)
                      DropdownMenuItem(
                        value: b.batchNo,
                        child: Text(
                            '${b.batchNo}${tr('range_paren_open')}${b.caliber} ${b.bullet}${tr('range_paren_close')}',
                            overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: (v) =>
                      setDialogState(() => batchChoice = v ?? '不关联'),
                ),
              ],
              if (deductItemFinal != null || inCabinet) ...[
                const SizedBox(height: 12),
                Text(tr('range_sync_label'),
                    style: TextStyle(fontWeight: FontWeight.bold)),
                if (deductItemFinal != null)
                  CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text(tr('range_deduct_prefix') + deductItemFinal.name + tr('range_deduct_suffix')),
                    value: deductStock,
                    onChanged: (v) =>
                        setDialogState(() => deductStock = v ?? false),
                  ),
                if (inCabinet)
                  CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text(tr('range_count_rounds')),
                    value: addToCollection,
                    onChanged: (v) => setDialogState(
                        () => addToCollection = v ?? false),
                  ),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: noteCtrl,
                decoration: InputDecoration(
                  labelText: tr('range_note_label'),
                  border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                ),
              ),
            ],
          ),
          actions: [
            glassCancelButton(dialogContext, tr('cancel')),
            glassPrimaryButton(dialogContext, tr('save'), popTrue: true),
          ],
        ),
      ),
    );
    if (saved == true && context.mounted) {
      final ammoText = stockNames.isNotEmpty && ammoChoice != '手动填'
          ? ammoChoice
          : ammoCtrl.text.trim();
      final shots = int.tryParse(shotsCtrl.text) ?? 5;
      communityStore.addRangeScore(RangeScore(
        gunName: gun.name,
        distance: int.tryParse(distanceCtrl.text) ?? 100,
        shots: shots,
        groupSize: double.tryParse(groupCtrl.text) ?? 0,
        note: noteCtrl.text.trim(),
        caliber: gun.caliber,
        ammo: ammoText,
        position: position,
        target: target,
        score: scoreCtrl.text.trim(),
        weather: weatherCtrl.text.trim(),
        wind: windCtrl.text.trim(),
        batchNo: batchChoice == '不关联' ? '' : batchChoice,
        heading: heading,
      ));
      showAppToast(context, tr('range_saved'));
      if (deductStock && deductItemFinal != null && shots > 0) {
        final used = shots > deductItemFinal.quantity
            ? deductItemFinal.quantity
            : shots;
        if (used > 0) {
          deductItemFinal.quantity -= used;
          await saveAmmoItems(stockItems);
          await addAmmoMovement(AmmoMovement(
              date: DateTime.now().toString().substring(0, 10),
              name: deductItemFinal.name,
              caliber: deductItemFinal.caliber,
              delta: -used,
              reason: '打靶'));
        }
      }
      // 计入枪柜发数：只改已在枪柜档案里的枪，并同步内存镜像。
      if (addToCollection && shots > 0) {
        final idx =
            cabinetProfiles.indexWhere((p) => p.gunName == gun.name);
        if (idx >= 0) {
          cabinetProfiles[idx].rounds += shots;
          await saveGunProfiles(cabinetProfiles);
          cabinetProfilesCache = cabinetProfiles;
        }
      }
    }
    distanceCtrl.dispose();
    shotsCtrl.dispose();
    groupCtrl.dispose();
    scoreCtrl.dispose();
    ammoCtrl.dispose();
    weatherCtrl.dispose();
    windCtrl.dispose();
    noteCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final grey = communitySecondary(dark);
    return AnimatedBuilder(
      animation: communityStore,
      builder: (_, __) {
        final me = communityStore.current;
        return Scaffold(
          appBar: SubPageAppBar(title: tr('range_title')),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  const Spacer(),
                  if (me != null)
                    OutlinedButton.icon(
                      onPressed: () => _addScore(context),
                      icon: const Icon(Icons.add, size: 18),
                      label: Text(tr('range_add_one')),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              if (me == null)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(tr('not_logged'),
                            style: const TextStyle(
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            ElevatedButton(
                              onPressed: () => showLoginDialog(context),
                              child: Text(tr('login')),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton(
                              onPressed: () => showRegisterDialog(context),
                              child: Text(tr('register')),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                )
              else if (me.rangeScores.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 32),
                    child: Column(
                      children: [
                        Icon(Icons.gps_fixed, size: 48, color: grey),
                        const SizedBox(height: 12),
                        Text(tr('range_empty'),
                            style: TextStyle(color: grey)),
                        const SizedBox(height: 4),
                        Text(tr('range_empty_hint'),
                            style: TextStyle(color: grey, fontSize: 12)),
                      ],
                    ),
                  ),
                )
              else
                Builder(
                  builder: (_) {
                    final scores = me.rangeScores;
                    final totalShots =
                        scores.fold<int>(0, (sum, e) => sum + e.shots);
                    RangeScore? best;
                    for (final r in scores) {
                      if (r.groupSize > 0 &&
                          (best == null || r.groupSize < best.groupSize)) {
                        best = r;
                      }
                    }
                    final gunNames =
                        scores.map((r) => r.gunName).toSet().toList();
                    final shown = _filter == '全部'
                        ? scores
                        : scores
                            .where((r) => r.gunName == _filter)
                            .toList();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${scores.length}' + tr('range_summary_times') + ' · ' + tr('range_summary_total') + '$totalShots' + tr('range_summary_shots'),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold)),
                                if (best != null)
                                  Text(
                                      best.distance > 0
                                          ? tr('range_best_prefix') + '${_fmt(best.groupSize)} ${tr('trip_cm')}${tr('range_paren_open')}${_fmt(best.groupSize / (best.distance * 0.02909))} MOA${tr('range_best_sep')}${best.distance} ${tr('trip_meter')}${tr('range_best_sep')}${best.gunName}${tr('range_paren_close')}'
                                          : tr('range_best_prefix') + '${_fmt(best.groupSize)} ${tr('trip_cm')}${tr('range_paren_open')}${best.gunName}${tr('range_paren_close')}',
                                      style: const TextStyle(
                                          color: Colors.grey, fontSize: 12)),
                                Text(
                                    tr('range_last_prefix') + CommunityStore.formatTime(scores.first.date),
                                    style: const TextStyle(
                                        color: Colors.grey, fontSize: 12)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 6,
                          children: ['全部', ...gunNames]
                              .map((g) => ChoiceChip(
                                    label: Text(g == '全部' ? tr('range_filter_all') : g),
                                    selected: _filter == g,
                                    onSelected: (_) =>
                                        setState(() => _filter = g),
                                  ))
                              .toList(),
                        ),
                        const SizedBox(height: 12),
                        if (shown.isEmpty)
                          Text(tr('range_no_scores_for_gun'),
                              style: TextStyle(color: Colors.grey))
                        else
                          ...shown.map((r) {
                            final moa = r.distance > 0 && r.groupSize > 0
                                ? r.groupSize / (r.distance * 0.02909)
                                : 0.0;
                            final details = [
                              if (r.position.isNotEmpty) _trPosition(r.position),
                              if (r.target.isNotEmpty) _trTarget(r.target),
                              if (r.ammo.isNotEmpty) r.ammo,
                              if (r.weather.isNotEmpty) r.weather,
                              if (r.wind.isNotEmpty) r.wind,
                              if (r.heading.isNotEmpty)
                                '${tr('trip_heading')} ${r.heading}',
                              if (r.note.isNotEmpty) r.note,
                            ].join(' · ');
                            return Card(
                              margin: const EdgeInsets.only(bottom: 10),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(r.gunName,
                                              style: const TextStyle(
                                                  fontWeight:
                                                      FontWeight.bold)),
                                        ),
                                        Text(
                                            CommunityStore.formatTime(
                                                r.date),
                                            style: const TextStyle(
                                                color: Colors.grey,
                                                fontSize: 12)),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    if (r.groupSize > 0)
                                      Text(
                                          tr('trip_group_label') + ' ${_fmt(r.groupSize)} ${tr('trip_cm')}${moa > 0 ? '${tr('range_paren_open')}${_fmt(moa)} MOA${tr('range_paren_close')}' : ''}',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFFE86A1C),
                                              fontSize: 15))
                                    else
                                      Text(tr('range_no_group'),
                                          style: TextStyle(
                                              color: Colors.grey)),
                                    const SizedBox(height: 4),
                                    Text(
                                        '${r.distance} ${tr('trip_meter')} · ${r.shots} ${tr('trip_shots_unit')}${r.score.isNotEmpty ? ' · ${r.score} ${tr('range_ring_suffix')}' : ''}'),
                                    if (details.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(details,
                                          style: const TextStyle(
                                              color: Colors.grey,
                                              fontSize: 12)),
                                    ],
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.end,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.repeat,
                                              size: 20),
                                          tooltip: tr('range_retake_tooltip'),
                                          onPressed: () {
                                            Gun? found;
                                            for (final g in guns) {
                                              if (g.name == r.gunName) {
                                                found = g;
                                              }
                                            }
                                            if (found != null) {
                                              _addScore(context,
                                                  presetGun: found,
                                                  presetDist: r.distance);
                                            } else {
                                              _addScore(context);
                                            }
                                          },
                                        ),
                                        IconButton(
                                          icon: const Icon(
                                              Icons.calculate_outlined,
                                              size: 20),
                                          tooltip: tr('range_calc_tooltip'),
                                          onPressed: () => Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  RangeToolsScreen(
                                                initialDistM:
                                                    r.distance.toDouble(),
                                                initialGroupCm: r.groupSize,
                                                initialLabel:
                                                    tr('range_title') + ' ${r.gunName} · ${r.distance} ${tr('trip_meter')}',
                                              ),
                                            ),
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(
                                              Icons.delete_outline,
                                              size: 20),
                                          onPressed: () => communityStore
                                              .removeRangeScore(r),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                      ],
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}
