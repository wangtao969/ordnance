import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../data.dart';
import '../models.dart';
import '../widgets/app_toast.dart';
import '../widgets/app_top_bar.dart';
import '../voice_actions.dart';
import '../app_log.dart';
import 'load_tools_screen.dart';
import 'reload_cost_screen.dart';
import '../widgets/glass_dialog.dart';
import '../i18n.dart';

/// 复装记录：按 SOP 一步步打勾执行，并记下每次复装的实际参数。
/// 记录经 gunsmap/prefs 存本机（key reload_log_v1），重启不丢；
/// 字段按 Hornady / Lyman 手册的记录要求：弹头、火药与批号、底火与批号、
/// 弹壳品牌与使用次数、装药量、COL、试射枪械、初速、散布、天气与备注。
class ReloadLogEntry {
  final String date;
  final String caliber;
  final String bullet;
  final String powder;
  final String charge;
  final String col;
  final String rounds;
  final String note;
  final String primer;
  final String caseBrand;
  final String caseTimes;
  final String velocity;
  final String group;
  final String firearm;
  final String lot;
  final String weather;
  // 放行标记：只有通过完整性与 SOP 检测的记录才会保存，旧记录默认已放行。
  final bool released;
  // 批次号：保存时自动编（日期-口径-当日序号），同一批弹的唯一标识。
  final String batchNo;
  // 压力迹象：试射时勾选的异常项（逗号分隔），非空即异常停用、不能放行。
  final String pressure;
  ReloadLogEntry({
    required this.date,
    required this.caliber,
    required this.bullet,
    required this.powder,
    required this.charge,
    required this.col,
    required this.rounds,
    required this.note,
    this.primer = '',
    this.caseBrand = '',
    this.caseTimes = '',
    this.velocity = '',
    this.group = '',
    this.firearm = '',
    this.lot = '',
    this.weather = '',
    this.released = true,
    this.batchNo = '',
    this.pressure = '',
  });

  Map<String, dynamic> toJson() => {
        'date': date,
        'caliber': caliber,
        'bullet': bullet,
        'powder': powder,
        'charge': charge,
        'col': col,
        'rounds': rounds,
        'note': note,
        'primer': primer,
        'caseBrand': caseBrand,
        'caseTimes': caseTimes,
        'velocity': velocity,
        'group': group,
        'firearm': firearm,
        'lot': lot,
        'weather': weather,
        'released': released,
        'batchNo': batchNo,
        'pressure': pressure,
      };

  factory ReloadLogEntry.fromJson(Map<String, dynamic> j) => ReloadLogEntry(
        date: j['date'] as String? ?? '',
        caliber: j['caliber'] as String? ?? '',
        bullet: j['bullet'] as String? ?? '',
        powder: j['powder'] as String? ?? '',
        charge: j['charge'] as String? ?? '',
        col: j['col'] as String? ?? '',
        rounds: j['rounds'] as String? ?? '',
        note: j['note'] as String? ?? '',
        primer: j['primer'] as String? ?? '',
        caseBrand: j['caseBrand'] as String? ?? '',
        caseTimes: j['caseTimes'] as String? ?? '',
        velocity: j['velocity'] as String? ?? '',
        group: j['group'] as String? ?? '',
        firearm: j['firearm'] as String? ?? '',
        lot: j['lot'] as String? ?? '',
        weather: j['weather'] as String? ?? '',
        released: j['released'] as bool? ?? true,
        batchNo: j['batchNo'] as String? ?? '',
        pressure: j['pressure'] as String? ?? '',
      );
}

class ReloadLogScreen extends StatefulWidget {
  // 从复装工作台带入的已选组件与口径：只做初始填充，用户仍可在记录页改。
  final String? initialBullet;
  final String? initialPowder;
  final String? initialPrimer;
  final String? initialCase;
  final String? initialCaliber;
  const ReloadLogScreen({
    super.key,
    this.initialBullet,
    this.initialPowder,
    this.initialPrimer,
    this.initialCase,
    this.initialCaliber,
  });

  @override
  State<ReloadLogScreen> createState() => _ReloadLogScreenState();
}

String _pressureLabel(String o) {
  switch (o) {
    case '底火压平':
      return tr('log_pressure_flat');
    case '底火 crater':
      return tr('log_pressure_crater');
    case '抛壳挺亮印/退壳困难':
      return tr('log_pressure_eject');
    case '枪机难开':
      return tr('log_pressure_bolt');
    case '底火窝变松漏气':
      return tr('log_pressure_pocket');
    default:
      return o;
  }
}

