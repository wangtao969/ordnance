import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../data.dart';
import '../english_terms.dart';
import '../haptics.dart';
import '../i18n.dart';
import '../models.dart';
import '../system_actions.dart';
import '../community_store.dart';
import '../widgets/app_top_bar.dart';
import '../widgets/glass_dialog.dart';
import 'suppliers_screen.dart';
import 'load_tools_screen.dart';
import 'reload_log_screen.dart';
import 'reload_tools_screen.dart';

/// 复装页三个板块：
/// 一、子弹口径图鉴（可搜索、可按弹种分组，卡片标题直接显示关键尺寸）；
/// 二、子弹复装（只做狙击步枪常用口径，实际复装以贵价狙击弹为主）；
/// 三、入口区：组件供应商与复装记录 SOP 各进一个子页，不再用长列表挡内容。
/// 复装手册入口页：不再把口径目录与复装内容长篇平铺在本页，
/// 只留四个入口卡片，各板块点进去才是完整内容。
/// 安全红线不再占一整块内容区：进页自动弹一次毛玻璃弹窗，
/// 点“知道了”后记下来不再自动弹，顶部只留一行入口随时再点开。
/// 一、子弹口径目录：点进子页搜口径、按弹种筛选、看详情；
/// 二、子弹复装：点进工作台，按口径选弹头/火药/弹壳/底火、查手册装药、
///    选好的组件可带入复装记录，复装记录也放在这个板块里；
/// 三、组件供应商与复装工具各进一个子页。
class ReloadingScreen extends StatefulWidget {
  const ReloadingScreen({super.key});

  @override
  State<ReloadingScreen> createState() => _ReloadingScreenState();
}

