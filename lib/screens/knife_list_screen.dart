import 'package:flutter/material.dart';
import '../i18n.dart';
import '../english_terms.dart';
import '../haptics.dart';
import '../knife_data.dart';
import '../models.dart';
import '../widgets/app_top_bar.dart';
import '../widgets/knife_silhouette.dart';
import 'knife_detail_screen.dart';

class KnifeListScreen extends StatefulWidget {
  const KnifeListScreen({super.key});

  @override
  State<KnifeListScreen> createState() => _KnifeListScreenState();
}

class _KnifeListScreenState extends State<KnifeListScreen> {
  String _type = '全部';
  String _country = '全部';
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final grey = dark ? const Color(0xFF8A8578) : const Color(0xFF9A917F);
    final ink = dark ? const Color(0xFFEDE8DF) : const Color(0xFF2E2A24);
    final bronze = dark ? const Color(0xFFC9A86A) : const Color(0xFF6B5B3E);
    final cardBg = dark ? const Color(0xFF0D0D0D) : Colors.white;
    final q = _query.trim().toLowerCase();
    final filtered = knives.where((k) {
      if (_type != '全部' && k.type != _type) return false;
      if (_country != '全部' && k.country != _country) return false;
      if (q.isEmpty) return true;
      return k.name.toLowerCase().contains(q) ||
          k.nameEn.toLowerCase().contains(q) ||
          k.country.toLowerCase().contains(q) ||
          countryDisplay(k.country).toLowerCase().contains(q) ||
          k.type.toLowerCase().contains(q) ||
          knifeTypeDisplay(k.type).toLowerCase().contains(q);
    }).toList();
    return Scaffold(
      appBar: SubPageAppBar(title: tr('knife_title')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
        children: [
          TextField(
            // 聚焦边与未聚焦同一支：不写 focusedBorder 会回落全局橙色边。
            decoration: InputDecoration(
              hintText: tr('knife_search_hint'),
              prefixIcon: const Icon(Icons.search),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    BorderSide(color: Colors.grey.withValues(alpha: 0.35)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    BorderSide(color: Colors.grey.withValues(alpha: 0.35)),
              ),
            ),
            onChanged: (v) => setState(() => _query = v),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ['全部', ...knifeTypes].map((t) {
              final selected = _type == t;
              return ChoiceChip(
                label: Text(t == '全部' ? tr('all') : knifeTypeDisplay(t)),
                selected: selected,
                selectedColor: bronze,
                labelStyle: TextStyle(
                    color: selected
                        ? Colors.white
                        : (dark ? ink : const Color(0xFF2E2A24))),
                onSelected: (_) => setState(() => _type = t),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ['全部', ...knifeCountries].map((c) {
              final selected = _country == c;
              return ChoiceChip(
                label: Text(c == '全部' ? tr('all') : countryDisplay(c)),
                selected: selected,
                selectedColor: bronze,
                labelStyle: TextStyle(
                    color: selected
                        ? Colors.white
                        : (dark ? ink : const Color(0xFF2E2A24))),
                onSelected: (_) => setState(() => _country = c),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          Text(tr('knife_count_prefix') + '${filtered.length}' + tr('knife_count_suffix'),
              style: TextStyle(color: grey, fontSize: 12)),
          const SizedBox(height: 12),
          ...filtered.map((k) => _knifeRow(context, k, cardBg, grey, ink)),
          if (filtered.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 24),
              child: Center(child: Text(tr('knife_empty'), style: TextStyle(color: grey))),
            ),
        ],
      ),
    );
  }

  Widget _knifeRow(
      BuildContext context, Knife k, Color cardBg, Color grey, Color ink) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        leading: SizedBox(
          width: 64,
          height: 32,
          child: KnifeSilhouette(
              type: k.type,
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFFC9A86A)
                  : const Color(0xFF6B5B3E)),
        ),
        title: Text(k.nameEn),
        subtitle: Text(
            '${countryDisplay(k.country)} · ${knifeTypeDisplay(k.type)} · Blade Length ${k.bladeLength}',
            maxLines: 1, overflow: TextOverflow.ellipsis),
        onTap: () {
          tapHaptic();
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => KnifeDetailScreen(knife: k)),
          );
        },
      ),
    );
  }
}