String _weatherLabel(String w) {
  switch (w) {
    case '晴':
      return tr('log_weather_sunny');
    case '阴':
      return tr('log_weather_cloudy');
    case '雨':
      return tr('log_weather_rainy');
    case '雪':
      return tr('log_weather_snowy');
    case '室内':
      return tr('log_weather_indoor');
    default:
      return w;
  }
}

class _ReloadLogScreenState extends State<ReloadLogScreen> {
  late List<bool> _done;
  // SOP 区默认收起，只留一行摘要 + 进度条，点开才是紧凑清单；
  // 放行检测发现 SOP 没打满时自动展开，免得用户自己上去找。
  bool _sopExpanded = false;
  final _logs = <ReloadLogEntry>[];
  String? _caliber;
  final _bulletCtrl = TextEditingController();
  final _powderCtrl = TextEditingController();
  final _chargeCtrl = TextEditingController();
  final _colCtrl = TextEditingController();
  final _roundsCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final _primerCtrl = TextEditingController();
  final _caseBrandCtrl = TextEditingController();
  final _caseTimesCtrl = TextEditingController();
  final _velocityCtrl = TextEditingController();
  final _groupCtrl = TextEditingController();
  final _firearmCtrl = TextEditingController();
  final _lotCtrl = TextEditingController();
  final _weatherCtrl = TextEditingController();
  static const _prefsChannel = MethodChannel('gunsmap/prefs');
  static const _prefsKey = 'reload_log_v1';
  // 压力迹象（取自安全红线）：勾选任何一项即异常停用。
  static const _pressureOptions = [
    '底火压平',
    '底火 crater',
    '抛壳挺亮印/退壳困难',
    '枪机难开',
    '底火窝变松漏气',
  ];
  final Set<String> _pressure = {};
  int _scaleChecks = 0;

  @override
  void initState() {
    super.initState();
    _done = List<bool>.filled(reloadSopSteps.length, false);
    if (widget.initialBullet != null) {
      _bulletCtrl.text = widget.initialBullet!;
    }
    if (widget.initialPowder != null) {
      _powderCtrl.text = widget.initialPowder!;
    }
    if (widget.initialPrimer != null) {
      _primerCtrl.text = widget.initialPrimer!;
    }
    if (widget.initialCase != null) {
      _caseBrandCtrl.text = widget.initialCase!;
    }
    if (widget.initialCaliber != null) _caliber = widget.initialCaliber;
    _load();
  }

  Future<void> _load() async {
    try {
      final raw = await _prefsChannel
          .invokeMethod<String>('getString', {'key': _prefsKey}).timeout(
              const Duration(seconds: 2));
      if (raw != null && raw.isNotEmpty && mounted) {
        final list = (jsonDecode(raw) as List)
            .map((e) => ReloadLogEntry.fromJson(e as Map<String, dynamic>))
            .toList();
        setState(() {
          _logs
            ..clear()
            ..addAll(list);
        });
      }
    } catch (_) {}
    // 记住上次口径：工作台带入的不覆盖；口径框可改，预填错了随手就能改。
    if (widget.initialCaliber == null && mounted) {
      try {
        final last = await _prefsChannel
            .invokeMethod<String>(
                'getString', {'key': 'reload_last_caliber_v1'})
            .timeout(const Duration(seconds: 2));
        if (last != null &&
            mounted &&
            reloadCalibers.any((c) => c.caliber == last)) {
          setState(() => _caliber = last);
        }
      } catch (_) {}
    }
  }

