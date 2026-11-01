import 'package:flutter/material.dart';
import '../data.dart';
import '../bullet_profiles.dart';
import '../english_terms.dart';
import '../widgets/app_top_bar.dart';
import '../widgets/bullet_profile_card.dart';
import '../i18n.dart';

/// 组件供应商子页：从复装页独立出来，避免长列表挡住下面内容。
class SuppliersScreen extends StatefulWidget {
  const SuppliersScreen({super.key});

  @override
  State<SuppliersScreen> createState() => _SuppliersScreenState();
}

class _SuppliersScreenState extends State<SuppliersScreen> {
  String? _kind;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final grey = dark ? const Color(0xFF8A8578) : const Color(0xFF9A917F);
    const kinds = ['弹头', '弹壳', '火药', '底火'];
    final components = _kind == null
        ? reloadComponents
        : reloadComponents.where((c) => c.kind == _kind).toList();
    return Scaffold(
      appBar: SubPageAppBar(title: tr('suppliers')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(tr('suppliers') + ' · ' + tr('suppliers_total_prefix') + '${reloadComponents.length}' + tr('suppliers_total_suffix'),
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
                tr('suppliers_price_note'),
                style: TextStyle(color: grey, fontSize: 12)),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                ChoiceChip(
                  label: Text(tr('all')),
                  selected: _kind == null,
                  onSelected: (_) => setState(() => _kind = null),
                ),
                ...kinds.map((k) => Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: ChoiceChip(
                        label: Text(componentKindDisplay(k)),
                        selected: _kind == k,
                        onSelected: (_) =>
                            setState(() => _kind = _kind == k ? null : k),
                      ),
                    )),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: components.length,
              itemBuilder: (context, i) {
                final c = components[i];
                final profiles = c.kind == '弹头'
                    ? bulletProfilesForComponent(c.vendor, c.name)
                    : const <BulletProfile>[];
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Text('${c.vendor} ${c.name}'),
                        subtitle: Text(
                            '${c.spec}\n${c.feature}\n' + tr('suppliers_price_prefix') + '${c.price}'),
                        trailing:
                            Chip(label: Text(componentKindDisplay(c.kind))),
                        isThreeLine: true,
                      ),
                    ),
                    if (profiles.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: BulletProfileCard(profiles: profiles),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
