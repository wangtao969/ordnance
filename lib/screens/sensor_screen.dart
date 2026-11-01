import 'package:flutter/material.dart';

import '../i18n.dart';
import '../range_trip_data.dart';
import '../sensors_api.dart';
import '../weather_api.dart';
import '../widgets/app_top_bar.dart';

/// 传感器工具页（2.2.5）：指南针 / 气压计 / GPS / 水平仪。
/// 全部是记录与测量类展示，不出射击解算；无传感器、未授权、
/// 读数超时都有可读提示，不编数。
class SensorScreen extends StatefulWidget {
  const SensorScreen({super.key});

  @override
  State<SensorScreen> createState() => _SensorScreenState();
}

class _SensorScreenState extends State<SensorScreen> {
  SensorResult<double>? _heading;
  SensorResult<double>? _pressure;
  SensorResult<GpsFix>? _gps;
  SensorResult<double>? _roll;
  var _gpsMsg = '';

  @override
  void initState() {
    super.initState();
    _refreshAll();
  }

  String _errText(SensorResult? r, {bool barometer = false}) {
    final e = r?.error;
    if (e == null) return '';
    switch (e) {
      case 'permission':
        return tr('sensor_no_permission');
      case 'timeout':
        return tr('sensor_timeout');
      case 'unavailable':
        return barometer
            ? tr('sensor_no_barometer')
            : tr('sensor_unavailable');
      default:
        return tr('sensor_unavailable');
    }
  }

  Future<void> _refreshAll() async {
    final heading = await getCompassHeading();
    final pressure = await getPressureHpa();
    final roll = await getRollDegrees();
    if (mounted) {
      setState(() {
        _heading = heading;
        _pressure = pressure;
        _roll = roll;
      });
    }
    await _refreshGps();
  }

  Future<void> _refreshGps() async {
    final granted = await requestLocationPermission();
    if (!granted) {
      if (mounted) {
        setState(() => _gps = const SensorResult(error: 'permission'));
      }
      return;
    }
    final fix = await getGpsPosition();
    if (mounted) setState(() => _gps = fix);
  }

  Future<void> _fillTrip() async {
    final fix = _gps?.value;
    if (fix == null) return;
    final trips = await loadRangeTrips();
    if (trips.isEmpty) {
      if (mounted) setState(() => _gpsMsg = tr('weather_no_trips'));
      return;
    }
    final picked = await showDialog<RangeTrip>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(tr('sensor_fill_trip')),
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
    picked.place =
        '${fix.latitude.toStringAsFixed(5)}, ${fix.longitude.toStringAsFixed(5)}';
    await saveRangeTrips(trips);
    if (mounted) setState(() => _gpsMsg = tr('sensor_filled_trip'));
  }

  @override
  Widget build(BuildContext context) {
    final heading = _heading?.value;
    final pressure = _pressure?.value;
    final gps = _gps?.value;
    final roll = _roll?.value;
    return ValueListenableBuilder<String>(
      valueListenable: localeNotifier,
      builder: (_, __, ___) => Scaffold(
        appBar: SubPageAppBar(title: tr('sensors')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: _refreshAll,
                icon: const Icon(Icons.refresh, size: 18),
                label: Text(tr('sensor_refresh')),
              ),
            ),
            const SizedBox(height: 8),
            _card(
              tr('sensor_compass'),
              heading == null
                  ? _errText(_heading)
                  : '${heading.toStringAsFixed(0)}° ${compassDir(heading)}',
              heading == null,
            ),
            _card(
              tr('sensor_pressure'),
              pressure == null
                  ? _errText(_pressure, barometer: true)
                  : '${pressure.toStringAsFixed(1)} hPa',
              pressure == null,
            ),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tr('sensor_gps'),
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    if (gps == null)
                      Text(_errText(_gps),
                          style: const TextStyle(color: Colors.grey))
                    else ...[
                      _line(tr('sensor_lat'),
                          gps.latitude.toStringAsFixed(5)),
                      _line(tr('sensor_lon'),
                          gps.longitude.toStringAsFixed(5)),
                      _line(
                          tr('sensor_alt'),
                          gps.altitude == null
                              ? '—'
                              : '${gps.altitude!.toStringAsFixed(1)} m'),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: _fillTrip,
                        icon: const Icon(Icons.location_on_outlined,
                            size: 18),
                        label: Text(tr('sensor_fill_trip')),
                      ),
                      if (_gpsMsg.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(_gpsMsg,
                              style: const TextStyle(
                                  color: Colors.grey, fontSize: 12)),
                        ),
                    ],
                  ],
                ),
              ),
            ),
            _card(
              tr('sensor_level'),
              roll == null
                  ? _errText(_roll)
                  : '${tr('sensor_roll')} ${roll.toStringAsFixed(1)}°',
              roll == null,
            ),
            const SizedBox(height: 8),
            Text(tr('sensor_note'),
                style: const TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _card(String title, String body, bool isError) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(body,
                  style: TextStyle(
                      fontSize: 20,
                      color: isError ? Colors.grey : null)),
            ],
          ),
        ),
      );

  Widget _line(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            SizedBox(
                width: 80,
                child: Text(label,
                    style: const TextStyle(color: Colors.grey))),
            Expanded(child: Text(value)),
          ],
        ),
      );
}