  void _save() {
    try {
      _prefsChannel.invokeMethod('setString', {
        'key': _prefsKey,
        'value': jsonEncode(_logs.map((e) => e.toJson()).toList()),
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _bulletCtrl.dispose();
    _powderCtrl.dispose();
    _chargeCtrl.dispose();
    _colCtrl.dispose();
    _roundsCtrl.dispose();
    _noteCtrl.dispose();
    _primerCtrl.dispose();
    _caseBrandCtrl.dispose();
    _caseTimesCtrl.dispose();
    _velocityCtrl.dispose();
    _groupCtrl.dispose();
    _firearmCtrl.dispose();
    _lotCtrl.dispose();
    _weatherCtrl.dispose();
    super.dispose();
  }

  String _today() {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
  }

  /// 放行检测：SOP 必须全部打勾；配方、组件与试射字段必须填完整；
  /// 装药量、弹长、数量、弹壳使用次数必须是大于 0 的数字。
  /// 返回缺失/不合格项，空表即放行。
  List<String> _missing() {
    final miss = <String>[];
    final doneCount = _done.where((d) => d).length;
    if (doneCount != reloadSopSteps.length) {
      miss.add(tr('log_sop_incomplete_prefix') + '$doneCount/${reloadSopSteps.length}' + tr('log_sop_incomplete_suffix'));
    }
    if (_caliber == null) miss.add(tr('log_field_caliber'));
    final fields = {
      tr('log_field_bullet'): _bulletCtrl.text.trim(),
      tr('log_field_powder'): _powderCtrl.text.trim(),
      tr('log_field_charge'): _chargeCtrl.text.trim(),
      tr('log_field_col'): _colCtrl.text.trim(),
      tr('log_field_rounds'): _roundsCtrl.text.trim(),
      tr('log_field_primer'): _primerCtrl.text.trim(),
      tr('log_field_lot'): _lotCtrl.text.trim(),
      tr('log_field_case_brand'): _caseBrandCtrl.text.trim(),
      tr('log_field_case_times'): _caseTimesCtrl.text.trim(),
      tr('log_field_velocity'): _velocityCtrl.text.trim(),
      tr('log_field_group'): _groupCtrl.text.trim(),
      tr('log_field_firearm'): _firearmCtrl.text.trim(),
      tr('log_field_weather'): _weatherCtrl.text.trim(),
    };
    fields.forEach((k, v) {
      if (v.isEmpty) miss.add(k);
    });
    double? num(String v) => double.tryParse(v);
    if (_chargeCtrl.text.trim().isNotEmpty &&
        (num(_chargeCtrl.text.trim()) ?? 0) <= 0) {
      miss.add(tr('log_num_charge'));
    }
    if (_colCtrl.text.trim().isNotEmpty &&
        (num(_colCtrl.text.trim()) ?? 0) <= 0) {
      miss.add(tr('log_num_col'));
    }
    if (_roundsCtrl.text.trim().isNotEmpty &&
        (num(_roundsCtrl.text.trim()) ?? 0) <= 0) {
      miss.add(tr('log_num_rounds'));
    }
    if (_caseTimesCtrl.text.trim().isNotEmpty &&
        (num(_caseTimesCtrl.text.trim()) ?? 0) < 1) {
      miss.add(tr('log_num_case_times'));
    }
    return miss;
  }

  /// 批次号：日期-口径-当日序号，如 20261026-308Winchester-01。
  String _batchNo() {
    final date = _today().replaceAll('-', '');
    final cal = (_caliber ?? '').replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
    final seq = _logs
            .where((l) => l.date == _today() && l.caliber == _caliber)
            .length +
        1;
    return '$date-$cal-$seq'.replaceAll(RegExp(r'-+$'), '');
  }

  /// 手册对照：只有口径、弹头品牌与重量、火药型号都对得上才算匹配；
  /// 品牌或重量对不上的一律算无对照，绝不模糊放行。
  ReloadLoad? _matchingLoad() {
    if (_caliber == null) return null;
    final bullet = _bulletCtrl.text.trim().toLowerCase();
    final powder = _powderCtrl.text.trim().toLowerCase();
    for (final l in reloadLoads) {
      if (l.caliber != _caliber) continue;
      final lb = l.bullet.toLowerCase();
      final brand = lb.split(' ').first;
      final weight = RegExp(r'(\d+)gr').firstMatch(lb)?.group(1);
      if (!bullet.contains(brand)) continue;
      if (weight != null && !bullet.contains('${weight}gr')) continue;
      final lp = l.powder.toLowerCase();
      if (!lp.split(' ').every((w) => powder.contains(w))) continue;
      return l;
    }
    return null;
  }

  double? _num(String v) {
    final m = RegExp(r'[0-9]+(?:\.[0-9]+)?').firstMatch(v);
    return m == null ? null : double.tryParse(m.group(0)!);
  }

  /// 手册装药量对照结果：null 表示无对照；否则返回是否在区间内与说明。
  ({ReloadLoad? load, bool inRange, String note}) _manualCheck() {
    final load = _matchingLoad();
    if (load == null) {
      return (
        load: null,
        inRange: false,
        note: tr('log_note_no_manual')
      );
    }
    final charge = _num(_chargeCtrl.text.trim());
    final col = _num(_colCtrl.text.trim());
    final start = _num(load.startCharge);
    final max = _num(load.maxCharge);
    final manualCol = _num(load.col);
    if (charge != null && max != null && charge > max) {
      return (
        load: load,
        inRange: false,
        note: tr('log_note_over_prefix') + '$charge' + tr('log_note_over_mid') + '$max' + tr('log_note_over_mid2') + load.manual + tr('log_note_over_suffix')
      );
    }
    if (col != null && manualCol != null && col < manualCol) {
      return (
        load: load,
        inRange: false,
        note: tr('log_note_col_prefix') + '$col' + tr('log_note_col_mid') + '$manualCol' + tr('log_note_col_mid2') + load.manual + tr('log_note_col_suffix')
      );
    }
    if (charge != null && start != null && charge < start) {
      return (
        load: load,
        inRange: false,
        note: tr('log_note_under_prefix') + '$charge' + tr('log_note_under_mid') + '$start' + tr('log_note_under_mid2') + load.manual + tr('log_note_under_suffix')
      );
    }
    return (
      load: load,
      inRange: true,
      note: tr('log_note_ok_prefix') + load.manual + tr('log_note_ok_mid_a') + '$start' + tr('log_note_ok_mid_b') + '$max' + tr('log_note_ok_mid_c') + '$manualCol' + tr('log_note_ok_suffix')
    );
  }

  void _insertEntry({required bool released}) {
    final savedCaliber = _caliber;
    setState(() {
      _logs.insert(
          0,
          ReloadLogEntry(
            date: _today(),
            caliber: _caliber!,
            bullet: _bulletCtrl.text.trim(),
            powder: _powderCtrl.text.trim(),
            charge: _chargeCtrl.text.trim(),
            col: _colCtrl.text.trim(),
            rounds: _roundsCtrl.text.trim(),
            note: _noteCtrl.text.trim(),
            primer: _primerCtrl.text.trim(),
            caseBrand: _caseBrandCtrl.text.trim(),
            caseTimes: _caseTimesCtrl.text.trim(),
            velocity: _velocityCtrl.text.trim(),
            group: _groupCtrl.text.trim(),
            firearm: _firearmCtrl.text.trim(),
            lot: _lotCtrl.text.trim(),
            weather: _weatherCtrl.text.trim(),
            released: released,
            batchNo: _batchNo(),
            pressure: _pressure.join('、'),
          ));
      _save();
      _clearForm();
    });
    if (savedCaliber != null) {
      _prefsChannel.invokeMethod('setString', {
        'key': 'reload_last_caliber_v1',
        'value': savedCaliber,
      });
    }
  }

  /// 沿用上次同口径配方：只带配方（弹头、火药、装药、弹长、底火、
  /// 弹壳品牌与次数），不带试射结果、批号、压力与 SOP，仍须重走放行。
  void _reuseLastCaliberRecipe() {
    if (_caliber == null) {
      showAppToast(context, tr('log_pick_caliber_first'));
      return;
    }
    ReloadLogEntry? last;
    for (final l in _logs) {
      if (l.caliber == _caliber && l.released) {
        last = l;
        break;
      }
    }
    if (last == null) {
      showAppToast(context, tr('log_no_released_caliber'));
      return;
    }
    setState(() {
      _bulletCtrl.text = last!.bullet;
      _powderCtrl.text = last.powder;
      _chargeCtrl.text = last.charge;
      _colCtrl.text = last.col;
      _primerCtrl.text = last.primer;
      _caseBrandCtrl.text = last.caseBrand;
      _caseTimesCtrl.text = last.caseTimes;
    });
    showAppToast(context, tr('log_recipe_carried'));
  }

  /// 语音备注：只把识别文本追加为备注草稿，绝不填装药量、COL、
  /// 底火、弹头等关键字段；无识别服务或取消时静默回退手动输入。
  Future<void> _voiceNote() async {
    final text = await recognizeSpeech();
    if (!mounted) return;
    if (text == null || text.trim().isEmpty) {
      appLog('voice', '识别无结果或本机无识别服务');
      showAppToast(context, tr('log_voice_none'));
      return;
    }
    appLog('voice', '识别成功，已填入备注草稿');
    setState(() {
      final cur = _noteCtrl.text.trim();
      _noteCtrl.text = cur.isEmpty ? text.trim() : '$cur $text'.trim();
    });
    showAppToast(context, tr('log_voice_draft'));
  }

  double? _grOf(String s) {
    final m = RegExp(r'(\d+(?:\.\d+)?)\s*gr').firstMatch(s);
    return m == null ? null : double.tryParse(m.group(1)!);
  }

  double? _firstNum(String s) {
    final m = RegExp(r'(\d+(?:\.\d+)?)').firstMatch(s);
    return m == null ? null : double.tryParse(m.group(1)!);
  }

  /// 安全规则不再占一整块内容区：改成按钮，点开弹毛玻璃窗看 13 条。
  Future<void> _showSafetyRules() async {
    await showDialog(
      context: context,
      builder: (ctx) => GlassDialog(
        title: tr('reload_safety_title'),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          // 英文界面显示英文版安全规则（与中文表一一对应，中文原文不动）。
          children: (localeNotifier.value == localeEn
                  ? reloadSafetyRulesEn
                  : reloadSafetyRules)
              .map((r) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text('· $r'),
                  ))
              .toList(),
        ),
        actions: [glassPrimaryButton(ctx, tr('got_it'))],
      ),
    );
  }

  /// 复用配方：把一条已放行记录的配方与组件载入表单，SOP 与压力
  /// 迹象清零重走，批号在保存时重新编，不沿用旧批号与旧试射结果。
  void _reuseRecipe(ReloadLogEntry l) {
    setState(() {
      _caliber = l.caliber;
      _bulletCtrl.text = l.bullet;
      _powderCtrl.text = l.powder;
      _chargeCtrl.text = l.charge;
      _colCtrl.text = l.col;
      _roundsCtrl.text = l.rounds;
      _primerCtrl.text = l.primer;
      _caseBrandCtrl.text = l.caseBrand;
      _caseTimesCtrl.text = l.caseTimes;
      _lotCtrl.text = l.lot;
      _velocityCtrl.text = '';
      _groupCtrl.text = '';
      _firearmCtrl.text = l.firearm;
      _weatherCtrl.text = '';
      _noteCtrl.text = '';
      _pressure.clear();
      _scaleChecks = 0;
      _done = List<bool>.filled(reloadSopSteps.length, false);
    });
    showAppToast(context, tr('log_recipe_loaded'));
  }

  void _clearForm() {
    _bulletCtrl.clear();
    _powderCtrl.clear();
    _chargeCtrl.clear();
    _colCtrl.clear();
    _roundsCtrl.clear();
    _noteCtrl.clear();
    _primerCtrl.clear();
    _caseBrandCtrl.clear();
    _caseTimesCtrl.clear();
    _velocityCtrl.clear();
    _groupCtrl.clear();
    _firearmCtrl.clear();
    _lotCtrl.clear();
    _weatherCtrl.clear();
    _caliber = null;
    _pressure.clear();
    _scaleChecks = 0;
    _done = List<bool>.filled(reloadSopSteps.length, false);
  }

  Future<void> _tryRelease() async {
    final miss = _missing();
    if (miss.isNotEmpty) {
      if (!mounted) return;
      if (miss.any((m) => m.startsWith('SOP'))) {
        setState(() => _sopExpanded = true);
      }
      await showDialog(
        context: context,
        builder: (ctx) => GlassDialog(
          title: tr('log_release_fail_title'),
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(tr('log_release_fail_note')),
              const SizedBox(height: 8),
              ...miss.map((m) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text('· $m'),
                  )),
            ],
          ),
          actions: [glassPrimaryButton(ctx, tr('got_it'))],
        ),
      );
      return;
    }
    // 压力迹象：直接存为异常停用记录，不放行。
    if (_pressure.isNotEmpty) {
      _insertEntry(released: false);
      if (mounted) {
        showAppToast(context, tr('log_pressure_saved'));
      }
      return;
    }
    // 手册对照：无对照或超出区间时不给已放行，只能二选一。
    final manual = _manualCheck();
    if (!manual.inRange) {
      if (!mounted) return;
      final saveOnly = await showDialog<bool>(
        context: context,
        builder: (ctx) => GlassDialog(
          title: tr('log_manual_fail_title'),
          content: Text(manual.note + tr('log_manual_fail_suffix')),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(tr('log_back_edit')),
            ),
            glassPrimaryButton(ctx, tr('log_save_unreleased'), popTrue: true),
          ],
        ),
      );
      if (saveOnly == true) {
        _insertEntry(released: false);
        if (mounted) showAppToast(context, tr('log_saved_unreleased'));
      }
      return;
    }
    _insertEntry(released: true);
    if (mounted) showAppToast(context, tr('log_released_saved'));
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final grey = dark ? const Color(0xFF8A8578) : const Color(0xFF9A917F);
    final bronze = dark ? const Color(0xFFC9A86A) : const Color(0xFF6B5B3E);
    final doneCount = _done.where((d) => d).length;
    final allDone = doneCount == reloadSopSteps.length;
    return Scaffold(
      appBar: SubPageAppBar(title: tr('log_title')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(tr('log_title'),
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('按步骤打勾，全部完成才能记一条；记录保存在本机，重启不丢。Tick off the SOP steps; all must be complete before a record can be released. Records stay on this device.',
              style: TextStyle(color: grey, fontSize: 12)),
          const SizedBox(height: 8),
          Text(tr('log_steps'),
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
              child: Column(
                children: [
                  InkWell(
                    onTap: () =>
                        setState(() => _sopExpanded = !_sopExpanded),
                    child: Row(
                      children: [
                        Icon(
                            allDone
                                ? Icons.check_circle
                                : Icons.checklist_outlined,
                            size: 20,
                            color: allDone ? Colors.green : bronze),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(tr('log_run_sop'),
                              style: TextStyle(
                                  fontWeight: FontWeight.bold)),
                        ),
                        Text(
                            allDone
                                ? tr('log_done')
                                : '$doneCount/${reloadSopSteps.length}',
                            style: TextStyle(
                                color: allDone ? Colors.green : grey,
                                fontWeight: allDone
                                    ? FontWeight.bold
                                    : FontWeight.normal)),
                        Icon(
                            _sopExpanded
                                ? Icons.expand_less
                                : Icons.expand_more,
                            color: grey),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: doneCount / reloadSopSteps.length,
                    backgroundColor: grey.withValues(alpha: 0.25),
                    color: bronze,
                  ),
                  if (_sopExpanded) ...[
                    const SizedBox(height: 4),
                    // 英文界面显示英文版 SOP（与中文表一一对应，勾选状态按索引共用）。
                    ...(localeNotifier.value == localeEn
                            ? reloadSopStepsEn
                            : reloadSopSteps)
                        .asMap()
                        .entries
                        .map((e) =>
                        CheckboxListTile(
                          dense: true,
                          visualDensity: VisualDensity.compact,
                          contentPadding: EdgeInsets.zero,
                          value: _done[e.key],
                          onChanged: (v) =>
                              setState(() => _done[e.key] = v ?? false),
                          title: Text(e.value,
                              style: const TextStyle(fontSize: 13)),
                          controlAffinity:
                              ListTileControlAffinity.leading,
                        )),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => setState(() => _done =
                            List<bool>.filled(
                                reloadSopSteps.length, false)),
                        child: Text(tr('log_reset_sop')),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: _showSafetyRules,
              icon: const Icon(Icons.warning_amber_outlined,
                  color: Colors.redAccent, size: 18),
              label: Text(
                  tr('safety_rules') + tr('log_rules_mid_a') + '${reloadSafetyRules.length}' + tr('log_rules_mid_b')),
            ),
          ),
          const SizedBox(height: 24),
          Text(tr('log_new'),
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('四步填完：配方 → 组件 → 试射 → 放行检测。带 * 的必须填完整，备注选填；弹头、火药、底火、弹壳、枪械边输边从数据库里搜，点一下即填入，数据库里没有的也可手动填写。Complete in four steps: Recipe → Components → Test Results → Release Check. Fields marked * are required; Notes are optional.',
              style: TextStyle(color: grey, fontSize: 12)),
          const SizedBox(height: 12),
          Text(tr('log_section_recipe'), style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(tr('log_caliber_field')),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButton<String>(
                  value: _caliber,
                  isExpanded: true,
                  hint: Text(tr('log_pick_caliber')),
                  items: reloadCalibers
                      .map((c) => DropdownMenuItem(
                          value: c.caliber, child: Text(c.caliber)))
                      .toList(),
                  onChanged: (v) => setState(() => _caliber = v),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: _reuseLastCaliberRecipe,
              icon: const Icon(Icons.history, size: 18),
              label: Text(tr('log_reuse_recipe')),
            ),
          ),
          const SizedBox(height: 8),
          _SuggestField(controller: _bulletCtrl, label: tr('log_bullet_field'), kind: '弹头'),
          const SizedBox(height: 8),
          _SuggestField(controller: _powderCtrl, label: tr('log_powder_field'), kind: '火药'),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _chargeCtrl,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: tr('log_charge_field'),
                    border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _colCtrl,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: tr('log_col_field'),
                    border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _roundsCtrl,
            keyboardType: TextInputType.number,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: tr('log_rounds_field'),
              border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
            ),
          ),
          if ((double.tryParse(_roundsCtrl.text) ?? 0) >= 10)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      tr('log_scale_prefix') + '$_scaleChecks' + tr('log_scale_suffix'),
                      style: const TextStyle(
                          color: Colors.amber, fontSize: 12),
                    ),
                  ),
                  TextButton(
                    onPressed: () =>
                        setState(() => _scaleChecks++),
                    child: Text(tr('log_scale_check')),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          Text(tr('log_section_components'), style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _SuggestField(controller: _primerCtrl, label: tr('log_primer_field'), kind: '底火'),
          const SizedBox(height: 8),
          TextField(
            controller: _lotCtrl,
            decoration: InputDecoration(
              labelText: tr('log_lot_field'),
              border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _SuggestField(controller: _caseBrandCtrl, label: tr('log_case_brand_field'), kind: '弹壳'),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _caseTimesCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: tr('log_case_times_field'),
                    border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(tr('log_section_test'), style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _SuggestField(
            controller: _firearmCtrl,
            label: tr('log_firearm_field'),
            kind: '',
            customItems: guns.map((g) => '${g.vendor} ${g.name}').toList(),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _velocityCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: tr('log_velocity_field'),
                    border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _groupCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: tr('log_group_field'),
                    border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _weatherCtrl,
            decoration: InputDecoration(
              labelText: tr('log_weather_field'),
              border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            children: ['晴', '阴', '雨', '雪', '室内']
                .map((w) => ActionChip(
                      label: Text(_weatherLabel(w)),
                      onPressed: () =>
                          setState(() => _weatherCtrl.text = w),
                    ))
                .toList(),
          ),
          const SizedBox(height: 8),
          Text(tr('log_section_pressure'),
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            children: _pressureOptions
                .map((o) => FilterChip(
                      label: Text(_pressureLabel(o)),
                      selected: _pressure.contains(o),
                      onSelected: (v) => setState(() {
                        if (v) {
                          _pressure.add(o);
                        } else {
                          _pressure.remove(o);
                        }
                      }),
                    ))
                .toList(),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _noteCtrl,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: tr('log_note_field'),
              suffixIcon: IconButton(
                icon: const Icon(Icons.mic_outlined),
                tooltip: tr('log_voice_tooltip'),
                onPressed: _voiceNote,
              ),
              border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
            ),
          ),
          const SizedBox(height: 12),
          Builder(builder: (_) {
            final miss = _missing();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      miss.isEmpty ? Icons.verified_outlined : Icons.pending_outlined,
                      size: 18,
                      color: miss.isEmpty ? Colors.green : grey,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        miss.isEmpty
                            ? tr('log_check_passed')
                            : tr('log_check_left_prefix') + '${miss.length}' + tr('log_check_left_mid') + miss.take(3).join(tr('log_check_join')) + (miss.length > 3 ? '…' : '') + tr('log_check_left_suffix'),
                        style: TextStyle(
                            color: miss.isEmpty ? Colors.green : grey,
                            fontSize: 13,
                            fontWeight: miss.isEmpty ? FontWeight.bold : FontWeight.normal),
                      ),
                    ),
                  ],
                ),
                if (_caliber != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      _manualCheck().note,
                      style: TextStyle(
                          color: _manualCheck().inRange
                              ? Colors.green
                              : grey,
                          fontSize: 12),
                    ),
                  ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _tryRelease,
                    child: Text(tr('log_verify_btn')),
                  ),
                ),
                if (miss.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(tr('log_verify_hint'),
                        style: TextStyle(color: grey, fontSize: 12)),
                  ),
              ],
            );
          }),
          const SizedBox(height: 16),
          Text(tr('log_count_prefix') + '${_logs.length}' + tr('log_count_suffix'),
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (_logs.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Center(
                  child: Text(tr('no_logs'), style: TextStyle(color: grey))),
            ),
          ..._logs.map((l) => Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Text('${l.date} · ${l.caliber}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold)),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: (l.released
                                            ? Colors.green
                                            : l.pressure.isNotEmpty
                                                ? Colors.red
                                                : Colors.grey)
                                        .withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                      l.released
                                          ? tr('log_status_released')
                                          : l.pressure.isNotEmpty
                                              ? tr('log_status_flagged')
                                              : tr('log_status_unreleased'),
                                      style: TextStyle(
                                          color: l.released
                                              ? Colors.green
                                              : l.pressure.isNotEmpty
                                                  ? Colors.red
                                                  : Colors.grey,
                                          fontSize: 11)),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.replay, size: 20),
                            tooltip: tr('log_reuse_tooltip'),
                            onPressed: () => _reuseRecipe(l),
                          ),
                          IconButton(
                            icon: const Icon(Icons.calculate_outlined,
                                size: 20),
                            tooltip: tr('reload_calc_energy'),
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => LoadToolsScreen(
                                  initialBulletGr: _grOf(l.bullet),
                                  initialVelocityFps: _firstNum(l.velocity),
                                  initialPowderGr:
                                      double.tryParse(l.charge),
                                  initialLabel:
                                      tr('log_share_prefix') + '${l.batchNo.isNotEmpty ? l.batchNo : l.date} · ${l.caliber}',
                                ),
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.attach_money_outlined,
                                size: 20),
                            tooltip: tr('log_cost_tooltip'),
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ReloadCostScreen(
                                  initialPowderGr:
                                      double.tryParse(l.charge),
                                  initialRounds:
                                      int.tryParse(l.rounds),
                                  initialLabel:
                                      tr('log_share_prefix') + '${l.batchNo.isNotEmpty ? l.batchNo : l.date} · ${l.caliber}',
                                ),
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 20),
                            onPressed: () {
                              setState(() => _logs.remove(l));
                              _save();
                            },
                          ),
                        ],
                      ),
                      if (l.batchNo.isNotEmpty)
                        Text(tr('log_row_batch') + l.batchNo,
                            style: TextStyle(color: grey, fontSize: 12)),
                      if (l.pressure.isNotEmpty)
                        Text(tr('log_row_pressure') + l.pressure.split('、').map(_pressureLabel).join(tr('log_pressure_join')),
                            style: const TextStyle(color: Colors.red)),
                      if (l.bullet.isNotEmpty) Text(tr('log_row_bullet') + l.bullet),
                      if (l.powder.isNotEmpty) Text(tr('log_row_powder') + l.powder),
                      if (l.charge.isNotEmpty) Text(tr('log_row_charge') + '${l.charge} gr'),
                      if (l.col.isNotEmpty) Text(tr('log_row_col') + '${l.col}″'),
                      if (l.rounds.isNotEmpty) Text(tr('log_row_rounds') + '${l.rounds}' + tr('ammo_rounds_suffix')),
                      if (l.primer.isNotEmpty) Text(tr('log_row_primer') + l.primer),
                      if (l.lot.isNotEmpty) Text(tr('log_row_lot') + l.lot),
                      if (l.caseBrand.isNotEmpty)
                        Text(tr('log_row_case') + l.caseBrand + (l.caseTimes.isNotEmpty ? tr('log_row_case_times_prefix') + l.caseTimes + tr('log_row_case_times_suffix') : '')),
                      if (l.velocity.isNotEmpty) Text(tr('log_row_velocity') + '${l.velocity} fps'),
                      if (l.group.isNotEmpty) Text(tr('log_row_group') + '${l.group}″'),
                      if (l.firearm.isNotEmpty) Text(tr('log_row_firearm') + l.firearm),
                      if (l.weather.isNotEmpty) Text(tr('log_row_weather') + _weatherLabel(l.weather)),
                      if (l.note.isNotEmpty) Text(tr('log_row_note') + l.note),
                    ],
                  ),
                ),
              )),
        ],
      ),
    );
  }
}

