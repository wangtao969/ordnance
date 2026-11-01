import 'package:flutter/material.dart';

import '../i18n.dart';
import '../range_trip_data.dart';
import '../sensors_api.dart';
import '../weather_api.dart';
import '../widgets/app_top_bar.dart';

/// 天气工具页（2.2.5）：Open-Meteo 实况 + 24 小时逐小时 + 7 天逐日。
/// 只展示气象条件：不算密度高度、不给风偏修正、不出任何射击解算。
/// 断网或接口失败显示可读提示，不闪退、不转圈卡死（请求有超时）。
class WeatherScreen extends StatefulWidget {
  const WeatherScreen({super.key});

  @override
  State<WeatherScreen> createState() => _WeatherScreenState();
}

class _WeatherScreenState extends State<WeatherScreen> {
  WeatherData? _data;
  var _place = '';
  var _loading = false;
  String? _error; // 'failed' | 'nogps'
  var _tripMsg = '';
  final _cityCtrl = TextEditingController();
  var _cityResults = <GeoPlace>[];

  @override
  void initState() {
    super.initState();
    _loadGps();
  }

  @override
  void dispose() {
    _cityCtrl.dispose();
    super.dispose();
  }

  String _fmt1(double? v) {
    if (v == null) return '—';
    final s = v.toStringAsFixed(1);
    return s.endsWith('.0') ? s.substring(0, s.length - 2) : s;
  }

  Future<void> _loadGps() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final granted = await requestLocationPermission();
    if (!granted) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'nogps';
        });
      }
      return;
    }
    final fix = await getGpsPosition();
    if (!fix.ok || fix.value == null) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = fix.error == 'permission' ? 'nogps' : 'failed';
        });
      }
      return;
    }
    final v = fix.value!;
    await _fetch(v.latitude, v.longitude,
        '${v.latitude.toStringAsFixed(4)}, ${v.longitude.toStringAsFixed(4)}');
  }

  Future<void> _fetch(double lat, double lon, String place) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await fetchWeather(lat, lon);
      if (mounted) {
        setState(() {
          _data = data;
          _place = place;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'failed';
        });
      }
    }
  }

  Future<void> _searchCity() async {
    final results = await searchCity(_cityCtrl.text);
    if (mounted) setState(() => _cityResults = results);
  }

  Future<void> _saveToTrip() async {
    final data = _data;
    if (data == null) return;
    final trips = await loadRangeTrips();
    if (trips.isEmpty) {
      if (mounted) setState(() => _tripMsg = tr('weather_no_trips'));
      return;
    }
    final snapshot = buildWeatherSnapshot(data, _place);
    final picked = await showDialog<RangeTrip>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(tr('weather_save_trip')),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final t in trips)
                ListTile(
                  title: Text(t.place.isEmpty
                      ? DateTime.fromMillisecondsSinceEpoch(t.dateMs)
                          .toString()
                          .substring(0, 10)
                      : t.place),
                  onTap: () => Navigator.pop(context, t),
                ),
            ],
          ),
        ),
      ),
    );
    if (picked == null) return;
    picked.note =
        picked.note.isEmpty ? snapshot : '${picked.note}\n$snapshot';
    await saveRangeTrips(trips);
    if (mounted) setState(() => _tripMsg = tr('weather_saved_trip'));
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    return ValueListenableBuilder<String>(
      valueListenable: localeNotifier,
      builder: (_, __, ___) => Scaffold(
        appBar: SubPageAppBar(title: tr('weather')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _cityCtrl,
                    onSubmitted: (_) => _searchCity(),
                    decoration: InputDecoration(
                      hintText: tr('weather_city_search'),
                      prefixIcon: const Icon(Icons.search),
                      border: const OutlineInputBorder(
                          borderRadius:
                              BorderRadius.all(Radius.circular(12))),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: _loadGps,
                  child: Text(tr('weather_use_gps')),
                ),
              ],
            ),
            if (_cityResults.isNotEmpty) ...[
              const SizedBox(height: 8),
              for (final p in _cityResults)
                ListTile(
                  title: Text(p.display),
                  onTap: () {
                    setState(() => _cityResults = []);
                    _fetch(p.lat, p.lon, p.display);
                  },
                ),
            ],
            const SizedBox(height: 16),
            if (_loading) Center(child: Text(tr('weather_loading'))),
            if (_error == 'failed') ...[
              Text(tr('weather_failed'),
                  style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: _loadGps,
                child: Text(tr('weather_use_gps')),
              ),
            ],
            if (_error == 'nogps')
              Text(tr('weather_no_gps'),
                  style: const TextStyle(color: Colors.grey)),
            if (data != null) ...[
              Text(_place,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(
                  '${_fmt1(data.temp)}°C',
                  style: const TextStyle(
                      fontSize: 36, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(tr('weather_now'),
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              _row(tr('weather_wind'),
                  '${_fmt1(data.windSpeed)} km/h${data.windDir == null ? '' : ' ${compassDir(data.windDir!)}'}'),
              _row(tr('weather_humidity'), '${_fmt1(data.humidity)}%'),
              _row(tr('weather_pressure'), '${_fmt1(data.pressure)} hPa'),
              _row(tr('weather_precip'), '${_fmt1(data.precipProb)}%'),
              const SizedBox(height: 16),
              Text(tr('weather_hourly'),
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final h in data.hours)
                      Container(
                        width: 64,
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          border: Border.all(
                              color: Colors.grey.withValues(alpha: 0.4)),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            Text(
                                '${h.time.hour.toString().padLeft(2, '0')}:${h.time.minute.toString().padLeft(2, '0')}',
                                style: const TextStyle(fontSize: 12)),
                            Text('${_fmt1(h.temp)}°',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                            Text('${_fmt1(h.precipProb)}%',
                                style: const TextStyle(
                                    color: Colors.grey, fontSize: 12)),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(tr('weather_daily'),
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              for (final d in data.days)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      SizedBox(
                          width: 64,
                          child: Text(
                              '${d.date.month}/${d.date.day}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold))),
                      Expanded(
                          child: Text(
                              '${_fmt1(d.tempMin)}° / ${_fmt1(d.tempMax)}°')),
                      Text('${_fmt1(d.precipProb)}%',
                          style: const TextStyle(color: Colors.grey)),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _saveToTrip,
                icon: const Icon(Icons.note_add_outlined, size: 18),
                label: Text(tr('weather_save_trip')),
              ),
              if (_tripMsg.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(_tripMsg,
                      style:
                          const TextStyle(color: Colors.grey, fontSize: 12)),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            SizedBox(
                width: 110,
                child: Text(label,
                    style: const TextStyle(color: Colors.grey))),
            Expanded(child: Text(value)),
          ],
        ),
      );
}
