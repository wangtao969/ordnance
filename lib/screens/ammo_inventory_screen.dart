import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../data.dart';
import '../i18n.dart';
import '../widgets/app_top_bar.dart';
import '../widgets/app_toast.dart';
import '../widgets/time_line_chart.dart';
import 'reload_log_screen.dart';

/// 弹药库存：工具向，不用登录，纯本机记录。
/// 经 gunsmap/prefs 存本机（key ammo_inventory_v1），重启不丢。
/// 只记你手头的弹药现存发数，不卖弹药、不做任何交易。
/// 价格区按口径记每发单价（用户自填数字，不假设货币），改价留记录；
/// 库存与价格曲线都用折线图，库存曲线由出入库记录重建。
///
/// 按射手用弹流程设计：
/// - 买是按盒买的：每种弹记每盒发数，现存显示成“盒 + 散”；
/// - 消耗发生在靶场：每行有打靶消耗与盘点，变动都留记录；
/// - 复装弹与厂弹分开：复装弹带复装记录的批次号，可从放行记录一键入库；
/// - 快打完要一眼看到：低于自设提醒线标红。
/// 旧版只有口径/名称/发数/备注四个字段，旧数据照常读，新字段给默认值。
class AmmoItem {
  String caliber;
  String name;
  int quantity;
  String note;
  String kind;
  int roundsPerBox;
  int lowAt;
  String location;
  String batchNo;
  AmmoItem(
      {required this.caliber,
      required this.name,
      required this.quantity,
      this.note = '',
      this.kind = '厂弹',
      this.roundsPerBox = 50,
      this.lowAt = -1,
      this.location = '',
      this.batchNo = ''});

  Map<String, dynamic> toJson() => {
        'caliber': caliber,
        'name': name,
        'quantity': quantity,
        'note': note,
        'kind': kind,
        'roundsPerBox': roundsPerBox,
        'lowAt': lowAt,
        'location': location,
        'batchNo': batchNo,
      };

  factory AmmoItem.fromJson(Map<String, dynamic> j) => AmmoItem(
        caliber: j['caliber'] as String? ?? '',
        name: j['name'] as String? ?? '',
        quantity: (j['quantity'] as num?)?.toInt() ?? 0,
        note: j['note'] as String? ?? '',
        kind: j['kind'] as String? ?? '厂弹',
        roundsPerBox: (j['roundsPerBox'] as num?)?.toInt() ?? 50,
        lowAt: (j['lowAt'] as num?)?.toInt() ?? -1,
        location: j['location'] as String? ?? '',
        batchNo: j['batchNo'] as String? ?? '',
      );

  bool get isLow => lowAt >= 0 && quantity < lowAt;

  String get stockText {
    if (roundsPerBox > 0 && quantity >= roundsPerBox) {
      final boxes = quantity ~/ roundsPerBox;
      final loose = quantity % roundsPerBox;
      return loose == 0
          ? tr('ammo_stock_prefix') + '$quantity' + tr('ammo_stock_rounds') + tr('ammo_stock_boxes_prefix') + '$boxes' + tr('ammo_stock_boxes_unit') + tr('ammo_stock_close')
          : tr('ammo_stock_prefix') + '$quantity' + tr('ammo_stock_rounds') + tr('ammo_stock_boxes_prefix') + '$boxes' + tr('ammo_stock_boxes_unit') + ' + $loose' + tr('ammo_stock_rounds') + tr('ammo_stock_close');
    }
    return tr('ammo_stock_prefix') + '$quantity' + tr('ammo_stock_rounds');
  }
}

/// 变动记录：日期、弹药、变化发数、原因（买入/消耗/打靶/复装入库/盘点）。
class AmmoMovement {
  String date;
  String name;
  String caliber;
  int delta;
  String reason;
  AmmoMovement(
      {required this.date,
      required this.name,
      required this.caliber,
      required this.delta,
      required this.reason});

  Map<String, dynamic> toJson() => {
        'date': date,
        'name': name,
        'caliber': caliber,
        'delta': delta,
        'reason': reason,
      };

