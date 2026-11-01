import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_log.dart';
import '../community_store.dart';
import '../i18n.dart';
import '../range_trip_data.dart';
import '../widgets/app_toast.dart';
import '../widgets/app_top_bar.dart';
import 'gun_picker_dialog.dart';

/// 靶场行程：一次出行的容器，只包起枪、弹药备注与关联成绩。
/// 经 gunsmap/prefs 存本机（key range_trips_v1），不产生经验、
/// 不喂勋章、不重复计分；成绩仍以靶场成绩页为准，行程只引用。
String _dateText(int ms) {
  final d = DateTime.fromMillisecondsSinceEpoch(ms);
  return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

class RangeTripScreen extends StatefulWidget {
  const RangeTripScreen({super.key});

  @override
  State<RangeTripScreen> createState() => _RangeTripScreenState();
}

class _RangeTripScreenState extends State<RangeTripScreen> {
  static const _prefsChannel = MethodChannel('gunsmap/prefs');
  static const _tripsKey = 'range_trips_v1';
  final _trips = <RangeTrip>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final raw = await _prefsChannel
          .invokeMethod<String>('getString', {'key': _tripsKey})
          .timeout(const Duration(seconds: 2));
      if (raw != null && raw.isNotEmpty && mounted) {
        final list = (jsonDecode(raw) as List)
            .map((e) => RangeTrip.fromJson(e as Map<String, dynamic>))
            .toList();
        list.sort((a, b) => b.dateMs.compareTo(a.dateMs));
        setState(() {
          _trips
            ..clear()
            ..addAll(list);
        });
      }
    } catch (e) {
      appLog('prefs', '靶场行程读取失败：$e');
    }
  }

  void _save() {
    try {
      _prefsChannel.invokeMethod('setString', {
        'key': _tripsKey,
        'value': jsonEncode(_trips.map((e) => e.toJson()).toList()),
      });
    } catch (e) {
      appLog('prefs', '靶场行程保存失败：$e');
    }
  }

  Future<void> _openAdd() async {
    final result = await Navigator.push<RangeTrip>(
      context,
      MaterialPageRoute(builder: (_) => const RangeTripAddPage()),
    );
    if (result != null && mounted) {
      setState(() {
        _trips.insert(0, result);
        _trips.sort((a, b) => b.dateMs.compareTo(a.dateMs));
      });
      _save();
      showAppToast(context, tr('chrono_saved'));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: localeNotifier,
      builder: (_, __, ___) => Scaffold(
        appBar: SubPageAppBar(title: tr('trip_title')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(tr('trip_note'),
                style: const TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _openAdd,
              icon: const Icon(Icons.add_outlined, size: 18),
              label: Text(tr('trip_add')),
            ),
            const SizedBox(height: 8),
            if (_trips.isEmpty)
              Text(tr('trip_list_empty'),
                  style: const TextStyle(color: Colors.grey))
            else
              ..._trips.map((t) => Card(
                    child: ListTile(
                      title: Text(
                          '${_dateText(t.dateMs)}${t.place.isNotEmpty ? ' · ${t.place}' : ''}'),
                      subtitle: Text(
                          '${tr('trip_guns')} ${t.gunNames.length} · ${tr('trip_scores')} ${t.scoreIds.length}'),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () {
                          setState(() => _trips.remove(t));
                          _save();
                        },
                      ),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => RangeTripDetailScreen(trip: t)),
                      ),
                    ),
                  )),
          ],
        ),
      ),
    );
  }
}

/// 行程详情：行程信息 + 被关联的成绩（按 id 从当前靶场成绩里找，
/// 已删除的成绩只计条数、不显示）。
class RangeTripDetailScreen extends StatelessWidget {
  final RangeTrip trip;
  const RangeTripDetailScreen({super.key, required this.trip});

