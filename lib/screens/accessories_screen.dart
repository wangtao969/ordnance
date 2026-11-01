import 'package:flutter/material.dart';
import '../data.dart';
import '../english_terms.dart';
import '../haptics.dart';
import '../i18n.dart';
import '../models.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import '../widgets/app_top_bar.dart';
import '../widgets/app_toast.dart';
import '../widgets/scale_tap.dart';

class AccessoriesScreen extends StatefulWidget {
  const AccessoriesScreen({super.key});

  @override
  State<AccessoriesScreen> createState() => _AccessoriesScreenState();
}

class _AccessoriesScreenState extends State<AccessoriesScreen> {
  String? _vendor;
  String? _type;
  String? _category;

  /// 配件按品类分：从适配枪型反查其品类，不再按具体型号筛。
  Set<String> _accessoryCategories(AccessoryItem a) {
    final cats = <String>{};
    for (final name in a.fitGuns) {
      for (final g in guns) {
        if (g.name == name) cats.add(g.category);
      }
    }
    return cats;
  }

  /// 卡片上只显示适配口径：从适配枪型反查口径并去重。
  List<String> _accessoryCalibers(AccessoryItem a) {
    final cals = <String>[];
    for (final name in a.fitGuns) {
      for (final g in guns) {
        if (g.name == name && !cals.contains(g.caliber)) {
          cals.add(g.caliber);
        }
      }
    }
    return cals;
  }

  @override
  Widget build(BuildContext context) {
    final types = accessories.map((a) => a.type).toSet().toList();
    final list = accessories.where((a) {
      if (_vendor != null && a.vendor != _vendor) return false;
      if (_type != null && a.type != _type) return false;
      if (_category != null &&
          !_accessoryCategories(a).contains(_category)) {
        return false;
      }
      return true;
    }).toList();
    return Scaffold(
      appBar: SubPageAppBar(title: tr('acc_catalog_title')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: Text(tr('vendor'),
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                ChoiceChip(
                  label: Text(tr('all')),
                  selected: _vendor == null,
                  onSelected: (_) => setState(() => _vendor = null),
                ),
                ...vendors.map((v) => Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: ChoiceChip(
                        label: Text(v),
                        selected: _vendor == v,
                        onSelected: (_) =>
                            setState(() => _vendor = _vendor == v ? null : v),
                      ),
                    )),
              ],
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                ChoiceChip(
                  label: Text(tr('all_types')),
                  selected: _type == null,
                  onSelected: (_) => setState(() => _type = null),
                ),
                ...types.map((t) => Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: ChoiceChip(
                        label: Text(accessoryTypeDisplay(t)),
                        selected: _type == t,
                        onSelected: (_) =>
                            setState(() => _type = _type == t ? null : t),
                      ),
                    )),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: EdgeInsets.fromLTRB(12, 4, 12, 4),
            child: Text(tr('by_category'),
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                ChoiceChip(
                  label: Text(tr('all_categories')),
                  selected: _category == null,
                  onSelected: (_) => setState(() => _category = null),
                ),
                ...categories.map((c) => Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: ChoiceChip(
                        label: Text(categoryDisplay(c)),
                        selected: _category == c,
                        onSelected: (_) => setState(
                            () => _category = _category == c ? null : c),
                      ),
                    )),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 1.35,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: list.length,
              itemBuilder: (context, i) {
                final a = list[i];
                final cals = _accessoryCalibers(a);
                return Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () {
                      tapHaptic();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                AccessoryDetailScreen(item: a)),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(accessoryDisplay(a.name),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold)),
                          const Spacer(),
                          Text(
                            cals.isEmpty ? tr('generic') : cals.join(' · '),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Colors.grey, fontSize: 12),
                          ),
                        ],
                      ),
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

/// 配件详情：点卡片进来才能看到适配枪械、售价与购买渠道。
/// 入库：把配件记进本机配件库（key accessory_inventory_v1），不登录、不交易；
/// 入库按钮带按压缩放 + 已入库对勾切换动画。
class AccessoryDetailScreen extends StatefulWidget {
  final AccessoryItem item;
  const AccessoryDetailScreen({super.key, required this.item});

