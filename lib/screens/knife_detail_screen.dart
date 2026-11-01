import 'package:flutter/material.dart';
import '../i18n.dart';
import '../english_terms.dart';
import '../models.dart';
import '../widgets/app_top_bar.dart';
import '../widgets/knife_silhouette.dart';

class KnifeDetailScreen extends StatelessWidget {
  final Knife knife;
  const KnifeDetailScreen({super.key, required this.knife});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final grey = dark ? const Color(0xFF8A8578) : const Color(0xFF9A917F);
    final ink = dark ? const Color(0xFFEDE8DF) : const Color(0xFF2E2A24);
    final bronze = dark ? const Color(0xFFC9A86A) : const Color(0xFF6B5B3E);
    final rows = [
      ('Country', countryDisplay(knife.country)),
      ('Type', knifeTypeDisplay(knife.type)),
      ('Blade Length', knife.bladeLength),
      ('Steel', knife.steel),
      ('Year / Service', knife.year),
    ];
    return Scaffold(
      appBar: SubPageAppBar(title: knife.nameEn),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
        children: [
          Container(
            height: 180,
            padding: const EdgeInsets.symmetric(horizontal: 32),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.black
                  : const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(16),
            ),
            child: KnifeSilhouette(type: knife.type, color: bronze),
          ),
          const SizedBox(height: 6),
          Text(tr('knife_note'),
              style: TextStyle(color: grey, fontSize: 11)),
          const SizedBox(height: 16),
          Text(knife.nameEn,
              style: TextStyle(
                  fontSize: 22, fontWeight: FontWeight.bold, color: ink)),
          const SizedBox(height: 4),
          Text(knife.name, style: TextStyle(color: grey, fontSize: 14)),
          const SizedBox(height: 16),
          ...rows.map((r) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                        width: 72,
                        child: Text(r.$1,
                            style: TextStyle(color: grey, fontSize: 13))),
                    Expanded(
                        child: Text(r.$2,
                            style: TextStyle(color: ink, fontSize: 14))),
                  ],
                ),
              )),
          const SizedBox(height: 8),
          Text(
              localeNotifier.value == localeEn &&
                      knife.descriptionEn.isNotEmpty
                  ? knife.descriptionEn
                  : knife.description,
              style: TextStyle(color: ink, fontSize: 14, height: 1.6)),
        ],
      ),
    );
  }
}