  factory AmmoMovement.fromJson(Map<String, dynamic> j) => AmmoMovement(
        date: j['date'] as String? ?? '',
        name: j['name'] as String? ?? '',
        caliber: j['caliber'] as String? ?? '',
        delta: (j['delta'] as num?)?.toInt() ?? 0,
        reason: j['reason'] as String? ?? '',
      );
}

const _ammoPrefsChannel = MethodChannel('gunsmap/prefs');
const _ammoItemsKey = 'ammo_inventory_v1';
const _ammoMovementsKey = 'ammo_movements_v1';

Future<List<AmmoItem>> loadAmmoItems() async {
  try {
    final raw = await _ammoPrefsChannel
        .invokeMethod<String>('getString', {'key': _ammoItemsKey})
        .timeout(const Duration(seconds: 2));
    if (raw == null || raw.isEmpty) return [];
    return (jsonDecode(raw) as List)
        .map((e) => AmmoItem.fromJson(e as Map<String, dynamic>))
        .toList();
  } catch (_) {
    return [];
  }
}

Future<void> saveAmmoItems(List<AmmoItem> items) async {
  try {
    await _ammoPrefsChannel.invokeMethod('setString', {
      'key': _ammoItemsKey,
      'value': jsonEncode(items.map((e) => e.toJson()).toList()),
    });
  } catch (_) {}
}

Future<List<AmmoMovement>> loadAmmoMovements() async {
  try {
    final raw = await _ammoPrefsChannel
        .invokeMethod<String>('getString', {'key': _ammoMovementsKey})
        .timeout(const Duration(seconds: 2));
    if (raw == null || raw.isEmpty) return [];
    return (jsonDecode(raw) as List)
        .map((e) => AmmoMovement.fromJson(e as Map<String, dynamic>))
        .toList();
  } catch (_) {
    return [];
  }
}

Future<void> addAmmoMovement(AmmoMovement m) async {
  final list = await loadAmmoMovements();
  list.insert(0, m);
  if (list.length > 200) list.removeRange(200, list.length);
  try {
    await _ammoPrefsChannel.invokeMethod('setString', {
      'key': _ammoMovementsKey,
      'value': jsonEncode(list.map((e) => e.toJson()).toList()),
    });
  } catch (_) {}
}

/// 口径单价记录：日期、口径、每发单价（用户自填数字，不假设货币）；
/// 改价时追加一条，价格曲线由此生成。
class AmmoPricePoint {
  String date;
  String caliber;
  double price;
  AmmoPricePoint(
      {required this.date, required this.caliber, required this.price});

  Map<String, dynamic> toJson() =>
      {'date': date, 'caliber': caliber, 'price': price};

  factory AmmoPricePoint.fromJson(Map<String, dynamic> j) => AmmoPricePoint(
        date: j['date'] as String? ?? '',
        caliber: j['caliber'] as String? ?? '',
        price: (j['price'] as num?)?.toDouble() ?? 0,
      );
}

const _ammoPricesKey = 'ammo_prices_v1';
const _ammoPriceHistoryKey = 'ammo_price_history_v1';

Future<Map<String, double>> loadAmmoPrices() async {
  try {
    final raw = await _ammoPrefsChannel
        .invokeMethod<String>('getString', {'key': _ammoPricesKey})
        .timeout(const Duration(seconds: 2));
    if (raw == null || raw.isEmpty) return {};
    final m = jsonDecode(raw) as Map<String, dynamic>;
    return m.map((k, v) => MapEntry(k, (v as num).toDouble()));
  } catch (_) {
    return {};
  }
}

Future<void> saveAmmoPrices(Map<String, double> prices) async {
  try {
    await _ammoPrefsChannel.invokeMethod('setString', {
      'key': _ammoPricesKey,
      'value': jsonEncode(prices),
    });
  } catch (_) {}
}

Future<List<AmmoPricePoint>> loadAmmoPriceHistory() async {
  try {
    final raw = await _ammoPrefsChannel
        .invokeMethod<String>('getString', {'key': _ammoPriceHistoryKey})
        .timeout(const Duration(seconds: 2));
    if (raw == null || raw.isEmpty) return [];
    return (jsonDecode(raw) as List)
        .map((e) => AmmoPricePoint.fromJson(e as Map<String, dynamic>))
        .toList();
  } catch (_) {
    return [];
  }
}

