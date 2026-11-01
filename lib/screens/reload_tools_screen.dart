import 'package:flutter/material.dart';
import '../i18n.dart';
import '../data.dart';
import '../english_terms.dart';
import '../models.dart';
import '../widgets/app_top_bar.dart';

/// 复装工具页：按类别列出复装常用工具，每样标具体功能与美国零售参考价。
/// 价格为 2026 年 10 月核实的参考价（以具体型号/口径为例），下单以商家标价为准；
/// 未查到的标“未确认”，不现编。
class ReloadToolsScreen extends StatefulWidget {
  const ReloadToolsScreen({super.key});

  @override
  State<ReloadToolsScreen> createState() => _ReloadToolsScreenState();
}

class _ReloadToolsScreenState extends State<ReloadToolsScreen> {
  String _query = '';

  static const _order = [
    '压床',
    '模具与壳座',
    '称量与量粉',
    '测量与规具',
    '弹壳修整',
    '底火窝与传火孔',
    '底火安装',
    '弹壳清洁',
    '润滑与辅助',
    '拔弹与故障处理',
  ];

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final grey = dark ? const Color(0xFF8A8578) : const Color(0xFF9A917F);
    final bronze = dark ? const Color(0xFFC9A86A) : const Color(0xFF6B5B3E);
    final q = _query.trim().toLowerCase();
    final filtered = reloadTools.where((t) {
      if (q.isEmpty) return true;
      return t.name.toLowerCase().contains(q) ||
          t.vendor.toLowerCase().contains(q) ||
          t.category.toLowerCase().contains(q) ||
          toolCategoryDisplay(t.category).toLowerCase().contains(q) ||
          t.function.toLowerCase().contains(q);
    }).toList();
    return Scaffold(
      appBar: SubPageAppBar(title: tr('reload_tools_title')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                tr('reload_tools_intro'),
                style: TextStyle(color: grey, fontSize: 12),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            decoration: InputDecoration(
              hintText: tr('reload_tools_search_hint'),
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => setState(() => _query = ''),
                    ),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24)),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            onChanged: (v) => setState(() => _query = v),
          ),
          const SizedBox(height: 16),
          for (final cat in _order)
            if (filtered.any((t) => t.category == cat)) ...[
              Text(toolCategoryDisplay(cat),
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ...filtered
                  .where((t) => t.category == cat)
                  .map((t) => _toolCard(t, bronze, grey)),
              const SizedBox(height: 16),
            ],
          if (filtered.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 24),
              child: Center(
                child: Text(tr('reload_tools_empty'), style: TextStyle(color: grey)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _toolCard(ReloadTool t, Color bronze, Color grey) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(t.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15)),
                ),
                if (t.essential)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: bronze,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(tr('reload_tools_essential'),
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.white)),
                  ),
              ],
            ),
            const SizedBox(height: 2),
            Text(t.vendor, style: TextStyle(color: grey, fontSize: 12)),
            const SizedBox(height: 6),
            Text(t.function, style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 6),
            Row(
              children: [
                Text(tr('reload_tools_price_label'), style: TextStyle(color: grey, fontSize: 12)),
                const SizedBox(width: 8),
                Text(
                  t.price == '未确认' ? tr('compare_unconfirmed') : t.price,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: t.price == '未确认' ? grey : bronze,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