class _ReloadingScreenState extends State<ReloadingScreen> {
  static const _prefsChannel = MethodChannel('gunsmap/prefs');
  static const _ackKey = 'safety_ack_v1';
  static const _warnLines = [
    '务必从起始装药开始，逐步试射并观察压力迹象，绝不超过手册最大装药。',
    '不同批次火药需重新验证，不可直接沿用旧数据。',
    '务必以纸质手册原文为准，本 App 数据仅供学习参考。',
    '装药数据按弹膛标识选用：.223 Remington 与 5.56×45mm NATO 的手册数据不可混用。',
    '本页未收录的口径与组合，均为未找到可靠公开手册出处而刻意省略，切勿自行推算补写。',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowSafety());
  }

  Future<void> _maybeShowSafety() async {
    try {
      final ack = await _prefsChannel
          .invokeMethod<String>('getString', {'key': _ackKey})
          .timeout(const Duration(seconds: 2));
      if (ack == '1') return;
    } catch (_) {}
    if (!mounted) return;
    await _showSafetyWarning(saveAck: true);
  }

  Future<void> _showSafetyWarning({required bool saveAck}) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => GlassDialog(
        title: tr('reload_safety_title'),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: _warnLines
              .map((l) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text('· $l'),
                  ))
              .toList(),
        ),
        actions: [
          glassPrimaryButton(ctx, tr('got_it'), onPressed: () async {
            if (saveAck) {
              try {
                await _prefsChannel.invokeMethod(
                    'setString', {'key': _ackKey, 'value': '1'});
              } catch (_) {}
            }
            if (ctx.mounted) Navigator.of(ctx).pop();
          }),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final grey = dark ? const Color(0xFF8A8578) : const Color(0xFF9A917F);
    return Scaffold(
      appBar: SubPageAppBar(title: tr('reload_manual_title')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => _showSafetyWarning(saveAck: false),
              icon: const Icon(Icons.warning_amber_outlined,
                  color: Colors.redAccent, size: 18),
              label: Text(tr('reload_safety_entry'),
                  style: TextStyle(color: Colors.redAccent)),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.menu_book_outlined),
              title: Text(tr('caliber_atlas')),
              subtitle: Text(
                  tr('reload_caliber_count_prefix') + '${caliberInfos.length}' + tr('reload_caliber_count_suffix'),
                  style: TextStyle(color: grey, fontSize: 12)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const CaliberCatalogScreen()),
              ),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.science_outlined),
              title: Text(tr('sniper_title')),
              subtitle: Text(tr('sniper_note'),
                  style: TextStyle(color: grey, fontSize: 12)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const ReloadWorkbenchScreen()),
              ),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.storefront_outlined),
              title: Text(tr('suppliers')),
              subtitle: Text(suppliersCountText(reloadComponents.length),
                  style: TextStyle(color: grey, fontSize: 12)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SuppliersScreen()),
              ),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.build_outlined),
              title: Text(tr('reload_tools_title')),
              subtitle: Text(tr('reload_tools_count_prefix') + '${reloadTools.length}' + tr('reload_tools_count_suffix'),
                  style: TextStyle(color: grey, fontSize: 12)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const ReloadToolsScreen()),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                '数据来源说明：本页装药数据均引自 Hornady、Speer、Nosler、Hodgdon、Vihtavuori、Lyman 等公开出版手册与官方数据页，各条标注出处；未引述的字段以“手册未载”标示；未经核实的组合一律未收录。组件与工具价格均为 2026 年 10 月美国零售参考价，随时变动，以下单时商家标价为准；未确认的以“未确认”标示。',
                style: TextStyle(color: grey, fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 子弹口径目录子页：原来平铺在复装手册页里的口径网格整个挪到这里，
/// 可搜索、可按弹种分组，卡片标题直接显示关键尺寸，点卡片进详情。
class CaliberCatalogScreen extends StatefulWidget {
  const CaliberCatalogScreen({super.key});

  @override
  State<CaliberCatalogScreen> createState() => _CaliberCatalogScreenState();
}

class _CaliberCatalogScreenState extends State<CaliberCatalogScreen> {
  String _query = '';
  String _group = '全部';

  static const _pistolCalibers = {
    '9×19mm',
    '.45 ACP',
    '.380 ACP',
    '.38 Special',
    '.357 Magnum',
    '.44 Magnum',
    '.22 LR',
  };

  static String _atlasGroup(CaliberInfo c) {
    final n = c.caliber;
    if (n.contains('霰弹')) return '霰弹';
    if (_pistolCalibers.contains(n)) return '手枪弹';
    if (n.contains('Magnum') ||
        n.contains('PRC') ||
        n.contains('CheyTac') ||
        n.contains('.50 BMG') ||
        n.contains('7mm Remington')) {
      return '马格南';
    }
    return '步枪弹';
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final grey = dark ? const Color(0xFF8A8578) : const Color(0xFF9A917F);
    final q = _query.trim().toLowerCase();
    final atlas = caliberInfos.where((c) {
      if (_group != '全部' && _atlasGroup(c) != _group) return false;
      if (q.isEmpty) return true;
      if (c.caliber.toLowerCase().contains(q)) return true;
      return c.bullets.any((b) =>
          b.toLowerCase().contains(q) ||
          bulletDisplay(b).toLowerCase().contains(q));
    }).toList();
    return Scaffold(
      appBar: SubPageAppBar(title: tr('caliber_atlas')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Text(tr('atlas_note'),
              style: TextStyle(color: grey, fontSize: 12)),
          const SizedBox(height: 8),
          TextField(
            decoration: InputDecoration(
              hintText: tr('search_caliber_hint'),
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => setState(() => _query = ''),
                    ),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24)),
              // 聚焦边与未聚焦同一支（圆角 24 灰边）：只写 border 时聚焦
              // 会回落全局橙色圆角 12 边。
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(
                      color: Colors.grey.withValues(alpha: 0.35))),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(
                      color: Colors.grey.withValues(alpha: 0.35))),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            onChanged: (v) => setState(() => _query = v),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            children: ['全部', '手枪弹', '步枪弹', '马格南', '霰弹']
                .map((g) => FilterChip(
                      label: Text(g == '全部' ? tr('all') : caliberGroupDisplay(g)),
                      selected: _group == g,
                      onSelected: (_) => setState(() => _group = g),
                    ))
                .toList(),
          ),
          const SizedBox(height: 4),
          Text(atlasCountText(atlas.length),
              style: TextStyle(color: grey, fontSize: 12)),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 0.92,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: atlas.length,
            itemBuilder: (context, i) {
              final c = atlas[i];
              return Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    tapHaptic();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => CaliberDetailScreen(info: c)),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(c.caliber,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 13)),
                        const Spacer(),
                        Text('Bullet ${c.bulletDiameter}',
                            style: TextStyle(color: grey, fontSize: 11)),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// 子弹复装工作台：一个口径的复装信息集中在一页——
