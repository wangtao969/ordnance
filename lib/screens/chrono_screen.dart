import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_log.dart';
import '../chrono_data.dart';
import '../i18n.dart';
import '../widgets/app_toast.dart';
import '../widgets/app_top_bar.dart';
import '../widgets/line_chart.dart';
import 'gun_picker_dialog.dart';

/// 测速导入 + AB 存档：工具向，不用登录，纯本机记录。
/// 经 gunsmap/prefs 存本机（key chrono_sessions_v1、ab_archives_v1），重启不丢。
/// 测速只记实测速度序列与描述统计；AB 只存原文，不做任何弹道计算、
/// 不从 AB 数据重绘弹道曲线、不插值。

String _dateText(int ms) {
  final d = DateTime.fromMillisecondsSinceEpoch(ms);
  return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

String _velText(double v) =>
    v.truncateToDouble() == v ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

String _avgText(double v) => v.toStringAsFixed(1);

class ChronoScreen extends StatefulWidget {
  const ChronoScreen({super.key});

  @override
  State<ChronoScreen> createState() => _ChronoScreenState();
}

class _ChronoScreenState extends State<ChronoScreen> {
  static const _prefsChannel = MethodChannel('gunsmap/prefs');
  static const _sessionsKey = 'chrono_sessions_v1';
  static const _archivesKey = 'ab_archives_v1';
  final _sessions = <ChronoSession>[];
  final _archives = <ABArchive>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final rawSessions = await _prefsChannel
          .invokeMethod<String>('getString', {'key': _sessionsKey})
          .timeout(const Duration(seconds: 2));
      if (rawSessions != null && rawSessions.isNotEmpty && mounted) {
        final list = (jsonDecode(rawSessions) as List)
            .map((e) => ChronoSession.fromJson(e as Map<String, dynamic>))
            .toList();
        list.sort((a, b) => b.dateMs.compareTo(a.dateMs));
        setState(() {
          _sessions
            ..clear()
            ..addAll(list);
        });
      }
    } catch (e) {
      appLog('prefs', '测速记录读取失败：$e');
    }
    try {
      final rawArchives = await _prefsChannel
          .invokeMethod<String>('getString', {'key': _archivesKey})
          .timeout(const Duration(seconds: 2));
      if (rawArchives != null && rawArchives.isNotEmpty && mounted) {
        final list = (jsonDecode(rawArchives) as List)
            .map((e) => ABArchive.fromJson(e as Map<String, dynamic>))
            .toList();
        list.sort((a, b) => b.dateMs.compareTo(a.dateMs));
        setState(() {
          _archives
            ..clear()
            ..addAll(list);
        });
      }
    } catch (e) {
      appLog('prefs', 'AB 存档读取失败：$e');
    }
  }

  void _saveSessions() {
    try {
      _prefsChannel.invokeMethod('setString', {
        'key': _sessionsKey,
        'value': jsonEncode(_sessions.map((e) => e.toJson()).toList()),
      });
    } catch (e) {
      appLog('prefs', '测速记录保存失败：$e');
    }
  }

  void _saveArchives() {
    try {
      _prefsChannel.invokeMethod('setString', {
        'key': _archivesKey,
        'value': jsonEncode(_archives.map((e) => e.toJson()).toList()),
      });
    } catch (e) {
      appLog('prefs', 'AB 存档保存失败：$e');
    }
  }

  Future<void> _openCsvImport() async {
    final result = await Navigator.push<ChronoSession>(
      context,
      MaterialPageRoute(builder: (_) => const ChronoCsvImportPage()),
    );
    if (result != null && mounted) {
      setState(() {
        _sessions.insert(0, result);
        _sessions.sort((a, b) => b.dateMs.compareTo(a.dateMs));
      });
      _saveSessions();
      showAppToast(context, tr('chrono_saved'));
    }
  }

  Future<void> _openManualImport() async {
    final result = await Navigator.push<ChronoSession>(
      context,
      MaterialPageRoute(builder: (_) => const ChronoManualImportPage()),
    );
    if (result != null && mounted) {
      setState(() {
        _sessions.insert(0, result);
        _sessions.sort((a, b) => b.dateMs.compareTo(a.dateMs));
      });
      _saveSessions();
      showAppToast(context, tr('chrono_saved'));
    }
  }

  Future<void> _openAbAdd() async {
    final result = await Navigator.push<ABArchive>(
      context,
      MaterialPageRoute(builder: (_) => const ChronoAbAddPage()),
    );
    if (result != null && mounted) {
      setState(() {
        _archives.insert(0, result);
        _archives.sort((a, b) => b.dateMs.compareTo(a.dateMs));
      });
      _saveArchives();
      showAppToast(context, tr('chrono_saved'));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: localeNotifier,
      builder: (_, __, ___) => Scaffold(
        appBar: SubPageAppBar(title: tr('chrono_title')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(tr('chrono_note'),
                style: const TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 16),
            Text(tr('chrono_sessions'),
                style:
                    const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: _openCsvImport,
                  icon: const Icon(Icons.file_upload_outlined, size: 18),
                  label: Text(tr('chrono_import_csv')),
                ),
                OutlinedButton.icon(
                  onPressed: _openManualImport,
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: Text(tr('chrono_import_manual')),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_sessions.isEmpty)
              Text(tr('chrono_empty'),
                  style: const TextStyle(color: Colors.grey))
            else
              ..._sessions.map((s) => Card(
                    child: ListTile(
                      title: Text(
                          '${s.gunName} · ${_dateText(s.dateMs)}'),
                      subtitle: Text(
                          '${tr('chrono_shots')} ${s.count} · ${tr('chrono_avg')} ${_avgText(s.avg)} ${s.unit}'),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () {
                          setState(() => _sessions.remove(s));
                          _saveSessions();
                        },
                      ),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => ChronoDetailScreen(session: s)),
                      ),
                    ),
                  )),
            const SizedBox(height: 20),
            Text(tr('chrono_ab'),
                style:
                    const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _openAbAdd,
              icon: const Icon(Icons.add_outlined, size: 18),
              label: Text(tr('chrono_ab_add')),
            ),
            const SizedBox(height: 8),
            if (_archives.isEmpty)
              Text(tr('chrono_ab_empty'),
                  style: const TextStyle(color: Colors.grey))
            else
              ..._archives.map((a) => Card(
                    child: ListTile(
                      title: Text(a.title),
                      subtitle: Text(
                          '${a.gunName.isEmpty ? tr('chrono_no_gun') : a.gunName} · ${_dateText(a.dateMs)}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Chip(
                            label: Text(tr('chrono_ab_source'),
                                style: const TextStyle(fontSize: 11)),
                            visualDensity: VisualDensity.compact,
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () {
                              setState(() => _archives.remove(a));
                              _saveArchives();
                            },
                          ),
                        ],
                      ),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => ChronoAbDetailScreen(archive: a)),
                      ),
                    ),
                  )),
          ],
        ),
      ),
    );
  }
}

