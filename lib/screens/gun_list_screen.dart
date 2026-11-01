import 'package:flutter/material.dart';
import '../data.dart';
import '../english_terms.dart';
import '../haptics.dart';
import '../i18n.dart';
import '../models.dart';
import '../widgets/app_top_bar.dart';
import 'gun_detail_screen.dart';

/// 品类内页：按厂商分组，每个厂商一个可折叠分区，分区内是该厂商的型号。
class GunListScreen extends StatelessWidget {
  final String category;
  const GunListScreen({super.key, required this.category});

  @override
  Widget build(BuildContext context) {
    final list = guns.where((g) => g.category == category).toList();
    final Map<String, List<Gun>> byVendor = {};
    for (final g in list) {
      byVendor.putIfAbsent(g.vendor, () => []).add(g);
    }
    final vendors = byVendor.keys.toList()..sort();
    return Scaffold(
      appBar: SubPageAppBar(title: categoryDisplay(category)),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(categoryDisplay(category),
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold)),
                Text(
                    '${categoryDisplay(category)} · ${list.length}' + tr('gun_count_suffix'),
                    style: const TextStyle(color: Colors.grey)),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
              itemCount: vendors.length,
        itemBuilder: (context, i) {
          final vendor = vendors[i];
          final models = byVendor[vendor]!;
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Theme(
              data: Theme.of(context)
                  .copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                initiallyExpanded: vendors.length <= 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                collapsedShape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                childrenPadding: const EdgeInsets.only(bottom: 8),
                title: Text(vendorDisplay(vendor),
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(modelsCountText(models.length),
                    style: const TextStyle(color: Color(0xFF9A917F))),
                children: models
                    .map((g) => ListTile(
                          leading: g.image != null
                              ? Image.asset(g.image!,
                                  width: 90, fit: BoxFit.contain)
                              : const Icon(Icons.image_not_supported,
                                  size: 36, color: Color(0xFF9A917F)),
                          title: Text(gunDisplayName(g)),
                          subtitle: Text(g.caliber),
                          onTap: () {
                            tapHaptic();
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => GunDetailScreen(gun: g)),
                            );
                          },
                        ))
                    .toList(),
              ),
            ),
          );
        },
              ),
            ),
          ],
        ),
      );
  }
}