/// 手册建议组件（弹头/弹壳/火药/底火）、组件库选择、该口径的手册装药、
/// 手册参考（点开出版社官网查验，App 内不附手册全文）、复装记录入口。
/// 选好的组件可带入复装记录，记录里的字段不再从零手打。
class ReloadWorkbenchScreen extends StatefulWidget {
  const ReloadWorkbenchScreen({super.key});

  @override
  State<ReloadWorkbenchScreen> createState() => _ReloadWorkbenchScreenState();
}

class _ReloadWorkbenchScreenState extends State<ReloadWorkbenchScreen> {
  static const _logPrefsChannel = MethodChannel('gunsmap/prefs');
  static const _logPrefsKey = 'reload_log_v1';
  List<ReloadLogEntry> _pastLogs = [];
  String? _caliber;
  String _libQuery = '';
  String _libKind = '弹头';
  bool _libShowAll = false;
  // 已选组件：kind -> 展示串（厂商 + 型号）。
  final Map<String, String> _picked = {};

  @override
  void initState() {
    super.initState();
    _loadPastLogs();
  }

  /// 读本机复装记录（只读，用于“我的配方”复用与未放行提醒，不改写）。
  Future<void> _loadPastLogs() async {
    try {
      final raw = await _logPrefsChannel
          .invokeMethod<String>('getString', {'key': _logPrefsKey})
          .timeout(const Duration(seconds: 2));
      if (raw == null || raw.isEmpty || !mounted) return;
      final list = (jsonDecode(raw) as List)
          .map((e) => ReloadLogEntry.fromJson(e as Map<String, dynamic>))
          .toList();
      setState(() => _pastLogs = list);
    } catch (_) {}
  }

  // 手册名 -> 出版社官网（只链官网首页，具体章节以纸质手册与官网数据页为准）。
  static const _manualSites = {
    'Hornady': 'https://www.hornady.com',
    'Speer': 'https://www.speer.com',
    'Hodgdon': 'https://www.hodgdon.com',
    'Nosler': 'https://www.nosler.com',
    'Barnes': 'https://www.barnesbullets.com',
    'Vihtavuori': 'https://www.vihtavuori.com',
    'Lyman': 'https://www.lymanproducts.com',
  };

  String? _manualSite(String manual) {
    for (final e in _manualSites.entries) {
      if (manual.contains(e.key)) return e.value;
    }
    return null;
  }

  /// 组件库条目是否与已选口径相关：弹头按弹径、火药按手册列出该口径
  /// 或出现在本口径建议/装药里、弹壳按壳名、底火按级别与型号。
  /// 建议里补一个型号，过滤结果里就多一个型号，不用另改过滤逻辑。
  bool _libRelevant(ReloadComponent c, String caliber) {
    final identity = '${c.vendor} ${c.name}';
    final entry =
        reloadCalibers.where((e) => e.caliber == caliber).toList();
    final suggestions = entry.isEmpty
        ? const <String>[]
        : [
            ...entry.first.bullets,
            ...entry.first.cases,
            ...entry.first.powders,
            ...entry.first.primers,
          ];
    if (suggestions.any((s) => s.contains(c.name))) return true;
    if (reloadLoads.any((l) =>
        l.caliber == caliber &&
        (l.powder == identity || l.primer == identity))) {
      return true;
    }
    final hay = '${c.name} ${c.spec}';
    switch (c.kind) {
      case '弹头':
        final token = _bulletToken(caliber);
        return token != null && hay.contains(token);
      case '火药':
        final token = _powderToken(caliber);
        return token != null && c.spec.contains(token);
      case '弹壳':
        return _caseTokens(caliber).any(hay.contains);
      case '底火':
        final token = _primerToken(caliber);
        return token != null && c.spec.contains(token);
      default:
        return false;
    }
  }

