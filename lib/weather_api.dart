import 'dart:convert';
import 'dart:io';

/// Open-Meteo 天气（免 key、免账号）：实况 + 24 小时逐小时 + 7 天逐日。
/// 只展示气象条件：不算密度高度、不给风偏修正、不出任何射击解算。
class HourlyWeather {
  final DateTime time;
  final double? temp;
  final double? precipProb;
  final double? windSpeed;
  const HourlyWeather(this.time, this.temp, this.precipProb, this.windSpeed);
}

class DailyWeather {
  final DateTime date;
  final double? tempMax;
  final double? tempMin;
  final double? precipProb;
  const DailyWeather(this.date, this.tempMax, this.tempMin, this.precipProb);
}

class WeatherData {
  final double? temp;
  final double? windSpeed; // km/h
  final double? windDir; // 度
  final double? humidity; // %
  final double? pressure; // hPa
  final double? precipProb; // %（实况时刻的逐小时降水概率）
  final List<HourlyWeather> hours;
  final List<DailyWeather> days;
  const WeatherData({
    this.temp,
    this.windSpeed,
    this.windDir,
    this.humidity,
    this.pressure,
    this.precipProb,
    this.hours = const [],
    this.days = const [],
  });
}

class GeoPlace {
  final String name;
  final String country;
  final double lat;
  final double lon;
  const GeoPlace(this.name, this.country, this.lat, this.lon);
  String get display => country.isEmpty ? name : '$name, $country';
}

double? _num(dynamic v) => (v as num?)?.toDouble();

List<dynamic> _list(Map<String, dynamic> j, String section, String key) {
  final s = j[section];
  if (s is Map<String, dynamic>) {
    final v = s[key];
    if (v is List) return v;
  }
  return const [];
}

Future<WeatherData> fetchWeather(double lat, double lon) async {
  final uri = Uri.parse(
      'https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon'
      '&current=temperature_2m,relative_humidity_2m,pressure_msl,wind_speed_10m,wind_direction_10m'
      '&hourly=temperature_2m,precipitation_probability,wind_speed_10m'
      '&daily=temperature_2m_max,temperature_2m_min,precipitation_probability_max'
      '&timezone=auto&forecast_days=7');
  final client = HttpClient();
  client.connectionTimeout = const Duration(seconds: 10);
  try {
    final req = await client.getUrl(uri);
    final resp = await req.close().timeout(const Duration(seconds: 15));
    if (resp.statusCode != 200) {
      throw Exception('status ${resp.statusCode}');
    }
    final body = await resp.transform(utf8.decoder).join();
    final j = jsonDecode(body) as Map<String, dynamic>;
    final cur = j['current'];
    final curMap = cur is Map<String, dynamic> ? cur : <String, dynamic>{};
    final now = DateTime.now();
    final hours = <HourlyWeather>[];
    final hTimes = _list(j, 'hourly', 'time');
    final hTemp = _list(j, 'hourly', 'temperature_2m');
    final hProb = _list(j, 'hourly', 'precipitation_probability');
    final hWind = _list(j, 'hourly', 'wind_speed_10m');
    double? curProb;
    for (var i = 0; i < hTimes.length; i++) {
      final t = DateTime.tryParse(hTimes[i].toString());
      if (t == null) continue;
      if (t.isBefore(now.subtract(const Duration(hours: 1)))) continue;
      if (hours.length >= 24) break;
      hours.add(HourlyWeather(
        t,
        i < hTemp.length ? _num(hTemp[i]) : null,
        i < hProb.length ? _num(hProb[i]) : null,
        i < hWind.length ? _num(hWind[i]) : null,
      ));
      if (curProb == null && !t.isAfter(now.add(const Duration(hours: 1)))) {
        curProb = i < hProb.length ? _num(hProb[i]) : null;
      }
    }
    final days = <DailyWeather>[];
    final dTimes = _list(j, 'daily', 'time');
    final dMax = _list(j, 'daily', 'temperature_2m_max');
    final dMin = _list(j, 'daily', 'temperature_2m_min');
    final dProb = _list(j, 'daily', 'precipitation_probability_max');
    for (var i = 0; i < dTimes.length && days.length < 7; i++) {
      final t = DateTime.tryParse(dTimes[i].toString());
      if (t == null) continue;
      days.add(DailyWeather(
        t,
        i < dMax.length ? _num(dMax[i]) : null,
        i < dMin.length ? _num(dMin[i]) : null,
        i < dProb.length ? _num(dProb[i]) : null,
      ));
    }
    return WeatherData(
      temp: _num(curMap['temperature_2m']),
      windSpeed: _num(curMap['wind_speed_10m']),
      windDir: _num(curMap['wind_direction_10m']),
      humidity: _num(curMap['relative_humidity_2m']),
      pressure: _num(curMap['pressure_msl']),
      precipProb: curProb,
      hours: hours,
      days: days,
    );
  } finally {
    client.close();
  }
}