  @override
  State<AccessoryDetailScreen> createState() => _AccessoryDetailScreenState();
}

class _AccessoryDetailScreenState extends State<AccessoryDetailScreen> {
  static const _prefsChannel = MethodChannel('gunsmap/prefs');
  static const _prefsKey = 'accessory_inventory_v1';
  int _count = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final raw = await _prefsChannel
          .invokeMethod<String>('getString', {'key': _prefsKey})
          .timeout(const Duration(seconds: 2));
      if (raw == null || raw.isEmpty || !mounted) return;
      final list = jsonDecode(raw) as List;
      for (final e in list) {
        final m = e as Map<String, dynamic>;
        if (m['name'] == widget.item.name) {
          setState(() => _count = (m['count'] as num?)?.toInt() ?? 0);
          return;
        }
      }
    } catch (_) {}
  }

  Future<void> _add() async {
    try {
      final raw = await _prefsChannel
          .invokeMethod<String>('getString', {'key': _prefsKey})
          .timeout(const Duration(seconds: 2));
      final list = <Map<String, dynamic>>[];
      if (raw != null && raw.isNotEmpty) {
        for (final e in jsonDecode(raw) as List) {
          list.add(Map<String, dynamic>.from(e as Map));
        }
      }
      var found = false;
      for (final m in list) {
        if (m['name'] == widget.item.name) {
          m['count'] = ((m['count'] as num?)?.toInt() ?? 0) + 1;
          found = true;
        }
      }
      if (!found) {
        list.add({
          'name': widget.item.name,
          'vendor': widget.item.vendor,
          'type': widget.item.type,
          'count': 1,
        });
      }
      await _prefsChannel.invokeMethod(
          'setString', {'key': _prefsKey, 'value': jsonEncode(list)});
      if (mounted) setState(() => _count += 1);
    } catch (_) {}
    if (mounted)
      showAppToast(context, tr('acc_added_prefix') + accessoryDisplay(widget.item.name));
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final grey = dark ? const Color(0xFF8A8578) : const Color(0xFF9A917F);
    final bronze = dark ? const Color(0xFFC9A86A) : const Color(0xFF6B5B3E);
    return Scaffold(
      appBar: SubPageAppBar(title: accessoryDisplay(item.name)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(accessoryDisplay(item.name),
              style:
                  const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('${item.vendor} · ${accessoryTypeDisplay(item.type)}',
              style: TextStyle(color: grey)),
          const SizedBox(height: 12),
          Text(item.description),
          const SizedBox(height: 20),
          ScaleTap(
            onTap: _add,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Container(
                key: ValueKey(_count),
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(vertical: 13, horizontal: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFE86A1C),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                        _count > 0
                            ? Icons.check_circle_outline
                            : Icons.inventory_outlined,
                        color: Colors.white,
                        size: 20),
                    const SizedBox(width: 8),
                    Text(
                        _count > 0
                            ? tr('acc_instock_prefix') + '$_count' + tr('acc_instock_mid')
                            : tr('acc_add'),
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(tr('acc_note'),
              style: TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 20),
          Text(tr('price'), style: TextStyle(fontWeight: FontWeight.bold, color: bronze)),
          const SizedBox(height: 4),
          Text(item.price ?? tr('not_listed'),
              style: TextStyle(color: item.price == null ? grey : null)),
          const SizedBox(height: 20),
          Text(tr('channel'),
              style: TextStyle(fontWeight: FontWeight.bold, color: bronze)),
          const SizedBox(height: 4),
          Text('${item.vendor}${tr('channel_vendor_suffix')}'),
          const SizedBox(height: 20),
          Text(fitGunsText(item.fitGuns.length),
              style: TextStyle(fontWeight: FontWeight.bold, color: bronze)),
          const SizedBox(height: 4),
          if (item.fitGuns.isEmpty)
            Text(tr('generic_unbound'), style: TextStyle(color: grey)),
          if (item.fitGuns.isNotEmpty)
            Text(item.fitGuns.map(gunNameEnOf).join(', '),
                style: TextStyle(color: grey, fontSize: 13)),
        ],
      ),
    );
  }
}