  String? _bulletToken(String caliber) {
    switch (caliber) {
      case '9×19mm':
        return '9×19mm';
      case '.223 Remington':
      case '5.56×45mm':
        return '.223 / 5.56';
      case '.308 Winchester':
      case '.300 Winchester Magnum':
      case '.300 PRC':
        return '.308';
      case '.45 ACP':
        return '.45 ACP';
      case '6.5 Creedmoor':
        return '6.5mm';
      case '.338 Lapua Magnum':
      case '.338 Norma Magnum':
        return '.338';
      default:
        // 12 号霰弹与 .50 BMG：库里暂无对应弹头，过滤结果为空并明示。
        return null;
    }
  }

  String? _powderToken(String caliber) {
    switch (caliber) {
      case '9×19mm':
        return '9×19mm';
      case '.223 Remington':
        return '.223 Rem';
      case '5.56×45mm':
        return '5.56';
      case '.308 Winchester':
        return '.308 Win';
      case '.45 ACP':
        return '.45 ACP';
      case '12号霰弹':
        return '霰弹';
      case '6.5 Creedmoor':
        return '6.5 Creedmoor';
      case '.300 Winchester Magnum':
        return '.300 Win Mag';
      case '.338 Lapua Magnum':
        return '.338 Lapua';
      case '.300 PRC':
        return '.300 PRC';
      case '.50 BMG':
        return '.50 BMG';
      case '.338 Norma Magnum':
        return '.338 Norma';
      default:
        return null;
    }
  }

  List<String> _caseTokens(String caliber) {
    switch (caliber) {
      case '9×19mm':
        return ['9×19mm'];
      case '.223 Remington':
        return ['.223 Rem'];
      case '5.56×45mm':
        return ['5.56', '.223 Rem'];
      case '.308 Winchester':
        return ['.308 Win'];
      case '.45 ACP':
        return ['.45 ACP'];
      case '12号霰弹':
        return ['12 号'];
      case '6.5 Creedmoor':
        return ['6.5 Creedmoor'];
      case '.300 Winchester Magnum':
        return ['.300 Win Mag'];
      case '.338 Lapua Magnum':
        return ['.338 Lapua'];
      case '.300 PRC':
        return ['.300 PRC'];
      case '.50 BMG':
        return ['.50 BMG'];
      case '.338 Norma Magnum':
        return ['.338 Norma'];
      default:
        return [];
    }
  }

