import 'package:flutter/material.dart';

import '../i18n.dart';
import '../tools_units.dart';
import '../widgets/app_top_bar.dart';

/// 单位设置区（第 8 项）：只学截图的分段 pill + 分组折叠形态，
/// 不抄截图里的解算开关（Aerodynamic Jump / Spin Drift /
/// Coriolis 等一律不做）。每行左标签、右分段 pill，2–3 档；
/// 存 tools_units_v1（分维度表），长度维度同步旧版英制/公制。
class UnitSettingsScreen extends StatefulWidget {
  const UnitSettingsScreen({super.key});

  @override
  State<UnitSettingsScreen> createState() => _UnitSettingsScreenState();
}

class _UnitSettingsScreenState extends State<UnitSettingsScreen> {
  @override
  void initState() {
    super.initState();
    loadUnitSystem();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: SubPageAppBar(title: tr('unit_settings_title')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(tr('unit_settings_note'),
              style: const TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 12),
          _Group(
            title: tr('unit_group_length'),
            children: [
              _UnitRow(
                dim: 'length',
                label: tr('unit_row_length'),
                options: [
                  ('m', tr('unit_length_m')),
                  ('yd', tr('unit_length_yd')),
                ],
              ),
            ],
          ),
          _Group(
            title: tr('unit_group_weight'),
            children: [
              _UnitRow(
                dim: 'weight',
                label: tr('unit_row_weight'),
                options: [
                  ('kg', tr('unit_weight_kg')),
                  ('lb', tr('unit_weight_lb')),
                ],
              ),
            ],
          ),
          _Group(
            title: tr('unit_group_velocity'),
            children: [
              _UnitRow(
                dim: 'velocity',
                label: tr('unit_row_velocity'),
                options: [
                  ('ms', tr('unit_velocity_ms')),
                  ('fps', tr('unit_velocity_fps')),
                  ('kmh', tr('unit_velocity_kmh')),
                ],
              ),
            ],
          ),
          _Group(
            title: tr('unit_group_temperature'),
            children: [
              _UnitRow(
                dim: 'temperature',
                label: tr('unit_row_temperature'),
                options: [
                  ('c', tr('unit_temperature_c')),
                  ('f', tr('unit_temperature_f')),
                ],
              ),
            ],
          ),
          _Group(
            title: tr('unit_group_pressure'),
            children: [
              _UnitRow(
                dim: 'pressure',
                label: tr('unit_row_pressure'),
                options: [
                  ('hpa', tr('unit_pressure_hpa')),
                  ('inhg', tr('unit_pressure_inhg')),
                ],
              ),
            ],
          ),
          _Group(
            title: tr('unit_group_energy'),
            children: [
              _UnitRow(
                dim: 'energy',
                label: tr('unit_row_energy'),
                options: [
                  ('j', tr('unit_energy_j')),
                  ('ftlb', tr('unit_energy_ftlb')),
                ],
              ),
            ],
          ),
          _Group(
            title: tr('unit_group_display'),
            children: [
              _UnitRow(
                dim: 'targetName',
                label: tr('unit_row_target'),
                options: [
                  ('alpha', tr('unit_target_alpha')),
                  ('numeric', tr('unit_target_numeric')),
                ],
              ),
              _UnitRow(
                dim: 'holdIndicator',
                label: tr('unit_row_hold'),
                options: [
                  ('udlr', tr('unit_hold_udlr')),
                  ('plusminus', tr('unit_hold_plusminus')),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Group extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _Group({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ExpansionTile(
        title: Text(title,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        initiallyExpanded: true,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }
}

class _UnitRow extends StatelessWidget {
  final String dim;
  final String label;
  final List<(String, String)> options;
  const _UnitRow({
    required this.dim,
    required this.label,
    required this.options,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Map<String, String>>(
      valueListenable: unitPrefsNotifier,
      builder: (_, prefs, __) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Expanded(child: Text(label)),
            const SizedBox(width: 8),
            _SegmentedPill(
              options: options,
              selected: prefs[dim] ?? unitPrefsDefaults[dim]!,
              onPick: (v) => saveUnitPref(dim, v),
            ),
          ],
        ),
      ),
    );
  }
}

/// 分段 pill：圆角条内 2–3 档，选中为品牌橙底白字。
class _SegmentedPill extends StatelessWidget {
  final List<(String, String)> options;
  final String selected;
  final ValueChanged<String> onPick;
  const _SegmentedPill({
    required this.options,
    required this.selected,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final o in options)
            GestureDetector(
              onTap: () => onPick(o.$1),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: o.$1 == selected
                      ? const Color(0xFFE86A1C)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  o.$2,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: o.$1 == selected
                        ? FontWeight.bold
                        : FontWeight.normal,
                    color: o.$1 == selected ? Colors.white : Colors.grey,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
