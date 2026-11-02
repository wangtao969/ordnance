import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import 'i18n.dart';
import 'sensors_api.dart';
import 'system_actions.dart';
import 'widgets/app_toast.dart';

/// 定位流程（零第三方包）：授权、取坐标、地名反查、跳系统地图。
/// 不做任何射击解算；坐标只用于显示地点与地图。

/// 解析“纬度, 经度”全文（允许空格与中文逗号）；非坐标文本返回 null。
/// 存量记录里纯经纬度字符串靠它识别，解析失败时调用方按普通地名处理。
({double lat, double lon})? parseLatLon(String text) {
  final m = RegExp(r'^\s*(-?\d+(?:\.\d+)?)\s*[,，]\s*(-?\d+(?:\.\d+)?)\s*$')
      .firstMatch(text);
  if (m == null) return null;
  final lat = double.tryParse(m.group(1)!);
  final lon = double.tryParse(m.group(2)!);
  if (lat == null || lon == null) return null;
  if (lat < -90 || lat > 90 || lon < -180 || lon > 180) return null;
  return (lat: lat, lon: lon);
}

/// Nominatim 免 key 地名反查：城市 + 道路，查不到或离线返回 null，
/// 调用方回落显示经纬度，绝不编造地名。同一坐标 4 位小数缓存一次。
final _geoCache = <String, String>{};

Future<String?> reverseGeocode(double lat, double lon) async {
  final key = '${lat.toStringAsFixed(4)},${lon.toStringAsFixed(4)}';
  if (_geoCache.containsKey(key)) return _geoCache[key];
  try {
    final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lon&zoom=18&addressdetails=1');
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 10);
    final req = await client.getUrl(uri);
    req.headers.set('User-Agent', 'Ordnance/2.3 (Android)');
    final resp = await req.close().timeout(const Duration(seconds: 15));
    if (resp.statusCode != 200) return null;
    final body = await resp.transform(utf8.decoder).join();
    final j = jsonDecode(body) as Map<String, dynamic>;
    final addr = j['address'] as Map<String, dynamic>?;
    String? name;
    if (addr != null) {
      final city = addr['city'] ??
          addr['town'] ??
          addr['village'] ??
          addr['municipality'] ??
          addr['county'] ??
          addr['state'];
      final road = addr['road'];
      if (city != null && road != null) {
        name = '$city $road';
      } else if (city != null) {
        name = city.toString();
      }
    }
    name ??= (j['display_name'] as String?)?.split(',').take(2).join(',');
    if (name != null && name.trim().isNotEmpty) {
      _geoCache[key] = name.trim();
      return name.trim();
    }
    return null;
  } catch (_) {
    return null;
  }
}

/// 点地图预览跳系统地图：先 geo intent（命中地图 App），
/// 无应用接手时回落 OSM 网页链接走浏览器。
Future<bool> openMapAt(double lat, double lon) async {
  final ok = await openSystemUrl('geo:$lat,$lon?q=$lat,$lon');
  if (ok) return true;
  return await openSystemUrl(
      'https://www.openstreetmap.org/?mlat=$lat&mlon=$lon#map=15/$lat/$lon');
}

/// 定位授权流程：首次先弹一句话用途说明；之前拒绝过则给
/// “去设置 / 再试一次”；返回 true 表示已授权。
/// 会话内 _askedBefore 只记本次运行是否问过，不做持久化。
bool _askedBefore = false;

Future<bool> ensureLocationPermission(BuildContext context) async {
  if (!_askedBefore) {
    _askedBefore = true;
    if (!context.mounted) return false;
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('loc_purpose_title')),
        content: Text(tr('loc_purpose_text')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(tr('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(tr('loc_start')),
          ),
        ],
      ),
    );
    if (go != true || !context.mounted) return false;
    return await requestLocationPermission();
  }
  final ok = await requestLocationPermission();
  if (ok || !context.mounted) return ok;
  final choice = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(tr('compose_location_denied')),
      content: Text(tr('loc_denied_text')),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, 'retry'),
          child: Text(tr('loc_retry')),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, 'settings'),
          child: Text(tr('loc_open_settings')),
        ),
      ],
    ),
  );
  if (choice == 'settings') {
    final opened = await openAppSettings();
    if (!opened && context.mounted) {
      showAppToast(context, tr('loc_settings_failed'));
    }
    return false;
  }
  if (choice == 'retry') return await requestLocationPermission();
  return false;
}

/// 取一次 GPS：成功返回 fix；失败返回 error 原文
/// （'permission' 未授权 / 'unavailable' 无定位或 GPS 未开 /
/// 其他为一般失败），调用方按 error 给可读提示。
Future<SensorResult<GpsFix>> fetchCurrentFix() => getGpsPosition();

/// 定位失败 error → 可读提示 key。
String locErrorKey(String? error) {
  switch (error) {
    case 'permission':
      return 'compose_location_denied';
    case 'unavailable':
      return 'loc_gps_hint';
    default:
      return 'compose_location_failed';
  }
}
