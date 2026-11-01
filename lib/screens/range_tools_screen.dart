import 'dart:convert';
import '../i18n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../tools_units.dart';
import '../widgets/app_top_bar.dart';
import 'dope_screen.dart';
import 'gun_picker_dialog.dart';

/// 靶场换算：只算你输入的数，不画弹道、不给装药建议。
/// 公式（公开常用值）：
/// - 1 MOA 在 100 米 ≈ 2.909 厘米；在 100 码 = 1.047 英寸；
/// - 1 密位在 100 米 = 10 厘米；
/// - 常见瞄具每格：1/4 MOA、1/2 MOA、1 MOA、0.1 密位。
/// 归零助手已并入 DOPE数据本：本页只留散布换算与速查表，
/// 归零调瞄请去工具页“DOPE数据本”里算、同一页直接记卡。
class RangeToolsScreen extends StatefulWidget {
  /// 带入值一律用公制原单位（米、厘米），页内按单位制换算显示。
  final double? initialDistM;
  final double? initialGroupCm;
  final String? initialLabel;
  const RangeToolsScreen(
      {super.key,
      this.initialDistM,
      this.initialGroupCm,
      this.initialLabel});

  @override
  State<RangeToolsScreen> createState() => _RangeToolsScreenState();
}

class _RangeToolsScreenState extends State<RangeToolsScreen> {
  static const _prefsChannel = MethodChannel('gunsmap/prefs');
  static const _prefsKey = 'range_tools_inputs_v1';
  final _groupCtrl = TextEditingController();
  final _distCtrl = TextEditingController(text: '100');
  final _moaCtrl = TextEditingController();

