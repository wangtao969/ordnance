import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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
import '../location_flow.dart';
import '../range_trip_data.dart';
import '../score_grade.dart';
import '../score_templates.dart';
import '../sensors_api.dart';
import '../weather_api.dart';
import '../widgets/score_grade_chip.dart';
import '../widgets/target_plot.dart';
import '../widgets/time_line_chart.dart';
import 'community_post_detail_screen.dart';

/// 靶场成绩：分组、距离、发数，绑定枪种；成绩直接喂靶场勋章。
/// 顶部统计卡 + 按枪筛选 + 结构化卡片，成绩不再是一长串字；
/// 录入框里可勾选同步：从弹药库存扣发数、计入枪柜已打发数。
class CommunityRangeScreen extends StatefulWidget {
  const CommunityRangeScreen({super.key});

  @override
  State<CommunityRangeScreen> createState() => _CommunityRangeScreenState();
}

/// 成绩录入对话框（顶层函数，供成绩页与行程详情共用）：
/// 落点图（点按标点、可拖动、可删单点、可清空）+ 自动带上下文
/// （行程枪、天气快照、射向）+ 存为模板 + 复制上次成绩。
/// 返回保存结果；取消返回 null。扣库存与计枪柜发数在函数内
/// 直接完成（仅新建时），公开/取消公开由调用方处理。
class ScoreDialogResult {
  final RangeScore score;
  final bool publish;
  final Uint8List? plotPng;
  const ScoreDialogResult({
    required this.score,
    required this.publish,
    this.plotPng,
  });
}

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

