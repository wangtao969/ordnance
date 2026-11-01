import 'package:flutter/services.dart';

/// 机身传感器原生通道（gunsmap/sensors，零第三方包）。
/// 所有读数均为测量值展示，不做任何射击解算。
/// error 取值：'permission' 未授权 / 'unavailable' 无传感器或无定位 /
/// 'timeout' 读数超时 / 'error' 其他异常；value 为 null 时看 error。
class SensorResult<T> {
  final T? value;
  final String? error;
  const SensorResult({this.value, this.error});
  bool get ok => value != null;
}

class GpsFix {
  final double latitude;
  final double longitude;
  final double? altitude;
  const GpsFix(this.latitude, this.longitude, this.altitude);
}

const _sensorsChannel = MethodChannel('gunsmap/sensors');

Future<bool> requestLocationPermission() async {
  try {
    return await _sensorsChannel
            .invokeMethod<bool>('requestLocationPermission') ??
        false;
  } catch (_) {
    return false;
  }
}

SensorResult<GpsFix> _parseGps(Map<String, dynamic> m) {
  final err = m['error'] as String?;
  if (err != null) return SensorResult(error: err);
  final lat = (m['latitude'] as num?)?.toDouble();
  final lon = (m['longitude'] as num?)?.toDouble();
  if (lat == null || lon == null) {
    return const SensorResult(error: 'unavailable');
  }
  return SensorResult(
      value: GpsFix(lat, lon, (m['altitude'] as num?)?.toDouble()));
}

Future<SensorResult<GpsFix>> getGpsPosition() async {
  try {
    final m = await _sensorsChannel
        .invokeMapMethod<String, dynamic>('getGps')
        .timeout(const Duration(seconds: 10));
    if (m == null) return const SensorResult(error: 'error');
    return _parseGps(m);
  } catch (_) {
    return const SensorResult(error: 'error');
  }
}

Future<SensorResult<double>> _parseDouble(
    String method, String field) async {
  try {
    final m = await _sensorsChannel
        .invokeMapMethod<String, dynamic>(method)
        .timeout(const Duration(seconds: 10));
    if (m == null) return const SensorResult(error: 'error');
    final err = m['error'] as String?;
    if (err != null) return SensorResult(error: err);
    final v = (m[field] as num?)?.toDouble();
    if (v == null) return const SensorResult(error: 'unavailable');
    return SensorResult(value: v);
  } catch (_) {
    return const SensorResult(error: 'error');
  }
}

/// 指南针朝向（度，0 = 北，顺时针）。
Future<SensorResult<double>> getCompassHeading() =>
    _parseDouble('getCompass', 'heading');

/// 本站气压（hPa）；无气压计的设备返回 error 'unavailable'。
Future<SensorResult<double>> getPressureHpa() =>
    _parseDouble('getPressure', 'pressure');

/// 横滚角（度，绕设备长轴，0 = 平放水平）。
Future<SensorResult<double>> getRollDegrees() =>
    _parseDouble('getLevel', 'roll');