  String? _primerToken(String caliber) {
    final entry =
        reloadCalibers.where((e) => e.caliber == caliber).toList();
    if (entry.isEmpty) return null;
    final joined = entry.first.primers.join(' ');
    if (joined.contains('霰弹')) return '霰弹';
    if (joined.contains('小号手枪')) return '小型手枪';
    if (joined.contains('小号步枪')) return '小型步枪';
    if (joined.contains('大号手枪')) return '大型手枪';
    if (joined.contains('大号步枪')) return '大型步枪';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final grey = dark ? const Color(0xFF8A8578) : const Color(0xFF9A917F);
    final bronze = dark ? const Color(0xFFC9A86A) : const Color(0xFF6B5B3E);
    final _caliberMatches = _caliber == null
        ? <ReloadCaliber>[]
        : reloadCalibers.where((c) => c.caliber == _caliber).toList();
    final caliberEntry =
        _caliberMatches.isEmpty ? null : _caliberMatches.first;
    final loads = _caliber == null
        ? <ReloadLoad>[]
        : reloadLoads.where((l) => l.caliber == _caliber).toList();
    final manuals = <String>{};
    for (final l in reloadLoads) {
      if (l.manual.isNotEmpty) manuals.add(l.manual);
    }
    final libQ = _libQuery.trim().toLowerCase();
    final libFiltered = reloadComponents.where((c) {
      if (c.kind != _libKind) return false;
      if (_caliber != null && !_libShowAll) {
        return _libRelevant(c, _caliber!);
      }
      return true;
    }).toList();
    final libMatches = libFiltered.where((c) {
      if (libQ.isEmpty) return true;
      return ('${c.vendor} ${c.name} ${c.spec}')
          .toLowerCase()
          .contains(libQ);
    }).toList();
    return Scaffold(
      appBar: SubPageAppBar(title: tr('sniper_title')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(tr('reload_workbench_hint'),
              style: TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _caliber,
            decoration: InputDecoration(
              labelText: tr('reload_caliber_field'),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12))),
            ),
            items: reloadCalibers
                .map((c) => DropdownMenuItem(
                    value: c.caliber, child: Text(c.caliber)))
                .toList(),
            onChanged: (v) => setState(() {
              _caliber = v;
              _libShowAll = false;
            }),
          ),
          if (caliberEntry != null) ...[
            const SizedBox(height: 16),
            Text(tr('reload_suggested'),
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _section('Bullet Selection',
                caliberEntry.bullets.map(shotPelletDisplay).toList(), bronze),
            _section('Case Selection',
                caliberEntry.cases.map(caseDisplay).toList(), bronze),
            _section('Powder Selection', caliberEntry.powders, bronze),
            _section('Primer Selection',
                caliberEntry.primers.map(primerDisplay).toList(), bronze),
            const SizedBox(height: 8),
            Text(tr('reload_manual_loads'),
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (loads.isEmpty)
              Text(tr('reload_no_manual_data'),
                  style: TextStyle(color: grey)),
            ...loads.map((l) => _loadCard(l)),
          ],
          const SizedBox(height: 16),
          Text(
              _caliber == null
                  ? tr('reload_lib_title') + tr('reload_lib_title_open') + '${reloadComponents.length}' + tr('reload_lib_title_mid')
                  : _libShowAll
                      ? tr('reload_lib_title') + tr('reload_lib_title_open') + tr('reload_lib_title_all') + '${reloadComponents.length}' + tr('reload_lib_title_mid')
                      : tr('reload_lib_title') + tr('reload_lib_title_open') + tr('reload_lib_title_rel_a') + '$_caliber' + tr('reload_lib_title_rel_b') + '${libFiltered.length}' + tr('reload_lib_title_mid'),
              style: const TextStyle(
                  fontSize: 17, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(
              _caliber == null
                  ? tr('reload_lib_hint_pick')
                  : _libShowAll
                      ? tr('reload_lib_hint_all')
                      : tr('reload_lib_hint_rel_a') + '$_caliber' + tr('reload_lib_hint_rel_b'),
              style: TextStyle(color: grey, fontSize: 12)),
          if (_caliber != null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: FilterChip(
                label: Text(tr('reload_only_caliber')),
                selected: !_libShowAll,
                onSelected: (v) => setState(() => _libShowAll = !v),
              ),
            ),
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            children: ['弹头', '火药', '弹壳', '底火']
                .map((k) => FilterChip(
                      label: Text(componentKindDisplay(k)),
                      selected: _libKind == k,
                      onSelected: (_) => setState(() => _libKind = k),
                    ))
                .toList(),
          ),
          const SizedBox(height: 8),
          TextField(
            decoration: InputDecoration(
              hintText: tr('reload_lib_search_hint'),
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24)),
              // 聚焦边与未聚焦同一支（圆角 24 灰边）：只写 border 时聚焦
              // 会回落全局橙色圆角 12 边。
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(
                      color: Colors.grey.withValues(alpha: 0.35))),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(
                      color: Colors.grey.withValues(alpha: 0.35))),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            onChanged: (v) => setState(() => _libQuery = v),
          ),
          const SizedBox(height: 8),
          ...libMatches.take(20).map((c) => Card(
                margin: const EdgeInsets.only(bottom: 6),
                child: ListTile(
                  title: Text('${c.vendor} ${c.name}'),
                  subtitle: Text(c.spec,
                      style: TextStyle(color: grey, fontSize: 12)),
                  trailing: (_picked[_libKind] ?? '')
                          .startsWith('${c.vendor} ${c.name}')
                      ? const Icon(Icons.check_circle,
                          color: Color(0xFFE86A1C))
                      : null,
                  onTap: () {
                    var picked = '${c.vendor} ${c.name}';
                    if (_libKind == '弹头') {
                      final w =
                          RegExp(r'(\d+)gr').firstMatch(c.spec)?.group(1);
                      if (w != null) picked = '$picked ${w}gr';
                    }
                    setState(() => _picked[_libKind] = picked);
                  },
                ),
              )),
          if (libMatches.length > 20)
            Text(tr('reload_lib_more_prefix') + '${libMatches.length - 20}' + tr('reload_lib_more_suffix'),
                style: TextStyle(color: grey, fontSize: 12)),
          if (libFiltered.isEmpty)
            Text(
                tr('reload_lib_no_match_prefix') + componentKindDisplay(_libKind) + tr('reload_lib_no_match_suffix'),
                style: TextStyle(color: grey, fontSize: 12)),
          const SizedBox(height: 16),
          Card(
            color: dark
                ? const Color(0xFF0D0D0D)
                : const Color(0xFFF3E9D8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tr('reload_picked_title'),
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('Bullet: ${_picked['弹头'] ?? tr('reload_not_picked')}'),
                  Text('Powder: ${_picked['火药'] ?? tr('reload_not_picked')}'),
                  Text('Case: ${_picked['弹壳'] ?? tr('reload_not_picked')}'),
                  Text('Primer: ${_picked['底火'] ?? tr('reload_not_picked')}'),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ReloadLogScreen(
                            initialBullet: _picked['弹头'],
                            initialPowder: _picked['火药'],
                            initialPrimer: _picked['底火'],
                            initialCase: _picked['弹壳'],
                            initialCaliber: _caliber,
                          ),
                        ),
                      ),
                      child: Text(tr('reload_carry_btn')),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(tr('reload_log_hint'),
                      style: TextStyle(color: grey, fontSize: 12)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(tr('reload_recipes_title'),
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(tr('reload_recipes_hint'),
              style: TextStyle(color: grey, fontSize: 12)),
          const SizedBox(height: 8),
          if (_pastLogs.where((l) => l.released).isEmpty)
            Text(tr('reload_no_recipes'),
                style: TextStyle(color: grey)),
          ...(() {
            final seen = <String>{};
            final recipes = <ReloadLogEntry>[];
            for (final l in _pastLogs.where((l) => l.released)) {
              final key =
                  '${l.caliber}|${l.bullet}|${l.powder}|${l.charge}|${l.col}';
              if (seen.add(key)) recipes.add(l);
            }
            return recipes.take(8).map((l) {
              // 闭环：该配方的全部批次号 → 关联了这些批次的成绩里取最好分组。
              final recipeKey =
                  '${l.caliber}|${l.bullet}|${l.powder}|${l.charge}|${l.col}';
              final batchNos = _pastLogs
                  .where((e) =>
                      e.released &&
                      '${e.caliber}|${e.bullet}|${e.powder}|${e.charge}|${e.col}' ==
                          recipeKey)
                  .map((e) => e.batchNo)
                  .where((b) => b.isNotEmpty)
                  .toSet();
              final linked = (communityStore.current?.rangeScores ?? [])
                  .where((sc) =>
                      batchNos.contains(sc.batchNo) && sc.groupSize > 0)
                  .toList();
              RangeScore? best;
              for (final sc in linked) {
                if (best == null || sc.groupSize < best.groupSize) best = sc;
              }
              final bestLine = best == null
                  ? ''
                  : '\n' + tr('reload_best_group_prefix') + '${best.groupSize.toStringAsFixed(1)}' + tr('range_unit_cm') + tr('reload_best_group_mid') + '${best.distance > 0 ? (best.groupSize / (best.distance * 0.02909)).toStringAsFixed(2) : '—'}' + tr('reload_best_group_mid2') + '${best.distance}' + tr('range_unit_m') + tr('reload_best_group_suffix');
              return Card(
                  margin: const EdgeInsets.only(bottom: 6),
                  child: ListTile(
                    title: Text('${l.caliber} · ${l.bullet}'),
                    subtitle: Text(
                        '${l.powder} ${l.charge}gr · COL ${l.col}″ · ${l.date}$bestLine',
                        style: TextStyle(color: grey, fontSize: 12)),
                    trailing: const Icon(Icons.replay, size: 20),
                    onTap: () => setState(() {
                      _caliber = l.caliber;
                      _picked['弹头'] = l.bullet;
                      _picked['火药'] = l.powder;
                      _picked['弹壳'] = l.caseBrand;
                      _picked['底火'] = l.primer;
                    }),
                  ),
                );
            });
          })(),
          if (_pastLogs.any((l) => !l.released)) ...[
            const SizedBox(height: 8),
            Text(
                tr('reload_unreleased_prefix') + '${_pastLogs.where((l) => !l.released).length}' + tr('reload_unreleased_suffix'),
                style: const TextStyle(color: Colors.amber, fontSize: 12)),
          ],
          const SizedBox(height: 16),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: Text('${tr('reload_manual_ref')} (${manuals.length})',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            children: [
              Text(tr('reload_manual_ref_note'),
                  style: TextStyle(color: grey, fontSize: 12)),
              const SizedBox(height: 8),
              ...manuals.map((m) {
            final site = _manualSite(m);
            return Card(
              margin: const EdgeInsets.only(bottom: 6),
              child: ListTile(
                leading: const Icon(Icons.menu_book_outlined),
                title: Text(m),
                trailing: site == null
                    ? null
                    : const Icon(Icons.open_in_new, size: 18),
                onTap: site == null
                    ? null
                    : () async {
                        await openSystemUrl(site);
                      },
              ),
            );
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _section(String title, List<String> items, Color bronze) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: TextStyle(fontWeight: FontWeight.bold, color: bronze)),
            ...items.map((e) => Padding(
                  padding: const EdgeInsets.only(top: 2, left: 8),
                  child: Text('· $e'),
                )),
          ],
        ),
      );

  Widget _loadCard(ReloadLoad l) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${l.bullet} · ${l.powder}',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              _loadRow(tr('reload_row_start'), l.startCharge),
              _loadRow(tr('reload_row_max'), l.maxCharge),
              _loadRow(tr('reload_row_col'), l.col),
              _loadRow(tr('reload_row_primer'), l.primer),
              _loadRow(tr('reload_row_brass'), l.brass),
              if (l.velocity != null) _loadRow(tr('reload_row_velocity'), l.velocity!),
              if (l.pressure != null) _loadRow(tr('reload_row_pressure'), l.pressure!),
              if (l.manual.isNotEmpty) _ManualSourceRow(manual: l.manual),
              const SizedBox(height: 4),
              Text('${tr('source_prefix')}${l.source}',
                  style: const TextStyle(color: Colors.grey, fontSize: 12)),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => LoadToolsScreen(
                        initialBulletGr: _grOf(l.bullet),
                        initialVelocityFps: _firstNum(l.velocity),
                        initialPowderGr: _grOf(l.startCharge),
                        initialLabel:
                            '${l.caliber} · ${l.bullet} · ${l.powder}' + tr('reload_start_charge_suffix'),
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.calculate_outlined, size: 18),
                  label: Text(tr('reload_calc_energy')),
                ),
              ),
            ],
          ),
        ),
      );

  /// 从“124gr”“4.0gr”这类串里取克令数；初速取区间里的起始值，
  /// 与起始装药配对，不拿最大值去算。
  double? _grOf(String s) {
    final m = RegExp(r'(\d+(?:\.\d+)?)\s*gr').firstMatch(s);
    return m == null ? null : double.tryParse(m.group(1)!);
  }

  double? _firstNum(String? s) {
    if (s == null) return null;
    final m = RegExp(r'(\d+(?:\.\d+)?)').firstMatch(s);
    return m == null ? null : double.tryParse(m.group(1)!);
  }

  Widget _loadRow(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 1),
        child: Row(
          children: [
            SizedBox(
                width: 72,
                child: Text(k, style: const TextStyle(color: Colors.grey))),
            Expanded(child: Text(v)),
          ],
        ),
      );
}