  void _onUnitsChanged() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    unitSystemNotifier.addListener(_onUnitsChanged);
    _init();
  }

  Future<void> _init() async {
    await loadUnitSystem();
    if (!mounted) return;
    setState(() {});
    await _load();
  }

  Future<void> _load() async {
    try {
      final raw = await _prefsChannel
          .invokeMethod<String>('getString', {'key': _prefsKey})
          .timeout(const Duration(seconds: 2));
      if (raw != null && raw.isNotEmpty && mounted) {
        final m = jsonDecode(raw) as Map<String, dynamic>;
        setState(() {
          void set(TextEditingController c, String k) {
            final v = m[k] as String?;
            if (v != null) c.text = v;
          }
          set(_groupCtrl, 'group');
          set(_distCtrl, 'dist');
          set(_moaCtrl, 'moa');
        });
      }
    } catch (_) {}
    if (!mounted) return;
    final metric = isMetricUnits;
    final d = widget.initialDistM;
    final g = widget.initialGroupCm;
    if (d == null && g == null) return;
    setState(() {
      if (d != null) {
        _distCtrl.text = metric ? _fmt(d) : _fmt(d / 0.9144);
      }
      if (g != null) {
        _groupCtrl.text = metric ? _fmt(g) : _fmt(g / 2.54);
      }
    });
    _save();
  }

  void _save() {
    try {
      _prefsChannel.invokeMethod('setString', {
        'key': _prefsKey,
        'value': jsonEncode({
          'group': _groupCtrl.text,
          'dist': _distCtrl.text,
          'moa': _moaCtrl.text,
        }),
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    unitSystemNotifier.removeListener(_onUnitsChanged);
    _groupCtrl.dispose();
    _distCtrl.dispose();
    _moaCtrl.dispose();
    super.dispose();
  }

  String _fmt(double v, [int digits = 2]) {
    var s = v.toStringAsFixed(digits);
    while (s.contains('.') && s.endsWith('0')) {
      s = s.substring(0, s.length - 1);
    }
    if (s.endsWith('.')) s = s.substring(0, s.length - 1);
    return s;
  }

  @override
  Widget build(BuildContext context) {
    // 单位制跟随工具页设置：英制时散布与偏差按英寸输入、距离按码输入，
    // 内部统一换算成厘米与米再套原公式；公制时沿用原来的厘米与米。
    final metric = isMetricUnits;
    final groupCm = (double.tryParse(_groupCtrl.text) ?? 0) *
        (metric ? 1 : 2.54);
    final distM = (double.tryParse(_distCtrl.text) ?? 0) *
        (metric ? 1 : 0.9144);
    final distInput = double.tryParse(_distCtrl.text) ?? 0;
    final moa = double.tryParse(_moaCtrl.text) ?? 0;

    // 1 MOA 在 dist 米处 ≈ dist * 0.02909 厘米；1 密位 = dist * 0.1 厘米。
    final moaValue = distM > 0 ? groupCm / (distM * 0.02909) : 0.0;
    final mradValue = distM > 0 ? groupCm / (distM * 0.1) : 0.0;
    final moaGroupCm = distM > 0 ? moa * distM * 0.02909 : 0.0;

    return ValueListenableBuilder<String>(
      valueListenable: unitSystemNotifier,
      builder: (_, __, ___) => Scaffold(
      appBar: SubPageAppBar(title: tr('tools_range_title')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(tr('range_calc_note'),
              style: TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.book_outlined),
              title: Text(tr('range_dope_moved_title')),
              subtitle: Text(tr('range_dope_moved_sub')),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                final gun = await showGunPickerDialog(context);
                if (gun == null || !context.mounted) return;
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => DopeScreen(gun: gun)),
                );
              },
            ),
          ),
          if (widget.initialLabel != null) ...[
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(tr('range_carried_prefix') + (widget.initialLabel ?? '') + tr('range_carried_suffix'),
                    style: const TextStyle(fontSize: 13)),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Text(tr('range_dispersion_title'),
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _NumberField(
              controller: _groupCtrl,
              label: metric ? tr('range_group_cm_label') : tr('range_group_in_label'),
              onChanged: (_) { setState(() {}); _save(); }),
          if (groupCm > 0 && distM > 0) ...[
            _ResultLine(
                tr('range_group_eq') + '${_fmt(moaValue)} MOA (${_fmt(mradValue)} Mil)'),
            Text(tr('range_moa_at_prefix') + '${_fmt(distM * 0.02909)}' + tr('range_moa_at_mid') + '${_fmt(distM * 0.1)}' + tr('range_moa_at_suffix'),
                style: const TextStyle(color: Colors.grey, fontSize: 12)),
          ],
          const SizedBox(height: 8),
          _NumberField(
              controller: _moaCtrl,
              label: tr('range_moa_input_label'),
              onChanged: (_) { setState(() {}); _save(); }),
          if (moa > 0 && distM > 0)
            _ResultLine(
                '${_fmt(moa)}' + tr('range_moa_result_b') + '${_fmt(distInput)}' + (metric ? tr('range_unit_m') : tr('range_unit_yd')) + tr('range_moa_result_c') + '${_fmt(moaGroupCm)}' + tr('range_unit_cm')),
          const SizedBox(height: 20),
          Text(tr('range_quick_title'),
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(tr('range_quick_note'),
              style: TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 8),
          for (final d in [50.0, 100.0, 200.0, 300.0])
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(
                  '${_fmt(d, 0)}' + tr('range_unit_m') + tr('range_quick_row_mid_a') + '${_fmt(d * 0.02909)}' + tr('range_quick_row_mid_b') + '${_fmt(d * 0.01)}' + tr('range_unit_cm')),
            ),
          const SizedBox(height: 8),
          Text(tr('range_unit_footer_prefix') + (metric ? tr('tools_unit_metric') : tr('tools_unit_imperial')) + tr('range_unit_footer_suffix'),
              style: const TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      ),
      ),
    );
  }
}

class _NumberField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final ValueChanged<String> onChanged;
  const _NumberField(
      {required this.controller,
      required this.label,
      required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
      ),
    );
  }
}

class _ResultLine extends StatelessWidget {
  final String text;
  const _ResultLine(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(text,
          style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFFE86A1C),
              fontSize: 15)),
    );
  }
}
