import 'package:flutter/material.dart';

import '../bullet_profiles.dart';
import '../i18n.dart';

/// 弹头档案卡（子弹目录 / 复装页 / 供应商页三处复用）。
/// profiles 为同一系列同弹径的已核实变体；空表时调用方不渲染本卡。
class BulletProfileCard extends StatelessWidget {
  final List<BulletProfile> profiles;

  const BulletProfileCard({super.key, required this.profiles});

  String _v(String s) => s.isEmpty ? tr('gun_data_not_listed') : s;

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 88,
            child: Text(
              label,
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (profiles.isEmpty) return const SizedBox.shrink();
    final first = profiles.first;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${tr('bullet_profile_title')} · ${first.vendor}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 6),
            for (var i = 0; i < profiles.length; i++) ...[
              if (i > 0) const Divider(height: 16),
              Text(
                profiles[i].name,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 2),
              _row(
                tr('bullet_profile_diameter'),
                profiles[i].diameterMm.isEmpty
                    ? tr('gun_data_not_listed')
                    : '${profiles[i].diameterMm} mm',
              ),
              _row(
                tr('bullet_profile_weight'),
                profiles[i].weightGr.isEmpty
                    ? tr('gun_data_not_listed')
                    : '${profiles[i].weightGr} gr',
              ),
              _row(
                tr('bullet_profile_bc'),
                'G1 ${_v(profiles[i].bcG1)} / G7 ${_v(profiles[i].bcG7)}',
              ),
              _row(
                tr('bullet_profile_drag'),
                _v(profiles[i].dragCoeff),
              ),
              _row(
                tr('bullet_profile_length'),
                profiles[i].lengthMm.isEmpty
                    ? tr('gun_data_not_listed')
                    : '${profiles[i].lengthMm} mm',
              ),
            ],
          ],
        ),
      ),
    );
  }
}