/// 测速详情：统计卡 + 速度折线图 + 发数速度明细。
class ChronoDetailScreen extends StatelessWidget {
  final ChronoSession session;
  const ChronoDetailScreen({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    final s = session;
    final sd = s.sd;
    return ValueListenableBuilder<String>(
      valueListenable: localeNotifier,
      builder: (_, __, ___) => Scaffold(
        appBar: SubPageAppBar(title: tr('chrono_detail')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('${s.gunName} · ${_dateText(s.dateMs)} · ${s.unit}',
                style:
                    const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            if (s.note.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(s.note, style: const TextStyle(color: Colors.grey)),
            ],
            if (s.source.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(s.source,
                  style: const TextStyle(color: Colors.grey, fontSize: 12)),
            ],
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Wrap(
                  spacing: 20,
                  runSpacing: 8,
                  children: [
                    _stat(tr('chrono_shots'), '${s.count}'),
                    _stat(tr('chrono_avg'), _avgText(s.avg)),
                    _stat(tr('chrono_sd'),
                        sd == null ? '—' : _avgText(sd)),
                    _stat(tr('chrono_es'), _velText(s.es)),
                    _stat(tr('chrono_min'), _velText(s.minV)),
                    _stat(tr('chrono_max'), _velText(s.maxV)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (s.velocities.isNotEmpty)
              VelocityLineChart(values: s.velocities, unit: s.unit),
            const SizedBox(height: 16),
            Text(tr('chrono_shot_list'),
                style:
                    const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...s.velocities.asMap().entries.map((e) => ListTile(
                  dense: true,
                  title: Text('${e.key + 1}'),
                  trailing: Text('${_velText(e.value)} ${s.unit}'),
                )),
          ],
        ),
      ),
    );
  }

  Widget _stat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(color: Colors.grey, fontSize: 12)),
        Text(value,
            style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

/// 预览确认页：导入保存前必经的一步，显示解析出的发数、平均与跳过行数。
class ChronoPreviewPage extends StatelessWidget {
  final ChronoSession draft;
  final int skippedNonNumeric;
  final int skippedOutOfRange;
  const ChronoPreviewPage({
    super.key,
    required this.draft,
    this.skippedNonNumeric = 0,
    this.skippedOutOfRange = 0,
  });

  @override
  Widget build(BuildContext context) {
    final s = draft;
    final sd = s.sd;
    final skipped = skippedNonNumeric + skippedOutOfRange;
    return ValueListenableBuilder<String>(
      valueListenable: localeNotifier,
      builder: (_, __, ___) => Scaffold(
        appBar: SubPageAppBar(title: tr('chrono_preview')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('${s.gunName} · ${s.unit}',
                style:
                    const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            if (s.note.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(s.note, style: const TextStyle(color: Colors.grey)),
            ],
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Wrap(
                  spacing: 20,
                  runSpacing: 8,
                  children: [
                    _stat(tr('chrono_shots'), '${s.count}'),
                    _stat(tr('chrono_avg'), _avgText(s.avg)),
                    _stat(tr('chrono_sd'),
                        sd == null ? '—' : _avgText(sd)),
                    _stat(tr('chrono_es'), _velText(s.es)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              skipped > 0
                  ? '${tr('chrono_skipped')} $skipped'
                      '（${tr('chrono_skipped_nonnum')} $skippedNonNumeric'
                      ' · ${tr('chrono_skipped_range')} $skippedOutOfRange）'
                  : '${tr('chrono_skipped')} 0',
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
            if (s.velocities.isNotEmpty) ...[
              const SizedBox(height: 12),
              VelocityLineChart(
                  values: s.velocities, unit: s.unit, height: 180),
            ],
            const SizedBox(height: 16),
            FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFE86A1C)),
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(tr('chrono_confirm_save'),
                  style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(color: Colors.grey, fontSize: 12)),
        Text(value,
            style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

/// 粘贴 CSV 导入：选枪 + 单位 + 粘贴文本 + 备注，解析后进预览确认页。
class ChronoCsvImportPage extends StatefulWidget {
  const ChronoCsvImportPage({super.key});

  @override
  State<ChronoCsvImportPage> createState() => _ChronoCsvImportPageState();
}

class _ChronoCsvImportPageState extends State<ChronoCsvImportPage> {
  final _csvCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  String _gunName = '';
  String _unit = 'fps';

  @override
  void dispose() {
    _csvCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickGun() async {
    final gun = await showGunPickerDialog(context);
    if (gun == null || !mounted) return;
    setState(() => _gunName = gun.name);
  }

  Future<void> _preview() async {
    if (_gunName.isEmpty) {
      showAppToast(context, tr('chrono_need_gun'));
      return;
    }
    final result = parseChronoCsv(_csvCtrl.text);
    if (result.velocities.isEmpty) {
      showAppToast(context, tr('chrono_err_nodata'));
      return;
    }
    final draft = ChronoSession(
      id: chronoNewId(),
      gunName: _gunName,
      dateMs: DateTime.now().millisecondsSinceEpoch,
      velocities: result.velocities,
      unit: _unit,
      note: _noteCtrl.text.trim(),
      source: tr('chrono_source_csv'),
    );
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
          builder: (_) => ChronoPreviewPage(
                draft: draft,
                skippedNonNumeric: result.skippedNonNumeric,
                skippedOutOfRange: result.skippedOutOfRange,
              )),
    );
    if (ok == true && mounted) Navigator.of(context).pop(draft);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: localeNotifier,
      builder: (_, __, ___) => Scaffold(
        appBar: SubPageAppBar(title: tr('chrono_import_csv')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            OutlinedButton.icon(
              onPressed: _pickGun,
              icon: const Icon(Icons.sports_outlined, size: 18),
              label: Text(_gunName.isEmpty
                  ? tr('chrono_pick_gun')
                  : _gunName),
            ),
            const SizedBox(height: 12),
            Text(tr('chrono_unit'),
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              children: ['fps', 'm/s']
                  .map((u) => ChoiceChip(
                        label: Text(u),
                        selected: _unit == u,
                        onSelected: (_) => setState(() => _unit = u),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _csvCtrl,
              maxLines: 12,
              decoration:
                  InputDecoration(labelText: tr('chrono_paste_hint')),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _noteCtrl,
              decoration:
                  InputDecoration(labelText: tr('chrono_note_label')),
            ),
            const SizedBox(height: 16),
            FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFE86A1C)),
              onPressed: _preview,
              child: Text(tr('chrono_preview'),
                  style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}

/// 手动逐条录入：选枪 + 单位 + 一条一条加速度，凑齐后进预览确认页。
class ChronoManualImportPage extends StatefulWidget {
  const ChronoManualImportPage({super.key});

  @override
  State<ChronoManualImportPage> createState() =>
      _ChronoManualImportPageState();
}

class _ChronoManualImportPageState extends State<ChronoManualImportPage> {
  final _velCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final _values = <double>[];
  String _gunName = '';
  String _unit = 'fps';

  @override
  void dispose() {
    _velCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickGun() async {
    final gun = await showGunPickerDialog(context);
    if (gun == null || !mounted) return;
    setState(() => _gunName = gun.name);
  }

  void _addValue() {
    final v = double.tryParse(_velCtrl.text.trim());
    if (v == null || v < 50 || v > 5000) {
      showAppToast(context, tr('chrono_err_velocity'));
      return;
    }
    setState(() {
      _values.add(v);
      _velCtrl.clear();
    });
  }

  Future<void> _preview() async {
    if (_gunName.isEmpty) {
      showAppToast(context, tr('chrono_need_gun'));
      return;
    }
    if (_values.isEmpty) {
      showAppToast(context, tr('chrono_err_empty'));
      return;
    }
    final draft = ChronoSession(
      id: chronoNewId(),
      gunName: _gunName,
      dateMs: DateTime.now().millisecondsSinceEpoch,
      velocities: List.of(_values),
      unit: _unit,
      note: _noteCtrl.text.trim(),
      source: tr('chrono_source_manual'),
    );
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
          builder: (_) => ChronoPreviewPage(draft: draft)),
    );
    if (ok == true && mounted) Navigator.of(context).pop(draft);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: localeNotifier,
      builder: (_, __, ___) => Scaffold(
        appBar: SubPageAppBar(title: tr('chrono_import_manual')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            OutlinedButton.icon(
              onPressed: _pickGun,
              icon: const Icon(Icons.sports_outlined, size: 18),
              label: Text(_gunName.isEmpty
                  ? tr('chrono_pick_gun')
                  : _gunName),
            ),
            const SizedBox(height: 12),
            Text(tr('chrono_unit'),
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              children: ['fps', 'm/s']
                  .map((u) => ChoiceChip(
                        label: Text(u),
                        selected: _unit == u,
                        onSelected: (_) => setState(() => _unit = u),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _velCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                        labelText: tr('chrono_manual_hint')),
                    onSubmitted: (_) => _addValue(),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFE86A1C)),
                  onPressed: _addValue,
                  child: Text(tr('chrono_add'),
                      style: const TextStyle(color: Colors.white)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ..._values.asMap().entries.map((e) => ListTile(
                  dense: true,
                  title: Text('${e.key + 1}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('${_velText(e.value)} $_unit'),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 20),
                        onPressed: () =>
                            setState(() => _values.removeAt(e.key)),
                      ),
                    ],
                  ),
                )),
            const SizedBox(height: 8),
            TextField(
              controller: _noteCtrl,
              decoration:
                  InputDecoration(labelText: tr('chrono_note_label')),
            ),
            const SizedBox(height: 16),
            FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFE86A1C)),
              onPressed: _preview,
              child: Text(tr('chrono_preview'),
                  style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}

/// AB 存档新增：标题 + 可选绑枪 + 原文粘贴，界面明确标注“AB Quantum 导出”。
class ChronoAbAddPage extends StatefulWidget {
  const ChronoAbAddPage({super.key});

  @override
  State<ChronoAbAddPage> createState() => _ChronoAbAddPageState();
}

class _ChronoAbAddPageState extends State<ChronoAbAddPage> {
  final _titleCtrl = TextEditingController();
  final _rawCtrl = TextEditingController();
  String _gunName = '';

  @override
  void dispose() {
    _titleCtrl.dispose();
    _rawCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickGun() async {
    final gun = await showGunPickerDialog(context);
    if (gun == null || !mounted) return;
    setState(() => _gunName = gun.name);
  }

  void _save() {
    final title = _titleCtrl.text.trim();
    final raw = _rawCtrl.text.trim();
    if (title.isEmpty || raw.isEmpty) {
      showAppToast(context, tr('chrono_err_title'));
      return;
    }
    Navigator.of(context).pop(ABArchive(
      id: chronoNewId(),
      title: title,
      gunName: _gunName,
      dateMs: DateTime.now().millisecondsSinceEpoch,
      rawText: raw,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: localeNotifier,
      builder: (_, __, ___) => Scaffold(
        appBar: SubPageAppBar(title: tr('chrono_ab_add')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  tr('chrono_ab_source'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _titleCtrl,
              decoration:
                  InputDecoration(labelText: tr('chrono_title_label')),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickGun,
                    icon: const Icon(Icons.sports_outlined, size: 18),
                    label: Text(_gunName.isEmpty
                        ? tr('chrono_gun_optional')
                        : _gunName),
                  ),
                ),
                if (_gunName.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () => setState(() => _gunName = ''),
                    child: Text(tr('chrono_no_gun')),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _rawCtrl,
              maxLines: 16,
              decoration:
                  InputDecoration(labelText: tr('chrono_raw')),
            ),
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

/// AB 存档详情：原文原样展示，不解析、不计算。
class ChronoAbDetailScreen extends StatelessWidget {
  final ABArchive archive;
  const ChronoAbDetailScreen({super.key, required this.archive});

  @override
  Widget build(BuildContext context) {
    final a = archive;
    return ValueListenableBuilder<String>(
      valueListenable: localeNotifier,
      builder: (_, __, ___) => Scaffold(
        appBar: SubPageAppBar(title: a.title),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Chip(
              label: Text(tr('chrono_ab_source')),
              visualDensity: VisualDensity.compact,
            ),
            const SizedBox(height: 8),
            Text(
                '${a.gunName.isEmpty ? tr('chrono_no_gun') : a.gunName} · ${_dateText(a.dateMs)}',
                style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 12),
            SelectableText(a.rawText),
          ],
        ),
      ),
    );
  }
}
