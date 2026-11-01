import 'package:flutter/material.dart';
import '../i18n.dart';
import '../data.dart';
import '../english_terms.dart';
import '../models.dart';

/// 从图鉴选一把枪：搜索框 + 列表，枪柜与靶场成绩共用。
Future<Gun?> showGunPickerDialog(BuildContext context) async {
  final ctrl = TextEditingController();
  var query = '';
  final picked = await showDialog<Gun>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (_, setDialogState) {
        final q = query.trim().toLowerCase();
        final results = q.isEmpty
            ? guns.take(60).toList()
            : guns
                .where((g) =>
                    g.name.toLowerCase().contains(q) ||
                    (g.nameEn ?? '').toLowerCase().contains(q) ||
                    g.vendor.toLowerCase().contains(q) ||
                    g.caliber.toLowerCase().contains(q))
                .take(60)
                .toList();
        return AlertDialog(
          title: Text(tr('picker_title')),
          content: SizedBox(
            width: double.maxFinite,
            height: 420,
            child: Column(
              children: [
                TextField(
                  controller: ctrl,
                  onChanged: (v) => setDialogState(() => query = v),
                  // 聚焦边与未聚焦同一支：只写 border 时聚焦会回落全局橙色边。
                  decoration: InputDecoration(
                    hintText: tr('picker_hint'),
                    prefixIcon: const Icon(Icons.search),
                    border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                    enabledBorder: OutlineInputBorder(
                      borderRadius:
                          const BorderRadius.all(Radius.circular(12)),
                      borderSide: BorderSide(
                          color: Colors.grey.withValues(alpha: 0.35)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius:
                          const BorderRadius.all(Radius.circular(12)),
                      borderSide: BorderSide(
                          color: Colors.grey.withValues(alpha: 0.35)),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: results.isEmpty
                      ? Center(child: Text(tr('picker_empty')))
                      : ListView.builder(
                          itemCount: results.length,
                          itemBuilder: (_, i) {
                            final g = results[i];
                            return ListTile(
                              title: Text(gunDisplayName(g)),
                              subtitle: Text(
                                  '${vendorDisplay(g.vendor)} · ${g.caliber}'),
                              onTap: () => Navigator.of(dialogContext)
                                  .pop(g),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(tr('cancel')),
            ),
          ],
        );
      },
    ),
  );
  ctrl.dispose();
  return picked;
}