Future<void> saveAmmoPriceHistory(List<AmmoPricePoint> points) async {
  try {
    await _ammoPrefsChannel.invokeMethod('setString', {
      'key': _ammoPriceHistoryKey,
      'value': jsonEncode(points.map((e) => e.toJson()).toList()),
    });
  } catch (_) {}
}

String _today() {
  final now = DateTime.now();
  return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
}

class AmmoInventoryScreen extends StatefulWidget {
  const AmmoInventoryScreen({super.key});

  @override
  State<AmmoInventoryScreen> createState() => _AmmoInventoryScreenState();
}

class _AmmoInventoryScreenState extends State<AmmoInventoryScreen> {
  static const _manualCaliber = '__manual__';
  final _items = <AmmoItem>[];
  final _movements = <AmmoMovement>[];
  final _caliberManualCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final _boxCtrl = TextEditingController(text: '50');
  final _lowCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _batchCtrl = TextEditingController();
  String _caliber = _manualCaliber;
  String _kind = '厂弹';
  final _prices = <String, double>{};
  final _priceHistory = <AmmoPricePoint>[];
  String _chartMode = 'stock';
  final _priceCtrl = TextEditingController();
  String _priceCaliber = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _caliberManualCtrl.dispose();
    _nameCtrl.dispose();
    _qtyCtrl.dispose();
    _noteCtrl.dispose();
    _boxCtrl.dispose();
    _lowCtrl.dispose();
    _locationCtrl.dispose();
    _batchCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final items = await loadAmmoItems();
    final movements = await loadAmmoMovements();
    final prices = await loadAmmoPrices();
    final history = await loadAmmoPriceHistory();
    if (!mounted) return;
    setState(() {
      _items
        ..clear()
        ..addAll(items);
      _movements
        ..clear()
        ..addAll(movements);
      _prices
        ..clear()
        ..addAll(prices);
      _priceHistory
        ..clear()
        ..addAll(history);
    });
  }

  void _save() => saveAmmoItems(_items);

  String get _resolvedCaliber {
    if (_caliber != _manualCaliber) return _caliber;
    return _caliberManualCtrl.text.trim();
  }

  /// 口径图鉴里的常用弹：点一下即填入弹药名，不用手打。
  List<String> _bulletChips(String caliber) {
    for (final c in caliberInfos) {
      if (c.caliber == caliber) return c.bullets;
    }
    return const [];
  }

  void _add() {
    final caliber = _resolvedCaliber;
    final name = _nameCtrl.text.trim();
    final qty = int.tryParse(_qtyCtrl.text.trim()) ?? 0;
    if (caliber.isEmpty || name.isEmpty) return;
    final box = int.tryParse(_boxCtrl.text.trim()) ?? 50;
    final low = int.tryParse(_lowCtrl.text.trim()) ?? -1;
    setState(() {
      _items.add(AmmoItem(
          caliber: caliber,
          name: name,
          quantity: qty < 0 ? 0 : qty,
          note: _noteCtrl.text.trim(),
          kind: _kind,
          roundsPerBox: box < 0 ? 0 : box,
          lowAt: low,
          location: _locationCtrl.text.trim(),
          batchNo: _kind == '复装' ? _batchCtrl.text.trim() : ''));
      _nameCtrl.clear();
      _qtyCtrl.clear();
      _noteCtrl.clear();
      _lowCtrl.clear();
      _locationCtrl.clear();
      _batchCtrl.clear();
    });
    _save();
  }

  void _bump(AmmoItem item, int delta, String reason) {
    final next = (item.quantity + delta).clamp(0, 100000000);
    final actual = next - item.quantity;
    if (actual == 0) return;
    setState(() => item.quantity = next);
    _save();
    _log(item, actual, reason);
  }

  /// 库存品类显示（含第 5 项新增的 4 个组件品类）。
  String _kindLabel(String k) {
    switch (k) {
      case '复装':
        return tr('ammo_kind_reload');
      case '弹头':
        return tr('ammo_kind_bullet');
      case '火药':
        return tr('ammo_kind_powder');
      case '弹壳':
        return tr('ammo_kind_case');
      case '底火':
        return tr('ammo_kind_primer');
      default:
        return tr('ammo_kind_factory');
    }
  }

  /// 已有条目改阈值（第 5 项④）：录入时填过的也可事后改。
  Future<void> _editLowDialog(AmmoItem item) async {
    final ctrl = TextEditingController(
        text: item.lowAt >= 0 ? '${item.lowAt}' : '');
    final v = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('ammo_set_low')),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          decoration:
              InputDecoration(labelText: tr('ammo_low_label')),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(tr('cancel'))),
          TextButton(
              onPressed: () =>
                  Navigator.pop(ctx, int.tryParse(ctrl.text.trim())),
              child: Text(tr('confirm'))),
        ],
      ),
    );
    if (v == null) return;
    setState(() => item.lowAt = v < 0 ? -1 : v);
    _save();
    showAppToast(context, tr('ammo_low_set'));
  }

  String _reasonLabel(String reason) {
    switch (reason) {
      case '买入':
        return tr('ammo_reason_buy');
      case '消耗':
        return tr('ammo_reason_use');
      case '打靶':
        return tr('ammo_reason_shoot');
      case '盘点':
        return tr('ammo_reason_count');
      case '复装入库':
        return tr('ammo_reason_reload_in');
      case '复装消耗':
        return tr('ammo_reason_reload_use');
      default:
        return reason;
    }
  }

  void _log(AmmoItem item, int delta, String reason) {
    final m = AmmoMovement(
        date: _today(),
        name: item.name,
        caliber: item.caliber,
        delta: delta,
        reason: reason);
    setState(() {
      _movements.insert(0, m);
      if (_movements.length > 200) {
        _movements.removeRange(200, _movements.length);
      }
    });
    addAmmoMovement(m);
  }

  void _setPrice(String caliber, double price) {
    final old = _prices[caliber];
    setState(() => _prices[caliber] = price);
    saveAmmoPrices(_prices);
    if (old == null || (old - price).abs() > 0.000001) {
      final point =
          AmmoPricePoint(date: _today(), caliber: caliber, price: price);
      setState(() {
        _priceHistory.insert(0, point);
        if (_priceHistory.length > 500) {
          _priceHistory.removeRange(500, _priceHistory.length);
        }
      });
      saveAmmoPriceHistory(_priceHistory);
      showAppToast(context, tr('ammo_price_saved'));
    }
  }

  Future<void> _editPriceDialog(String caliber) async {
    final ctrl = TextEditingController(
        text: _prices[caliber] == null ? '' : '${_prices[caliber]}');
    final v = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$caliber · ' + tr('ammo_price_unit')),
        content: TextField(
          controller: ctrl,
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
          decoration:
              InputDecoration(labelText: tr('ammo_price_unit')),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(tr('cancel'))),
          TextButton(
              onPressed: () =>
                  Navigator.pop(ctx, double.tryParse(ctrl.text.trim())),
              child: Text(tr('confirm'))),
        ],
      ),
    );
    if (v == null || v < 0) return;
    _setPrice(caliber, v);
  }

  /// 库存量随时间：出入库记录按日期汇总，当前总量减全部变动得基线，
  /// 再按日期累计还原（记录只有最近 200 条，曲线起点为最早记录日）。
  List<TimePoint> _stockSeries() {
    final byDate = <String, int>{};
    for (final m in _movements) {
      byDate[m.date] = (byDate[m.date] ?? 0) + m.delta;
    }
    if (byDate.isEmpty) return [];
    final dates = byDate.keys.toList()..sort();
    final totalNow = _items.fold<int>(0, (s, e) => s + e.quantity);
    final sumDeltas = byDate.values.fold<int>(0, (s, e) => s + e);
    var running = (totalNow - sumDeltas).clamp(0, 100000000);
    final pts = <TimePoint>[];
    for (final d in dates) {
      final dt = DateTime.tryParse(d);
      if (dt == null) continue;
      if (pts.isEmpty) pts.add(TimePoint(dt, running.toDouble()));
      running = (running + byDate[d]!).clamp(0, 100000000);
      pts.add(TimePoint(dt, running.toDouble()));
    }
    return pts;
  }

  /// 单价随时间：每口径一条线；同一天多次改价只留最后一次。
  List<TimeSeries> _priceSeries() {
    final byCal = <String, Map<String, double>>{};
    for (final p in _priceHistory.reversed) {
      byCal.putIfAbsent(p.caliber, () => {})[p.date] = p.price;
    }
    const palette = <int>[
      0xFFE86A1C,
      0xFF2F5DA8,
      0xFF3E7A4E,
      0xFF7A2E2E,
      0xFF6B4FA1,
      0xFF8C6A2F,
    ];
    var i = 0;
    return byCal.entries.map((e) {
      final dates = e.value.keys.toList()..sort();
      final pts = <TimePoint>[];
      for (final d in dates) {
        final dt = DateTime.tryParse(d);
        if (dt == null) continue;
        pts.add(TimePoint(dt, e.value[d]!));
      }
      final color = Color(palette[i++ % palette.length]);
      return TimeSeries(label: e.key, color: color, points: pts);
    }).toList();
  }

  Future<void> _adjustDialog(AmmoItem item, bool isShoot) async {
    final ctrl = TextEditingController();
    final n = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isShoot ? tr('ammo_shoot_use') : tr('ammo_count_check')),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
              labelText: isShoot ? tr('ammo_shoot_label') : tr('ammo_count_label')),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(tr('cancel'))),
          TextButton(
              onPressed: () =>
                  Navigator.pop(ctx, int.tryParse(ctrl.text.trim())),
              child: Text(tr('confirm'))),
        ],
      ),
    );
    if (n == null || n < 0) return;
    if (isShoot) {
      final used = n > item.quantity ? item.quantity : n;
      if (used == 0) return;
      setState(() => item.quantity -= used);
      _save();
      _log(item, -used, '打靶');
    } else {
      final delta = n - item.quantity;
      setState(() => item.quantity = n);
      _save();
      if (delta != 0) _log(item, delta, '盘点');
    }
  }

  /// 从已放行复装记录一键入库：批次号自动带入，填好表单请确认后加入。
  Future<void> _importFromReloadLog() async {
    List<ReloadLogEntry> logs = [];
    try {
      final raw = await _ammoPrefsChannel
          .invokeMethod<String>('getString', {'key': 'reload_log_v1'})
          .timeout(const Duration(seconds: 2));
      if (raw != null && raw.isNotEmpty) {
        logs = (jsonDecode(raw) as List)
            .map((e) => ReloadLogEntry.fromJson(e as Map<String, dynamic>))
            .where((e) => e.released)
            .toList();
      }
    } catch (_) {}
    if (!mounted) return;
    if (logs.isEmpty) {
      showAppToast(context, tr('ammo_no_released'));
      return;
    }
    final picked = await showDialog<ReloadLogEntry>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('ammo_import_from_reload')),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: logs.length,
            itemBuilder: (_, i) {
              final l = logs[i];
              return ListTile(
                title: Text(
                    '${l.batchNo.isNotEmpty ? l.batchNo : l.date} · ${l.caliber}'),
                subtitle: Text('${l.bullet} · ${l.rounds}' + tr('ammo_rounds_suffix')),
                onTap: () => Navigator.pop(ctx, l),
              );
            },
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(tr('cancel'))),
        ],
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      final calibers = caliberInfos.map((c) => c.caliber).toSet();
      if (calibers.contains(picked.caliber)) {
        _caliber = picked.caliber;
      } else {
        _caliber = _manualCaliber;
        _caliberManualCtrl.text = picked.caliber;
      }
      _kind = '复装';
      _nameCtrl.text = picked.bullet;
      _qtyCtrl.text = picked.rounds;
      _boxCtrl.text = '0';
      _batchCtrl.text = picked.batchNo;
    });
    showAppToast(context, tr('ammo_filled_form'));
  }

  @override
  Widget build(BuildContext context) {
    final total = _items.fold<int>(0, (s, e) => s + e.quantity);
    final lowCount = _items.where((e) => e.isLow).length;
    final groups = <String, List<AmmoItem>>{};
    for (final item in _items) {
      groups.putIfAbsent(item.caliber, () => []).add(item);
    }
    final calibers = caliberInfos.map((c) => c.caliber).toList();
    return Scaffold(
      appBar: SubPageAppBar(title: tr('ammo_title')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(tr('ammo_note'),
              style: TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 12),
          Text(tr('ammo_total_prefix') + '$total' + tr('ammo_total_mid') + '${_items.length}' + tr('ammo_total_suffix'),
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFE86A1C),
                  fontSize: 15)),
          if (lowCount > 0)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(tr('ammo_low_prefix') + '$lowCount' + tr('ammo_low_suffix'),
                  style: const TextStyle(color: Colors.red, fontSize: 13)),
            ),
          // 第 5 项④：补货清单区——低于阈值的条目集中列出。
          if (lowCount > 0)
            Card(
              margin: const EdgeInsets.only(top: 8),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tr('ammo_restock_title'),
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.red)),
                    const SizedBox(height: 4),
                    ..._items.where((e) => e.isLow).map((e) => Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                              '${e.name} · ${e.caliber} · ${e.quantity} / ${e.lowAt}',
                              style: const TextStyle(fontSize: 13)),
                        )),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 12),
          Text(tr('ammo_price_title'),
              style: const TextStyle(
                  fontSize: 17, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Builder(builder: (_) {
            double totalValue = 0;
            for (final item in _items) {
              final price = _prices[item.caliber];
              if (price != null) totalValue += item.quantity * price;
            }
            final invCalibers = groups.keys.toList()..sort();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (totalValue > 0)
                  Text(tr('ammo_price_total') + ' $totalValue',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFE86A1C))),
                if (invCalibers.isEmpty)
                  Text(tr('ammo_price_none'),
                      style: TextStyle(color: Colors.grey)),
                for (final cal in invCalibers)
                  Builder(builder: (_) {
                    final qty = groups[cal]!
                        .fold<int>(0, (s2, e) => s2 + e.quantity);
                    final price = _prices[cal];
                    final value = price == null ? null : qty * price;
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text('$cal · $qty' + tr('ammo_stock_rounds')),
                      subtitle: price == null
                          ? null
                          : Text(tr('ammo_price_unit') +
                              ' $price' +
                              (value == null
                                  ? ''
                                  : ' · ' +
                                      tr('ammo_price_value') +
                                      ' $value')),
                      trailing: IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 20),
                        onPressed: () => _editPriceDialog(cal),
                      ),
                    );
                  }),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButton<String>(
                        value:
                            _priceCaliber.isEmpty ? null : _priceCaliber,
                        hint: Text(tr('ammo_caliber_label')),
                        isExpanded: true,
                        items: [
                          for (final c in calibers)
                            DropdownMenuItem(value: c, child: Text(c)),
                        ],
                        onChanged: (v) {
                          if (v != null) {
                            setState(() => _priceCaliber = v);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 110,
                      child: TextField(
                        controller: _priceCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: InputDecoration(
                            labelText: tr('ammo_price_unit')),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: () {
                        final cal = _priceCaliber;
                        final v =
                            double.tryParse(_priceCtrl.text.trim());
                        if (cal.isEmpty || v == null || v < 0) return;
                        _setPrice(cal, v);
                        _priceCtrl.clear();
                      },
                      child: Text(tr('ammo_price_add')),
                    ),
                  ],
                ),
              ],
            );
          }),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            children: [
              ChoiceChip(
                label: Text(tr('ammo_chart_mode_stock')),
                selected: _chartMode == 'stock',
                onSelected: (_) => setState(() => _chartMode = 'stock'),
              ),
              ChoiceChip(
                label: Text(tr('ammo_chart_mode_price')),
                selected: _chartMode == 'price',
                onSelected: (_) => setState(() => _chartMode = 'price'),
              ),
              ChoiceChip(
                label: Text(tr('ammo_chart_mode_all')),
                selected: _chartMode == 'all',
                onSelected: (_) => setState(() => _chartMode = 'all'),
              ),
            ],
          ),
          if (_chartMode == 'stock' || _chartMode == 'all') ...[
            const SizedBox(height: 12),
            Text(tr('ammo_chart_stock_title'),
                style: const TextStyle(
                    fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Builder(builder: (_) {
              final pts = _stockSeries();
              if (pts.isEmpty) {
                return Text(tr('ammo_chart_empty_stock'),
                    style: TextStyle(color: Colors.grey));
              }
              return TimeLineChart(
                series: [
                  TimeSeries(
                      label: '',
                      color: const Color(0xFFE86A1C),
                      points: pts),
                ],
                unit: tr('ammo_chart_unit_rounds'),
              );
            }),
          ],
          if (_chartMode == 'price' || _chartMode == 'all') ...[
            const SizedBox(height: 12),
            Text(tr('ammo_chart_price_title'),
                style: const TextStyle(
                    fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Builder(builder: (_) {
              final s2 = _priceSeries();
              if (s2.isEmpty) {
                return Text(tr('ammo_chart_empty_price'),
                    style: TextStyle(color: Colors.grey));
              }
              return TimeLineChart(
                  series: s2, unit: tr('ammo_chart_unit_price'));
            }),
          ],
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _importFromReloadLog,
            icon: const Icon(Icons.science_outlined, size: 18),
            label: Text(tr('ammo_import_from_reload')),
          ),
          const SizedBox(height: 16),
          Text(tr('ammo_add_title'),
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(tr('ammo_caliber_label')),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButton<String>(
                  value: _caliber,
                  isExpanded: true,
                  items: [
                    for (final c in calibers)
                      DropdownMenuItem(value: c, child: Text(c)),
                    DropdownMenuItem(
                        value: _manualCaliber, child: Text(tr('ammo_other_manual'))),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _caliber = v);
                  },
                ),
              ),
            ],
          ),
          if (_caliber == _manualCaliber) ...[
            const SizedBox(height: 8),
            TextField(
                controller: _caliberManualCtrl,
                onChanged: (_) => setState(() {}),
                decoration:
                    InputDecoration(labelText: tr('ammo_caliber_hint'))),
          ],
          const SizedBox(height: 8),
          TextField(
              controller: _nameCtrl,
              decoration: InputDecoration(
                  labelText: tr('ammo_name_hint'))),
          if (_bulletChips(_resolvedCaliber).isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              children: _bulletChips(_resolvedCaliber)
                  .map((b) => ActionChip(
                        label: Text(b),
                        onPressed: () =>
                            setState(() => _nameCtrl.text = b),
                      ))
                  .toList(),
            ),
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            children: ['厂弹', '复装', '弹头', '火药', '弹壳', '底火']
                .map((k) => ChoiceChip(
                      label: Text(_kindLabel(k)),
                      selected: _kind == k,
                      onSelected: (_) => setState(() => _kind = k),
                    ))
                .toList(),
          ),
          if (_kind == '复装') ...[
            const SizedBox(height: 8),
            TextField(
                controller: _batchCtrl,
                decoration: InputDecoration(
                    labelText: tr('ammo_batch_label'))),
          ],
          const SizedBox(height: 8),
          TextField(
              controller: _qtyCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: tr('ammo_qty_label'))),
          const SizedBox(height: 8),
          TextField(
              controller: _boxCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                  labelText: tr('ammo_per_box_label'))),
          const SizedBox(height: 8),
          TextField(
              controller: _lowCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                  labelText: tr('ammo_low_label'))),
          const SizedBox(height: 8),
          TextField(
              controller: _locationCtrl,
              decoration:
                  InputDecoration(labelText: tr('ammo_location_label'))),
          const SizedBox(height: 8),
          TextField(
              controller: _noteCtrl,
              decoration: InputDecoration(labelText: tr('ammo_note_label'))),
          const SizedBox(height: 12),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFE86A1C)),
            onPressed: _add,
            child: Text(tr('ammo_add_btn'),
                style: TextStyle(color: Colors.white)),
          ),
          const SizedBox(height: 20),
          if (_items.isEmpty)
            Text(tr('ammo_empty'),
                style: TextStyle(color: Colors.grey))
          else
            ...groups.entries.map((entry) {
              final groupTotal =
                  entry.value.fold<int>(0, (s, e) => s + e.quantity);
              final groupLow = entry.value.any((e) => e.isLow);
              return Card(
                child: ExpansionTile(
                  title: Text(
                      '${entry.key} · ' + tr('ammo_group_prefix') + '$groupTotal' + tr('ammo_group_mid') + '${entry.value.length}' + tr('ammo_group_suffix')),
                  subtitle: groupLow
                      ? Text(tr('ammo_group_low'),
                          style: TextStyle(color: Colors.red, fontSize: 12))
                      : null,
                  children: entry.value.map((item) {
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                    '${item.name} · ${item.kind}${item.batchNo.isNotEmpty ? ' · ${item.batchNo}' : ''}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold)),
                              ),
                              IconButton(
                                icon: const Icon(Icons.tune_outlined,
                                    size: 20),
                                tooltip: tr('ammo_set_low'),
                                onPressed: () => _editLowDialog(item),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () {
                                  setState(() => _items.remove(item));
                                  _save();
                                },
                              ),
                            ],
                          ),
                          if (item.location.isNotEmpty)
                            Text(tr('ammo_location_prefix') + item.location,
                                style: const TextStyle(
                                    color: Colors.grey, fontSize: 12)),
                          if (item.note.isNotEmpty)
                            Text(item.note,
                                style: const TextStyle(
                                    color: Colors.grey, fontSize: 12)),
                          const SizedBox(height: 4),
                          Text(item.stockText,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFE86A1C))),
                          if (item.isLow)
                            Text(tr('ammo_below_line_prefix') + '${item.lowAt}' + tr('ammo_below_line_suffix'),
                                style: const TextStyle(
                                    color: Colors.red, fontSize: 12)),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              if (item.roundsPerBox > 0)
                                OutlinedButton(
                                    onPressed: () => _bump(item,
                                        item.roundsPerBox, '买入'),
                                    child: Text(tr('ammo_add_box'))),
                              if (item.roundsPerBox > 0)
                                OutlinedButton(
                                    onPressed: () => _bump(item,
                                        -item.roundsPerBox, '消耗'),
                                    child: Text(tr('ammo_remove_box'))),
                              OutlinedButton(
                                  onPressed: () => _bump(item, 10, '买入'),
                                  child: const Text('+10')),
                              OutlinedButton(
                                  onPressed: () => _bump(item, -10, '消耗'),
                                  child: const Text('-10')),
                              OutlinedButton(
                                  onPressed: () => _adjustDialog(item, true),
                                  child: Text(tr('ammo_shoot_use'))),
                              OutlinedButton(
                                  onPressed: () => _adjustDialog(item, false),
                                  child: Text(tr('ammo_count_check'))),
                            ],
                          ),
                          const Divider(height: 20),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              );
            }),
          if (_movements.isNotEmpty) ...[
            const SizedBox(height: 8),
            Card(
              child: ExpansionTile(
                title: Text(tr('ammo_movements_prefix') + '${_movements.length > 30 ? 30 : _movements.length}' + tr('ammo_movements_suffix')),
                children: _movements.take(30).map((m) {
                  final sign = m.delta >= 0 ? '+' : '';
                  return ListTile(
                    dense: true,
                    title: Text('${m.name} · ${m.caliber}'),
                    subtitle: Text('${m.date} · ${_reasonLabel(m.reason)}'),
                    trailing: Text('$sign${m.delta}',
                        style: TextStyle(
                            color: m.delta >= 0
                                ? Colors.green
                                : Colors.red,
                            fontWeight: FontWeight.bold)),
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
