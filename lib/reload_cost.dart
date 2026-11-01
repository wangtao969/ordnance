import 'dart:convert';

import 'package:flutter/services.dart';

import 'data.dart';
import 'models.dart';

/// 复装每发成本与库存扣减（第 5 项）：只用组件库已核实价格，
/// 价格缺失或非美元币种的项返回 null（界面显示留空，绝不估算）。

double? _num(String s) => double.tryParse(s.replaceAll(',', ''));

bool _nonUsd(String price) =>
    price.contains('ZAR') ||
    price.contains('AUD') ||
    price.contains('€') ||
    price.contains('£') ||
    price.contains('日元') ||
    price.contains('加元');

/// 每发单价（弹头 / 底火 / 弹壳）：认“\$X / N 发”与“X 美元 / N 发”。
double? unitPricePerRound(String price) {
  if (_nonUsd(price)) return null;
  // 两种写法都认：“\$26.54 / 100 发”与“103.52 美元 / 1000 发”。
  final m = RegExp(r'(?:\$\s*)?([\d,]+\.?\d*)\s*(?:美元)?\s*/\s*([\d,]+)\s*发')
      .firstMatch(price);
  if (m == null) return null;
  final amount = _num(m.group(1)!);
  final count = _num(m.group(2)!);
  if (amount == null || count == null || count <= 0) return null;
  return amount / count;
}

/// 每磅单价（火药）：认“\$X / N 磅”与“\$X / 磅”。
double? pricePerPound(String price) {
  if (_nonUsd(price)) return null;
  var m = RegExp(r'\$([\d,]+\.?\d*)\s*/\s*([\d,]+)\s*磅').firstMatch(price);
  if (m != null) {
    final amount = _num(m.group(1)!);
    final count = _num(m.group(2)!);
    if (amount == null || count == null || count <= 0) return null;
    return amount / count;
  }
  m = RegExp(r'\$([\d,]+\.?\d*)\s*/\s*磅').firstMatch(price);
  if (m == null) return null;
  return _num(m.group(1)!);
}

/// 组件库按（品类，名称）精确匹配；名不符返回 null，不模糊匹配。
ReloadComponent? findComponent(String kind, String name) {
  final t = name.trim();
  if (t.isEmpty) return null;
  for (final c in reloadComponents) {
    if (c.kind == kind && c.name == t) return c;
  }
  return null;
}

class RoundCost {
  final double? bullet;
  final double? powder;
  final double? primer;
  final double? kase;

  const RoundCost({this.bullet, this.powder, this.primer, this.kase});

  bool get complete =>
      bullet != null && powder != null && primer != null && kase != null;

  double get knownSum {
    var s = 0.0;
    if (bullet != null) s += bullet!;
    if (powder != null) s += powder!;
    if (primer != null) s += primer!;
    if (kase != null) s += kase!;
    return s;
  }
}

/// 本批每发成本：弹头 / 火药（装药量格令 × 每磅价 / 7000）/
/// 底火 / 弹壳（单价按复用次数分摊，次数缺失按 1 计）。
RoundCost costPerRound({
  required String bullet,
  required String powder,
  required double? chargeGr,
  required String primer,
  required String caseBrand,
  required int? caseTimes,
}) {
  double? b;
  double? p;
  double? pr;
  double? c;
  final bc = findComponent('弹头', bullet);
  if (bc != null) b = unitPricePerRound(bc.price);
  final pc = findComponent('火药', powder);
  if (pc != null && chargeGr != null) {
    final perLb = pricePerPound(pc.price);
    if (perLb != null) p = chargeGr * perLb / 7000;
  }
  final prc = findComponent('底火', primer);
  if (prc != null) pr = unitPricePerRound(prc.price);
  final cc = findComponent('弹壳', caseBrand);
  if (cc != null) {
    final u = unitPricePerRound(cc.price);
    if (u != null) {
      c = u / (caseTimes != null && caseTimes > 0 ? caseTimes : 1);
    }
  }
  return RoundCost(bullet: b, powder: p, primer: pr, kase: c);
}

/// 成本显示：小于 1 美元留 3 位小数，否则 2 位。
String fmtCost(double v) =>
    '\$${v < 1 ? v.toStringAsFixed(3) : v.toStringAsFixed(2)}';

// ---------------------------------------------------------------------------
// 库存扣减用的弹药库存读写（与 ammo_inventory_screen 同 key，
// 直接走 gunsmap/prefs；用原始 Map 读写，避免覆盖 lowAt 等字段）。
// 单独放这里是为了避开 reload_log_screen ↔ ammo_inventory_screen
// 的循环 import。

const _stockChannel = MethodChannel('gunsmap/prefs');
const _stockItemsKey = 'ammo_inventory_v1';
const _stockMovementsKey = 'ammo_movements_v1';

Future<List<Map<String, dynamic>>> loadStockMaps() async {
  try {
    final raw = await _stockChannel
        .invokeMethod<String>('getString', {'key': _stockItemsKey})
        .timeout(const Duration(seconds: 2));
    if (raw == null || raw.isEmpty) return [];
    return (jsonDecode(raw) as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  } catch (_) {
    return [];
  }
}

Future<void> saveStockMaps(List<Map<String, dynamic>> items) async {
  try {
    await _stockChannel.invokeMethod('setString', {
      'key': _stockItemsKey,
      'value': jsonEncode(items),
    });
  } catch (_) {}
}

Future<void> addStockMovement({
  required String date,
  required String name,
  required String caliber,
  required int delta,
  required String reason,
}) async {
  try {
    final raw = await _stockChannel
        .invokeMethod<String>('getString', {'key': _stockMovementsKey})
        .timeout(const Duration(seconds: 2));
    final list = <Map<String, dynamic>>[];
    if (raw != null && raw.isNotEmpty) {
      list.addAll((jsonDecode(raw) as List)
          .map((e) => Map<String, dynamic>.from(e as Map)));
    }
    list.insert(0, {
      'date': date,
      'name': name,
      'caliber': caliber,
      'delta': delta,
      'reason': reason,
    });
    if (list.length > 200) list.removeRange(200, list.length);
    await _stockChannel.invokeMethod('setString', {
      'key': _stockMovementsKey,
      'value': jsonEncode(list),
    });
  } catch (_) {}
}