Future<List<GeoPlace>> searchCity(String query) async {
  final q = query.trim();
  if (q.isEmpty) return [];
  final uri = Uri.parse(
      'https://geocoding-api.open-meteo.com/v1/search?name=${Uri.encodeComponent(q)}&count=10&language=zh&format=json');
  final client = HttpClient();
  client.connectionTimeout = const Duration(seconds: 10);
  try {
    final req = await client.getUrl(uri);
    final resp = await req.close().timeout(const Duration(seconds: 15));
    if (resp.statusCode != 200) return [];
    final body = await resp.transform(utf8.decoder).join();
    final j = jsonDecode(body) as Map<String, dynamic>;
    final results = j['results'];
    if (results is! List) return [];
    final out = <GeoPlace>[];
    for (final r in results) {
      if (r is! Map<String, dynamic>) continue;
      final lat = _num(r['latitude']);
      final lon = _num(r['longitude']);
      if (lat == null || lon == null) continue;
      out.add(GeoPlace(
        r['name'] as String? ?? '',
        r['country'] as String? ?? '',
        lat,
        lon,
      ));
    }
    return out;
  } catch (_) {
    return [];
  } finally {
    client.close();
  }
}

/// 风向 16 方位字母（语言中性）。
String compassDir(double deg) {
  const dirs = [
    'N', 'NNE', 'NE', 'ENE', 'E', 'ESE', 'SE', 'SSE',
    'S', 'SSW', 'SW', 'WSW', 'W', 'WNW', 'NW', 'NNW',
  ];
  final idx = ((deg % 360) / 22.5).round() % 16;
  return dirs[idx];
}

String _fmt(double v) {
  final s = v.toStringAsFixed(1);
  return s.endsWith('.0') ? s.substring(0, s.length - 2) : s;
}

String _two(int v) => v.toString().padLeft(2, '0');

/// 行程备注用天气快照：纯数值 + 单位 + 时间戳，不依赖界面语言，
/// 记进行程备注后即为用户记录原文。
String buildWeatherSnapshot(WeatherData w, String place) {
  final parts = <String>[];
  if (place.isNotEmpty) parts.add(place);
  if (w.temp != null) parts.add('${_fmt(w.temp!)}°C');
  if (w.windSpeed != null) {
    parts.add('wind ${_fmt(w.windSpeed!)}km/h'
        '${w.windDir == null ? '' : ' ${compassDir(w.windDir!)}'}');
  }
  if (w.humidity != null) parts.add('humidity ${_fmt(w.humidity!)}%');
  if (w.pressure != null) parts.add('pressure ${_fmt(w.pressure!)}hPa');
  if (w.precipProb != null) parts.add('precip ${_fmt(w.precipProb!)}%');
  final now = DateTime.now();
  final stamp =
      '${now.year}-${_two(now.month)}-${_two(now.day)} ${_two(now.hour)}:${_two(now.minute)}';
  return '${parts.join(', ')} @ $stamp';
}