  @override
  Widget build(BuildContext context) {
    final scores = communityStore.current?.rangeScores ?? [];
    final byId = <String, RangeScore>{};
    for (final s in scores) {
      byId[s.id] = s;
    }
    final linked = <RangeScore>[];
    var missing = 0;
    for (final id in trip.scoreIds) {
      final s = byId[id];
      if (s == null) {
        missing++;
      } else {
        linked.add(s);
      }
    }
    return ValueListenableBuilder<String>(
      valueListenable: localeNotifier,
      builder: (_, __, ___) => Scaffold(
        appBar: SubPageAppBar(title: tr('trip_detail')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(_dateText(trip.dateMs),
                style:
                    const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            if (trip.place.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(trip.place),
            ],
            if (trip.gunNames.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('${tr('trip_guns')}：${trip.gunNames.join('、')}'),
            ],
            if (trip.ammoNote.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('${tr('trip_ammo')}：${trip.ammoNote}'),
            ],
            if (trip.note.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(trip.note,
                  style: const TextStyle(color: Colors.grey)),
            ],
            const SizedBox(height: 16),
            Text(tr('trip_scores'),
                style:
                    const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (linked.isEmpty && missing == 0)
              Text(tr('trip_scores_empty'),
                  style: const TextStyle(color: Colors.grey))
            else ...[
              ...linked.map((s) => Card(
                    child: ListTile(
                      title: Text('${s.gunName} · ${s.distance} 米'),
                      subtitle: Text(
                          '${s.shots} 发 · 分组 ${s.groupSize.toStringAsFixed(1)} 厘米${s.score.isNotEmpty ? ' · ${s.score}' : ''}'),
                    ),
                  )),
              if (missing > 0)
                Text('$missing ${tr('trip_scores_missing')}',
                    style: const TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ],
        ),
      ),
    );
  }
}

/// 新增行程：日期 + 地点 + 带的枪（选枪加入）+ 弹药备注 +
/// 从已有靶场成绩里多选关联 + 备注。
class RangeTripAddPage extends StatefulWidget {
  const RangeTripAddPage({super.key});

  @override
  State<RangeTripAddPage> createState() => _RangeTripAddPageState();
}

class _RangeTripAddPageState extends State<RangeTripAddPage> {
  final _placeCtrl = TextEditingController();
  final _ammoCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final _guns = <String>[];
  final _scoreIds = <String>{};
  String _date = '';

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _date =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _placeCtrl.dispose();
    _ammoCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final initial = DateTime.tryParse(_date) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked == null) return;
    setState(() {
      _date =
          '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
    });
  }

  Future<void> _addGun() async {
    final gun = await showGunPickerDialog(context);
    if (gun == null || !mounted) return;
    if (!_guns.contains(gun.name)) {
      setState(() => _guns.add(gun.name));
    }
  }

  void _save() {
    final date = DateTime.tryParse(_date) ?? DateTime.now();
    Navigator.of(context).pop(RangeTrip(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      dateMs: date.millisecondsSinceEpoch,
      place: _placeCtrl.text.trim(),
      gunNames: List.of(_guns),
      ammoNote: _ammoCtrl.text.trim(),
      scoreIds: _scoreIds.toList(),
      note: _noteCtrl.text.trim(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final scores = communityStore.current?.rangeScores ?? [];
    return ValueListenableBuilder<String>(
      valueListenable: localeNotifier,
      builder: (_, __, ___) => Scaffold(
        appBar: SubPageAppBar(title: tr('trip_add')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            InkWell(
              onTap: _pickDate,
              child: InputDecorator(
                decoration:
                    InputDecoration(labelText: tr('trip_date')),
                child: Text(_date),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _placeCtrl,
              decoration:
                  InputDecoration(labelText: tr('trip_place')),
            ),
            const SizedBox(height: 12),
            Text(tr('trip_guns'),
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            OutlinedButton.icon(
              onPressed: _addGun,
              icon: const Icon(Icons.add_outlined, size: 18),
              label: Text(tr('trip_add_gun')),
            ),
            ..._guns.map((g) => ListTile(
                  dense: true,
                  title: Text(g),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20),
                    onPressed: () => setState(() => _guns.remove(g)),
                  ),
                )),
            const SizedBox(height: 12),
            TextField(
              controller: _ammoCtrl,
              decoration:
                  InputDecoration(labelText: tr('trip_ammo')),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _noteCtrl,
              decoration: InputDecoration(
                  labelText: tr('chrono_note_label')),
            ),
            const SizedBox(height: 16),
            Text(tr('trip_scores'),
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            if (scores.isEmpty)
              Text(tr('trip_scores_none'),
                  style: const TextStyle(color: Colors.grey))
            else
              ...scores.map((s) => CheckboxListTile(
                    dense: true,
                    title: Text('${s.gunName} · ${s.distance} 米'),
                    subtitle: Text(
                        '${s.shots} 发 · 分组 ${s.groupSize.toStringAsFixed(1)} 厘米'),
                    value: _scoreIds.contains(s.id),
                    onChanged: (v) {
                      setState(() {
                        if (v == true) {
                          _scoreIds.add(s.id);
                        } else {
                          _scoreIds.remove(s.id);
                        }
                      });
                    },
                  )),
            const SizedBox(height: 16),
            FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFE86A1C)),
              onPressed: _save,
              child: Text(tr('chrono_confirm_save'),
                  style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}