Future<ScoreDialogResult?> showScoreDialog(
  BuildContext context, {
  Gun? presetGun,
  int? presetDist,
  RangeTrip? presetTrip,
  RangeScore? editing,
  String? presetAmmo,
}) async {
  final editingScore = editing;
  Gun? gun = presetGun;
  if (gun == null && editingScore != null) {
    for (final g in guns) {
      if (g.name == editingScore.gunName) gun = g;
    }
  }
  if (gun == null && presetTrip != null) {
    for (final name in presetTrip.gunNames) {
      for (final g in guns) {
        if (g.name == name) {
          gun = g;
          break;
        }
      }
      if (gun != null) break;
    }
  }
  gun ??= await showGunPickerDialog(context);
  if (gun == null || !context.mounted) return null;
  final gunFinal = gun;
  final distanceCtrl = TextEditingController(
      text: '${editingScore?.distance ?? presetDist ?? 100}');
  // 弹药优先从库存选：该口径有库存时下拉点选，没有再手填。
  final stockItems = await loadAmmoItems();
  if (!context.mounted) return null;
  final stockNames = stockItems
      .where((e) => e.caliber == gunFinal.caliber)
      .map((e) => e.name)
      .toSet()
      .toList();
  // 弹药初始选择：编辑时沿用原值（不在库存里则走手动填，用原文字）；
  // 模板/预设弹药同理；全新则默认第一条库存，否则手动填。
  var ammoChoice = '手动填';
  if (editingScore != null && editingScore.ammo.isNotEmpty) {
    ammoChoice = stockNames.contains(editingScore.ammo)
        ? editingScore.ammo
        : '手动填';
  } else if (presetAmmo != null && presetAmmo.isNotEmpty) {
    ammoChoice =
        stockNames.contains(presetAmmo) ? presetAmmo : '手动填';
  } else if (stockNames.isNotEmpty) {
    ammoChoice = stockNames.first;
  }
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
  var batchChoice = editingScore?.batchNo.isNotEmpty == true
      ? editingScore!.batchNo
      : '不关联';
  // 同步勾选：扣库存只对同口径库存，计入枪柜只对已在枪柜档案里的枪。
  AmmoItem? deductItem;
  for (final item in stockItems) {
    if (item.caliber == gunFinal.caliber) {
      deductItem = item;
      break;
    }
  }
  final deductItemFinal = deductItem;
  var deductStock = false;
  // 2.2.5 起发数归枪柜档案：先读枪柜档案，勾选与写回都走它，不再写收藏柜。
  final cabinetProfiles = await loadGunProfiles();
  final inCabinet =
      cabinetProfiles.any((p) => p.gunName == gunFinal.name);
  var addToCollection = false;
  final shotsCtrl =
      TextEditingController(text: '${editingScore?.shots ?? 5}');
  final groupCtrl = TextEditingController(
      text: editingScore == null || editingScore.groupSize <= 0
          ? ''
          : _fmt(editingScore.groupSize));
  final scoreCtrl =
      TextEditingController(text: editingScore?.score ?? '');
  final ammoCtrl = TextEditingController(
      text: editingScore?.ammo ?? presetAmmo ?? '');
  final weatherCtrl =
      TextEditingController(text: editingScore?.weather ?? '');
  final windCtrl = TextEditingController(text: editingScore?.wind ?? '');
  final noteCtrl = TextEditingController(text: editingScore?.note ?? '');
  // 传感器融合：指南针记射向（随成绩保存），水平仪只显示角度（不保存）。
  var heading = editingScore?.heading ?? '';
  var levelText = '';
  const positions = ['站姿', '跪姿', '卧姿', '依托', '坐姿'];
  const targets = ['胸环靶', '精度靶', '人形靶', '钢靶', '其他'];
  // 旧记录姿势/靶型若不在下拉表里，回落默认值，避免下拉断言。
  var position = positions.contains(editingScore?.position)
      ? editingScore!.position
      : '站姿';
  var target = targets.contains(editingScore?.target)
      ? editingScore!.target
      : '胸环靶';
  // 落点图状态：归一化坐标对 + 每环厘米数 + 选中点。
  var points = editingScore?.shotPoints
          .map((e) => <double>[e[0], e[1]])
          .toList() ??
      <List<double>>[];
  // 每环厘米数只认下拉表里的 2/5/10，旧值不在表里回落 5，避免下拉断言。
  var gridCm = [2.0, 5.0, 10.0].contains(editingScore?.gridCm)
      ? editingScore!.gridCm
      : 5.0;
  var selectedPoint = -1;
  var publish = false;
  final plotKey = GlobalKey();
  var autoFetched = false;

  RangeScore? prevSameGun;
  if (editingScore == null) {
    final me = communityStore.current;
    if (me != null) {
      for (final r in me.rangeScores) {
        if (r.gunName == gunFinal.name) {
          prevSameGun = r;
          break;
        }
      }
    }
  }

  final result = await showDialog<ScoreDialogResult>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (ctx, setDialogState) {
        // 打开后自动带上下文（只填空项，不覆盖已有内容）：
        // 天气快照（授权后自动拉取）+ 射向（指南针读数）。
        if (!autoFetched) {
          autoFetched = true;
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            if (!dialogContext.mounted) return;
            final cr = await getCompassHeading();
            if (dialogContext.mounted &&
                cr.value != null &&
                heading.isEmpty) {
              final deg = cr.value!;
              setDialogState(() => heading =
                  '${deg.toStringAsFixed(0)}° ${compassDir(deg)}');
            }
            if (dialogContext.mounted && weatherCtrl.text.trim().isEmpty) {
              final ok = await ensureLocationPermission(dialogContext);
              if (!dialogContext.mounted || !ok) return;
              final fix = await fetchCurrentFix();
              if (!dialogContext.mounted || fix.value == null) return;
              final v = fix.value!;
              final w =
                  await fetchWeather(v.latitude, v.longitude);
              if (!dialogContext.mounted) return;
              final name = await reverseGeocode(v.latitude, v.longitude);
              if (!dialogContext.mounted) return;
              final place = name ??
                  '${v.latitude.toStringAsFixed(5)}, ${v.longitude.toStringAsFixed(5)}';
              setDialogState(
                  () => weatherCtrl.text = buildWeatherSnapshot(w, place));
            }
          });
        }

        Future<void> fetchWeatherInto() async {
          final ok = await ensureLocationPermission(context);
          if (!context.mounted || !ok) return;
          final fix = await fetchCurrentFix();
          if (!context.mounted || fix.value == null) {
            if (context.mounted) {
              showAppToast(context, tr(locErrorKey(fix.error)));
            }
            return;
          }
          final v = fix.value!;
          final w = await fetchWeather(v.latitude, v.longitude);
          if (!context.mounted) return;
          final name = await reverseGeocode(v.latitude, v.longitude);
          if (!context.mounted) return;
          final place = name ??
              '${v.latitude.toStringAsFixed(5)}, ${v.longitude.toStringAsFixed(5)}';
          setDialogState(
              () => weatherCtrl.text = buildWeatherSnapshot(w, place));
        }

        final dist = int.tryParse(distanceCtrl.text) ?? 100;
        final shots = int.tryParse(shotsCtrl.text) ?? 5;
        final group = double.tryParse(groupCtrl.text) ?? 0;
        final effCm = effectiveSpreadCm(
            points: points, gridCm: gridCm, groupSize: group);
        final effMoa = spreadMoa(effCm, dist);
        final grade = gradeForScore(
            shots: shots,
            distance: dist,
            groupSize: group,
            points: points,
            gridCm: gridCm);
        final content = Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (prevSameGun != null) ...[
              OutlinedButton.icon(
                onPressed: () {
                  final p = prevSameGun!;
                  setDialogState(() {
                    distanceCtrl.text = '${p.distance}';
                    shotsCtrl.text = '${p.shots}';
                    groupCtrl.text =
                        p.groupSize > 0 ? _fmt(p.groupSize) : '';
                    scoreCtrl.text = p.score;
                    if (positions.contains(p.position)) {
                      position = p.position;
                    }
                    if (targets.contains(p.target)) {
                      target = p.target;
                    }
                    if (p.ammo.isNotEmpty) {
                      if (stockNames.contains(p.ammo)) {
                        ammoChoice = p.ammo;
                      } else {
                        ammoChoice = '手动填';
                        ammoCtrl.text = p.ammo;
                      }
                    }
                  });
                  showAppToast(ctx, tr('range_copy_last_done'));
                },
                icon: const Icon(Icons.copy_outlined, size: 18),
                label: Text(tr('range_copy_last')),
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: distanceCtrl,
              keyboardType: TextInputType.number,
              onChanged: (_) => setDialogState(() {}),
              decoration: InputDecoration(
                labelText: tr('range_distance_label'),
                border: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12))),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: shotsCtrl,
              keyboardType: TextInputType.number,
              onChanged: (_) => setDialogState(() {}),
              decoration: InputDecoration(
                labelText: tr('range_shots_label'),
                border: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12))),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: groupCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => setDialogState(() {}),
              decoration: InputDecoration(
                labelText: tr('range_group_label'),
                border: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12))),
              ),
            ),
            const SizedBox(height: 12),
            // 靶纸落点图：点按标点、拖动调整；有落点图时散布以落点图为准。
            Text(tr('range_plot_label'),
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Center(
              child: RepaintBoundary(
                key: plotKey,
                child: TargetPlot(
                  points: points,
                  selected: selectedPoint,
                  onSelectedChanged: (i) =>
                      setDialogState(() => selectedPoint = i),
                  onChanged: (next) => setDialogState(() {
                    points = next;
                    if (selectedPoint >= points.length) {
                      selectedPoint = points.length - 1;
                    }
                  }),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Text(
                    points.length >= 2
                        ? tr('range_plot_spread') +
                            ' ${_fmt(effCm)} ${tr('trip_cm')} (${_fmt(effMoa)} MOA / ${_fmt(spreadMil(effCm, dist))} ${tr('range_mil')})'
                        : tr('range_plot_hint'),
                    style:
                        const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ),
                DropdownButton<double>(
                  value: gridCm,
                  items: [2.0, 5.0, 10.0]
                      .map((v) => DropdownMenuItem(
                          value: v,
                          child: Text('$v ${tr('trip_cm')}')))
                      .toList(),
                  onChanged: (v) =>
                      setDialogState(() => gridCm = v ?? gridCm),
                ),
              ],
            ),
            Row(
              children: [
                ScoreGradeChip(grade: grade, insufficient: shots < 3),
                const Spacer(),
                TextButton(
                  onPressed: selectedPoint < 0
                      ? null
                      : () => setDialogState(() {
                            points.removeAt(selectedPoint);
                            selectedPoint = -1;
                          }),
                  child: Text(tr('range_plot_delete_point')),
                ),
                TextButton(
                  onPressed: points.isEmpty
                      ? null
                      : () => setDialogState(() {
                            points = [];
                            selectedPoint = -1;
                          }),
                  child: Text(tr('range_plot_clear')),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: scoreCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: tr('range_score_label'),
                border: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12))),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: position,
              decoration: InputDecoration(
                labelText: tr('range_position_label'),
                border: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12))),
              ),
              items: positions
                  .map((e) => DropdownMenuItem(
                      value: e, child: Text(_trPosition(e))))
                  .toList(),
              onChanged: (v) =>
                  setDialogState(() => position = v ?? position),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: target,
              decoration: InputDecoration(
                labelText: tr('range_target_label'),
                border: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12))),
              ),
              items: targets
                  .map((e) =>
                      DropdownMenuItem(value: e, child: Text(_trTarget(e))))
                  .toList(),
              onChanged: (v) => setDialogState(() => target = v ?? target),
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
                            value: '手动填',
                            child: Text(tr('range_manual'))),
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
                    border: const OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(12))),
                  ),
                ),
              ],
            ] else
              TextField(
                controller: ammoCtrl,
                decoration: InputDecoration(
                  labelText: tr('range_ammo_hint'),
                  border: const OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(12))),
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
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.cloud_download_outlined,
                            size: 20),
                        tooltip: tr('range_weather_fetch'),
                        onPressed: fetchWeatherInto,
                      ),
                      border: const OutlineInputBorder(
                          borderRadius:
                              BorderRadius.all(Radius.circular(12))),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: windCtrl,
                    decoration: InputDecoration(
                      labelText: tr('range_wind_label'),
                      border: const OutlineInputBorder(
                          borderRadius:
                              BorderRadius.all(Radius.circular(12))),
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
                      showAppToast(ctx, tr('trip_heading_saved'));
                    } else {
                      showAppToast(ctx, tr('trip_heading_failed'));
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
                      showAppToast(ctx, tr('trip_level_failed'));
                    }
                  },
                  child: Text(tr('trip_level_read')),
                ),
              ],
            ),
            if (releasedBatches.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(tr('range_batch_label'),
                  style: const TextStyle(fontWeight: FontWeight.bold)),
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
            if (editingScore == null &&
                (deductItemFinal != null || inCabinet)) ...[
              const SizedBox(height: 12),
              Text(tr('range_sync_label'),
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              if (deductItemFinal != null)
                CheckboxListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Text(tr('range_deduct_prefix') +
                      deductItemFinal.name +
                      tr('range_deduct_suffix')),
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
                  onChanged: (v) =>
                      setDialogState(() => addToCollection = v ?? false),
                ),
            ],
            if (editingScore == null) ...[
              const SizedBox(height: 4),
              CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(tr('score_publish_label')),
                value: publish,
                onChanged: (v) =>
                    setDialogState(() => publish = v ?? false),
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: noteCtrl,
              decoration: InputDecoration(
                labelText: tr('range_note_label'),
                border: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12))),
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () async {
                  final ammoText = stockNames.isNotEmpty &&
                          ammoChoice != '手动填'
                      ? ammoChoice
                      : ammoCtrl.text.trim();
                  final templates = await loadScoreTemplates();
                  templates.removeWhere(
                      (t) => t.gunName == gunFinal.name);
                  templates.insert(
                      0,
                      ScoreTemplate(
                          gunName: gunFinal.name,
                          distance: int.tryParse(distanceCtrl.text) ??
                              100,
                          ammo: ammoText));
                  await saveScoreTemplates(templates);
                  if (ctx.mounted) {
                    showAppToast(ctx, tr('score_template_saved'));
                  }
                },
                child: Text(tr('score_save_template')),
              ),
            ),
          ],
        );
        return GlassDialog(
          title: gunFinal.name,
          subtitle: gunFinal.caliber.isNotEmpty
              ? tr('range_caliber_prefix') + gunFinal.caliber
              : null,
          content: content,
          actions: [
            glassCancelButton(dialogContext, tr('cancel')),
            TextButton(
              onPressed: () async {
                final dist = int.tryParse(distanceCtrl.text) ?? 100;
                final shots = int.tryParse(shotsCtrl.text) ?? 5;
                final group = double.tryParse(groupCtrl.text) ?? 0;
                final ammoText = stockNames.isNotEmpty &&
                        ammoChoice != '手动填'
                    ? ammoChoice
                    : ammoCtrl.text.trim();
                final newGrade = gradeForScore(
                    shots: shots,
                    distance: dist,
                    groupSize: group,
                    points: points,
                    gridCm: gridCm);
                final score = RangeScore(
                  id: editingScore?.id,
                  gunName: gunFinal.name,
                  distance: dist,
                  shots: shots,
                  groupSize: group,
                  date: editingScore?.date,
                  note: noteCtrl.text.trim(),
                  caliber: gunFinal.caliber,
                  ammo: ammoText,
                  position: position,
                  target: target,
                  score: scoreCtrl.text.trim(),
                  weather: weatherCtrl.text.trim(),
                  wind: windCtrl.text.trim(),
                  batchNo: batchChoice == '不关联' ? '' : batchChoice,
                  heading: heading,
                  shotPoints: points,
                  gridCm: gridCm,
                  grade: newGrade ?? '',
                  isPublic: editingScore?.isPublic ?? false,
                  postId: editingScore?.postId,
                );
                if (editingScore != null &&
                    editingScore.isPublic &&
                    editingScore.postId != null) {
                  final oldCm = effectiveSpreadCm(
                      points: editingScore.shotPoints,
                      gridCm: editingScore.gridCm,
                      groupSize: editingScore.groupSize);
                  final newCm = effectiveSpreadCm(
                      points: points, gridCm: gridCm, groupSize: group);
                  if ((oldCm - newCm).abs() > 0.01 ||
                      editingScore.grade != (newGrade ?? '')) {
                    final ok = await showDialog<bool>(
                      context: dialogContext,
                      builder: (confirmCtx) => AlertDialog(
                        title: Text(tr('score_republish_title')),
                        content: Text(tr('score_republish_body')),
                        actions: [
                          TextButton(
                            onPressed: () =>
                                Navigator.of(confirmCtx).pop(false),
                            child: Text(tr('cancel')),
                          ),
                          TextButton(
                            onPressed: () =>
                                Navigator.of(confirmCtx).pop(true),
                            child: Text(tr('score_republish_confirm')),
                          ),
                        ],
                      ),
                    );
                    if (ok != true) return;
                  }
                }
                Uint8List? png;
                if (points.length >= 2) {
                  try {
                    final boundary = plotKey.currentContext
                            ?.findRenderObject()
                        as RenderRepaintBoundary?;
                    if (boundary != null) {
                      final img =
                          await boundary.toImage(pixelRatio: 2);
                      final bytes = await img.toByteData(
                          format: ui.ImageByteFormat.png);
                      png = bytes?.buffer.asUint8List();
                    }
                  } catch (_) {}
                }
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop(ScoreDialogResult(
                      score: score, publish: publish, plotPng: png));
                }
              },
              child: Text(tr('save'),
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFE86A1C))),
            ),
          ],
        );
      },
    ),
  );
  if (result == null) {
    distanceCtrl.dispose();
    shotsCtrl.dispose();
    groupCtrl.dispose();
    scoreCtrl.dispose();
    ammoCtrl.dispose();
    weatherCtrl.dispose();
    windCtrl.dispose();
    noteCtrl.dispose();
    return null;
  }
  // 新建时才做同步：从弹药库存扣发数、计入枪柜已打发数。
  final shots = result.score.shots;
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
  if (addToCollection && shots > 0) {
    final idx =
        cabinetProfiles.indexWhere((p) => p.gunName == gunFinal.name);
    if (idx >= 0) {
      cabinetProfiles[idx].rounds += shots;
      await saveGunProfiles(cabinetProfiles);
      cabinetProfilesCache = cabinetProfiles;
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
  return result;
}


/// 公开一条成绩：生成动态（枪、距离、散布、落点图、档位徽章），
/// 评论走普通动态链路；成功后把动态 id 写回成绩。
Future<void> publishScore(
    BuildContext context, RangeScore s, Uint8List? plotPng) async {
  final me = communityStore.current;
  if (me == null || !context.mounted) return;
  final cm = effectiveSpreadCm(
      points: s.shotPoints, gridCm: s.gridCm, groupSize: s.groupSize);
  final moa = spreadMoa(cm, s.distance);
  final grade = s.grade.isNotEmpty
      ? s.grade
      : (gradeForScore(
              shots: s.shots,
              distance: s.distance,
              groupSize: s.groupSize,
              points: s.shotPoints,
              gridCm: s.gridCm) ??
          '');
  final title =
      '${tr('score_post_title')} ${s.gunName} · ${s.distance} ${tr('trip_meter')}';
  final content = cm > 0
      ? '${tr('score_post_spread')} ${_fmt(cm)} ${tr('trip_cm')} (${_fmt(moa)} MOA)'
      : tr('score_post_no_spread');
  final beforeIds = communityStore.posts.map((p) => p.id).toSet();
  final err = communityStore.createPost(
    title: title,
    content: content,
    board: '综合',
    images: plotPng == null ? [] : [plotPng],
    weather: s.weather,
    scoreGrade: grade,
  );
  if (err != null) {
    if (context.mounted) showAppToast(context, err);
    return;
  }
  // 本次新增的非成就动态即成绩动态（发帖 XP 可能连带产生
  // 成就动态，用 achievement 字段排除；标题可能被敏感词
  // 替换，改按新增 + 非成就定位，不按标题匹配）。
  CommunityPost? post;
  for (final p in communityStore.posts) {
    if (!beforeIds.contains(p.id) && p.achievement.isEmpty) {
      post = p;
      break;
    }
  }
  if (post != null) {
    communityStore.updateRangeScore(
        s, s.copyWith(isPublic: true, postId: post.id));
  }
}

/// 取消公开：按动态 id 删帖，成绩恢复私密。
Future<void> unpublishScore(RangeScore s) async {
  if (s.postId == null) return;
  CommunityPost? post;
  for (final p in communityStore.posts) {
    if (p.id == s.postId) {
      post = p;
      break;
    }
  }
  if (post != null) communityStore.deletePost(post);
  communityStore.updateRangeScore(
      s, s.copyWith(isPublic: false, clearPostId: true));
}

/// 保存后的统一收尾：写库（新增/编辑）+ 公开/重新发布 + 行程关联。
/// tripLink 是行程详情传来的 live 行程对象：直接改它的 scoreIds
/// 再调 onTripChanged 持久化，避免 prefs 往返把列表页的旧对象覆盖。
Future<void> handleSavedScore(
  BuildContext context,
  ScoreDialogResult result, {
  RangeScore? editing,
  RangeTrip? tripLink,
  VoidCallback? onTripChanged,
}) async {
  final s = result.score;
  if (editing != null) {
    if (editing.isPublic && editing.postId != null) {
      final oldCm = effectiveSpreadCm(
          points: editing.shotPoints,
          gridCm: editing.gridCm,
          groupSize: editing.groupSize);
      final newCm = effectiveSpreadCm(
          points: s.shotPoints, gridCm: s.gridCm, groupSize: s.groupSize);
      if ((oldCm - newCm).abs() > 0.01 || editing.grade != s.grade) {
        await unpublishScore(editing);
        await publishScore(context, s, result.plotPng);
      }
    }
    communityStore.updateRangeScore(editing, s);
  } else {
    communityStore.addRangeScore(s);
    if (result.publish) await publishScore(context, s, result.plotPng);
  }
  if (tripLink != null && !tripLink.scoreIds.contains(s.id)) {
    tripLink.scoreIds.add(s.id);
    onTripChanged?.call();
  }
  if (context.mounted) showAppToast(context, tr('range_saved'));
}

class _CommunityRangeScreenState extends State<CommunityRangeScreen> {
  String _filter = '全部';
  int? _trendDist;
  // 卡片落点图的 RepaintBoundary 键：公开时现拍落点图用。
  final _plotKeys = <String, GlobalKey>{};

  /// 成绩录入/编辑入口：对话框 + 统一收尾（写库/公开/行程关联）。
  Future<void> _addScore(BuildContext context,
      {Gun? presetGun,
      int? presetDist,
      RangeScore? editing,
      String? presetAmmo}) async {
    final result = await showScoreDialog(context,
        presetGun: presetGun,
        presetDist: presetDist,
        editing: editing,
        presetAmmo: presetAmmo);
    if (result == null || !context.mounted) return;
    await handleSavedScore(context, result, editing: editing);
  }

  /// 卡片上的公开开关：公开时落点图现拍（卡片上的图已渲染），
  /// 取消公开时删帖；已有私密成绩默认不动。
  Future<void> _togglePublic(RangeScore r) async {
    if (r.isPublic) {
      await unpublishScore(r);
      if (mounted) showAppToast(context, tr('score_unpublished'));
      return;
    }
    Uint8List? png;
    final key = _plotKeys[r.id];
    try {
      final boundary =
          key?.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary != null) {
        final img = await boundary.toImage(pixelRatio: 2);
        final bytes =
            await img.toByteData(format: ui.ImageByteFormat.png);
        png = bytes?.buffer.asUint8List();
      }
    } catch (_) {}
    await publishScore(context, r, png);
    if (mounted) showAppToast(context, tr('score_published'));
  }


  /// 快速录入模板：点模板直接按组合新建成绩，左滑删除模板。
  Future<void> _showTemplates(BuildContext context) async {
    var templates = await loadScoreTemplates();
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dctx) => StatefulBuilder(
        builder: (ctx, setD) => GlassDialog(
          title: tr('score_templates_title'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (templates.isEmpty)
                Text(tr('score_templates_empty'),
                    style: const TextStyle(color: Colors.grey))
              else
                ...templates.map((t) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                          '${t.gunName} · ${t.distance} ${tr('trip_meter')}${t.ammo.isNotEmpty ? ' · ${t.ammo}' : ''}'),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, size: 20),
                        onPressed: () async {
                          templates.remove(t);
                          await saveScoreTemplates(templates);
                          setD(() {});
                        },
                      ),
                      onTap: () {
                        Navigator.of(dctx).pop();
                        Gun? found;
                        for (final g in guns) {
                          if (g.name == t.gunName) found = g;
                        }
                        if (found != null) {
                          _addScore(context,
                              presetGun: found,
                              presetDist: t.distance,
                              presetAmmo: t.ammo);
                        } else {
                          _addScore(context);
                        }
                      },
                    )),
            ],
          ),
          actions: [glassCancelButton(dctx, tr('cancel'))],
        ),
      ),
    );
  }
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
                  if (me != null) ...[
                    OutlinedButton.icon(
                      onPressed: () => _showTemplates(context),
                      icon: const Icon(Icons.bookmark_border, size: 18),
                      label: Text(tr('score_templates_button')),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: () => _addScore(context),
                      icon: const Icon(Icons.add, size: 18),
                      label: Text(tr('range_add_one')),
                    ),
                  ],
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
                        Builder(
                          builder: (_) {
                            // 个人纪录：每支枪最佳散布（MOA 最小，3 发以下
                            // 样本不足不计）；趋势：按距离分的 MOA 时间折线。
                            final byGun = <String, RangeScore>{};
                            final byGunMoa = <String, double>{};
                            for (final r in scores) {
                              if (r.shots < 3) continue;
                              final cm = effectiveSpreadCm(
                                  points: r.shotPoints,
                                  gridCm: r.gridCm,
                                  groupSize: r.groupSize);
                              if (cm <= 0 || r.distance <= 0) continue;
                              final moa = spreadMoa(cm, r.distance);
                              if (!byGunMoa.containsKey(r.gunName) ||
                                  moa < byGunMoa[r.gunName]!) {
                                byGunMoa[r.gunName] = moa;
                                byGun[r.gunName] = r;
                              }
                            }
                            final dists = scores
                                .where((r) =>
                                    r.shots >= 3 &&
                                    effectiveSpreadCm(
                                            points: r.shotPoints,
                                            gridCm: r.gridCm,
                                            groupSize: r.groupSize) >
                                        0)
                                .map((r) => r.distance)
                                .toSet()
                                .toList()
                              ..sort();
                            final trendDist = _trendDist != null &&
                                    dists.contains(_trendDist)
                                ? _trendDist!
                                : (dists.isNotEmpty ? dists.first : 0);
                            final trendPoints = scores
                                .where((r) =>
                                    r.distance == trendDist &&
                                    r.shots >= 3)
                                .map((r) {
                                  final cm = effectiveSpreadCm(
                                      points: r.shotPoints,
                                      gridCm: r.gridCm,
                                      groupSize: r.groupSize);
                                  return (r, cm);
                                })
                                .where((e) => e.$2 > 0)
                                .map((e) => TimePoint(e.$1.date,
                                    spreadMoa(e.$2, e.$1.distance)))
                                .toList()
                              ..sort((a, b) => a.date.compareTo(b.date));
                            if (byGun.isEmpty && dists.isEmpty) {
                              return const SizedBox.shrink();
                            }
                            return Card(
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(tr('score_records_title'),
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 4),
                                    Text(tr('score_grade_legend'),
                                        style: const TextStyle(
                                            color: Colors.grey,
                                            fontSize: 12)),
                                    if (byGun.isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      ...byGun.entries.map((e) {
                                        final r = e.value;
                                        final moa = byGunMoa[e.key]!;
                                        final cm = effectiveSpreadCm(
                                            points: r.shotPoints,
                                            gridCm: r.gridCm,
                                            groupSize: r.groupSize);
                                        return Padding(
                                          padding: const EdgeInsets.only(
                                              bottom: 4),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                  child: Text(e.key)),
                                              ScoreGradeChip(
                                                  grade: r.grade.isNotEmpty
                                                      ? r.grade
                                                      : gradeForScore(
                                                          shots: r.shots,
                                                          distance:
                                                              r.distance,
                                                          groupSize:
                                                              r.groupSize,
                                                          points:
                                                              r.shotPoints,
                                                          gridCm: r.gridCm)),
                                              const SizedBox(width: 8),
                                              Text(
                                                  '${_fmt(moa)} MOA · ${_fmt(cm)} ${tr('trip_cm')} · ${r.distance} ${tr('trip_meter')}',
                                                  style: const TextStyle(
                                                      color: Colors.grey,
                                                      fontSize: 12)),
                                            ],
                                          ),
                                        );
                                      }),
                                    ],
                                    if (dists.isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      Text(tr('score_trend_title'),
                                          style: const TextStyle(
                                              fontWeight:
                                                  FontWeight.bold)),
                                      const SizedBox(height: 4),
                                      Wrap(
                                        spacing: 6,
                                        children: dists
                                            .map((d) => ChoiceChip(
                                                  label: Text(
                                                      '$d ${tr('trip_meter')}'),
                                                  selected:
                                                      trendDist == d,
                                                  onSelected: (_) =>
                                                      setState(() =>
                                                          _trendDist = d),
                                                ))
                                            .toList(),
                                      ),
                                      const SizedBox(height: 4),
                                      if (trendPoints.isEmpty)
                                        Text(tr('score_trend_empty'),
                                            style: const TextStyle(
                                                color: Colors.grey,
                                                fontSize: 12))
                                      else
                                        TimeLineChart(
                                          series: [
                                            TimeSeries(
                                                label: '',
                                                color: const Color(
                                                    0xFFE86A1C),
                                                points: trendPoints),
                                          ],
                                          unit: 'MOA',
                                          height: 180,
                                        ),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          },
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
                            // 有效散布：有落点图时以落点图为准，否则手填分组。
                            final effCm = effectiveSpreadCm(
                                points: r.shotPoints,
                                gridCm: r.gridCm,
                                groupSize: r.groupSize);
                            final moa = spreadMoa(effCm, r.distance);
                            final mil = spreadMil(effCm, r.distance);
                            final grade = r.grade.isNotEmpty
                                ? r.grade
                                : gradeForScore(
                                    shots: r.shots,
                                    distance: r.distance,
                                    groupSize: r.groupSize,
                                    points: r.shotPoints,
                                    gridCm: r.gridCm);
                            final showChip = r.shots < 3 ||
                                (grade ?? '').isNotEmpty;
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
                                        if (showChip) ...[
                                          ScoreGradeChip(
                                              grade: grade,
                                              insufficient: r.shots < 3),
                                          const SizedBox(width: 6),
                                        ],
                                        Text(
                                            CommunityStore.formatTime(
                                                r.date),
                                            style: const TextStyle(
                                                color: Colors.grey,
                                                fontSize: 12)),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    if (effCm > 0)
                                      Text(
                                          tr('trip_group_label') +
                                              ' ${_fmt(effCm)} ${tr('trip_cm')}${moa > 0 ? '${tr('range_paren_open')}${_fmt(moa)} MOA / ${_fmt(mil)} ${tr('range_mil')}${tr('range_paren_close')}' : ''}${r.shotPoints.length >= 2 ? ' · ${tr('range_plot_short')}' : ''}',
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
                                    if (r.shotPoints.isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      Center(
                                        child: RepaintBoundary(
                                          key: _plotKeys.putIfAbsent(
                                              r.id, () => GlobalKey()),
                                          child: TargetPlot(
                                            points: r.shotPoints,
                                            editable: false,
                                            size: 160,
                                          ),
                                        ),
                                      ),
                                    ],
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
                                        if (r.isPublic)
                                          TextButton(
                                            onPressed: () {
                                              CommunityPost? post;
                                              for (final p
                                                  in communityStore.posts) {
                                                if (p.id == r.postId) {
                                                  post = p;
                                                  break;
                                                }
                                              }
                                              if (post != null &&
                                                  context.mounted) {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (_) =>
                                                        CommunityPostDetailScreen(
                                                            post: post!),
                                                  ),
                                                );
                                              }
                                            },
                                            child: Text(
                                                tr('score_view_post')),
                                          ),
                                        IconButton(
                                          icon: Icon(Icons.public,
                                              size: 20,
                                              color: r.isPublic
                                                  ? const Color(0xFFE86A1C)
                                                  : null),
                                          tooltip: r.isPublic
                                              ? tr('score_unpublish')
                                              : tr('score_publish'),
                                          onPressed: () =>
                                              _togglePublic(r),
                                        ),
                                        IconButton(
                                          icon: const Icon(
                                              Icons.edit_outlined,
                                              size: 20),
                                          tooltip: tr('score_edit'),
                                          onPressed: () => _addScore(context,
                                              editing: r),
                                        ),
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