/// 装药卡手册来源收起行：默认只显示一行“手册来源”+ 展开箭头，
/// 点开才显示完整手册引用，免得每张卡都摊一行长引用。
class _ManualSourceRow extends StatefulWidget {
  final String manual;
  const _ManualSourceRow({required this.manual});

  @override
  State<_ManualSourceRow> createState() => _ManualSourceRowState();
}

class _ManualSourceRowState extends State<_ManualSourceRow> {
  var _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 1),
            child: Row(
              children: [
                SizedBox(
                    width: 72,
                    child: Text(tr('reload_manual_source'),
                        style: const TextStyle(color: Colors.grey))),
                const Spacer(),
                Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    size: 18,
                    color: Colors.grey),
              ],
            ),
          ),
        ),
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: Padding(
            padding: const EdgeInsets.only(left: 72, top: 2, bottom: 2),
            child: Text(widget.manual),
          ),
          crossFadeState: _expanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 200),
        ),
      ],
    );
  }
}

/// 口径详情：点三列小卡片进来，尺寸、弹头、售价、适配枪械都在这里。
class CaliberDetailScreen extends StatelessWidget {
  final CaliberInfo info;
  const CaliberDetailScreen({super.key, required this.info});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final grey = dark ? const Color(0xFF8A8578) : const Color(0xFF9A917F);
    final bronze = dark ? const Color(0xFFC9A86A) : const Color(0xFF6B5B3E);
    return Scaffold(
      appBar: SubPageAppBar(title: info.caliber),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(info.caliber,
              style:
                  const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          _detailRow('Bullet Diameter', info.bulletDiameter),
          _detailRow('Case Length', info.caseLength),
          _detailRow('Max OAL', info.maxOal),
          _detailRow('Common Bullet Weight', info.bulletWeightRange),
          _detailRow('Use', info.use),
          const SizedBox(height: 16),
          Text(tr('factory_price'),
              style: TextStyle(fontWeight: FontWeight.bold, color: bronze)),
          const SizedBox(height: 4),
          Text(info.factoryPrice ?? tr('reload_price_missing'),
              style: TextStyle(color: info.factoryPrice == null ? grey : null)),
          Text(tr('factory_price_note'),
              style: TextStyle(color: grey, fontSize: 12)),
          if (info.bullets.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(bulletsText(info.bullets.length),
                style: TextStyle(fontWeight: FontWeight.bold, color: bronze)),
            const SizedBox(height: 4),
            ...info.bullets.map((b) => Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text('· ${bulletDisplay(b)}',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                )),
          ],
          const SizedBox(height: 16),
          Text(fitGunsText(info.fitGuns.length),
              style: TextStyle(fontWeight: FontWeight.bold, color: bronze)),
          const SizedBox(height: 4),
          if (info.fitGuns.isEmpty)
            Text(tr('no_guns_for_caliber'),
                style: TextStyle(color: grey)),
          if (info.fitGuns.isNotEmpty)
            Text(info.fitGuns.map(gunNameEnOf).join(', '),
                style: TextStyle(color: grey, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _detailRow(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
                width: 80,
                child: Text(k, style: const TextStyle(color: Colors.grey))),
            Expanded(child: Text(v)),
          ],
        ),
      );
}