/// 边输边搜输入框：输入时从复装组件库（弹头/火药/底火/弹壳）或自定义列表
/// （试射枪械用图鉴枪名）里实时过滤，最多显示 6 条，点一下即填入；
/// 数据库里没有的仍可手动填写，不卡保存。
class _SuggestField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String kind;
  final List<String>? customItems;
  const _SuggestField({
    required this.controller,
    required this.label,
    this.kind = '',
    this.customItems,
  });

  @override
  State<_SuggestField> createState() => _SuggestFieldState();
}

class _SuggestFieldState extends State<_SuggestField> {
  final _focus = FocusNode();
  String _query = '';
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (mounted) setState(() => _focused = _focus.hasFocus);
    });
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  List<String> _suggestions() {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    if (widget.customItems != null) {
      return widget.customItems!
          .where((s) => s.toLowerCase().contains(q))
          .take(6)
          .toList();
    }
    return reloadComponents
        .where((c) =>
            c.kind == widget.kind &&
            ('${c.vendor} ${c.name} ${c.spec}'.toLowerCase().contains(q)))
        .map((c) => '${c.vendor} ${c.name}')
        .take(6)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final sug = _suggestions();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: widget.controller,
          focusNode: _focus,
          onChanged: (v) => setState(() => _query = v),
          decoration: InputDecoration(
            labelText: widget.label,
            border: const OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(12))),
            suffixIcon: widget.controller.text.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () {
                      widget.controller.clear();
                      setState(() => _query = '');
                    },
                  ),
          ),
        ),
        if (_focused && _query.trim().isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: sug.isEmpty
                ? Padding(
                    padding: EdgeInsets.all(10),
                    child: Text(tr('log_no_match_hint'),
                        style: TextStyle(color: Colors.grey, fontSize: 12)),
                  )
                : Column(
                    children: sug
                        .map((s) => ListTile(
                              dense: true,
                              title: Text(s, style: const TextStyle(fontSize: 14)),
                              onTap: () {
                                widget.controller.text = s;
                                setState(() => _query = '');
                                _focus.unfocus();
                              },
                            ))
                        .toList(),
                  ),
          ),
      ],
    );
  }
}
