import 'package:flutter/material.dart';

import '../ballistic_store.dart';
import '../i18n.dart';
import '../models.dart';
import '../widgets/app_top_bar.dart';
import 'gun_picker_dialog.dart';

/// 弹道档案工具页（2.2.5）：只存数据、不做任何弹道计算。
/// Sg 只显示导入或用户填写的值，本页与 App 内任何地方都不计算 Sg；
/// 不画弹道曲线、不做风偏与落点推算。
class BallisticProfileScreen extends StatefulWidget {
  const BallisticProfileScreen({super.key});

  @override
  State<BallisticProfileScreen> createState() =>
      _BallisticProfileScreenState();
}

class _BallisticProfileScreenState extends State<BallisticProfileScreen> {
  List<BallisticProfile> _profiles = [];
  BallisticProfile? _editing;
  var _editingIsNew = false;
  var _dragModel = '';
  var _twistDirection = '';
  var _importMsg = '';

  final _diameter = TextEditingController();
  final _weight = TextEditingController();
  final _bc = TextEditingController();
  final _customDrag = TextEditingController();
  final _bulletLength = TextEditingController();
  final _mv = TextEditingController();
  final _zero = TextEditingController();
  final _sightHeight = TextEditingController();
  final _twist = TextEditingController();
  final _sg = TextEditingController();
  final _importCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    loadBallisticProfiles().then((v) {
      if (mounted) setState(() => _profiles = v);
    });
  }

  @override
  void dispose() {
    for (final c in [
      _diameter,
      _weight,
      _bc,
      _customDrag,
      _bulletLength,
      _mv,
      _zero,
      _sightHeight,
      _twist,
      _sg,
      _importCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _openEditor(BallisticProfile? p) {
    final target = p == null
        ? BallisticProfile(
            id: DateTime.now().microsecondsSinceEpoch.toString())
        : BallisticProfile.fromJson(p.toJson());
    setState(() {
      _editing = target;
      _editingIsNew = p == null;
      _dragModel = target.dragModel;
      _twistDirection = target.twistDirection;
      _importMsg = '';
      _importCtrl.clear();
      _diameter.text = target.diameterIn;
      _weight.text = target.bulletWeightGr;
      _bc.text = target.bc;
      _customDrag.text = target.customDrag;
      _bulletLength.text = target.bulletLengthIn;
      _mv.text = target.muzzleVelocityFps;
      _zero.text = target.zeroDistanceY;
      _sightHeight.text = target.sightHeightIn;
      _twist.text = target.twistIn;
      _sg.text = target.sg;
    });
  }

  Future<void> _save() async {
    final p = _editing;
    if (p == null) return;
    p.dragModel = _dragModel;
    p.twistDirection = _twistDirection;
    p.diameterIn = _diameter.text.trim();
    p.bulletWeightGr = _weight.text.trim();
    p.bc = _bc.text.trim();
    p.customDrag = _customDrag.text.trim();
    p.bulletLengthIn = _bulletLength.text.trim();
    p.muzzleVelocityFps = _mv.text.trim();
    p.zeroDistanceY = _zero.text.trim();
    p.sightHeightIn = _sightHeight.text.trim();
    p.twistIn = _twist.text.trim();
    p.sg = _sg.text.trim();
    final idx = _profiles.indexWhere((e) => e.id == p.id);
    if (idx >= 0) {
      _profiles[idx] = p;
    } else {
      _profiles.add(p);
    }
    await saveBallisticProfiles(_profiles);
    if (mounted) setState(() => _editing = null);
  }

  Future<void> _delete() async {
    final p = _editing;
    if (p == null) return;
    _profiles.removeWhere((e) => e.id == p.id);
    await saveBallisticProfiles(_profiles);
    if (mounted) setState(() => _editing = null);
  }

  void _import() {
    final parsed = parseAbExport(_importCtrl.text);
    final ctrls = <String, TextEditingController>{
      'diameterIn': _diameter,
      'bulletWeightGr': _weight,
      'bc': _bc,
      'customDrag': _customDrag,
      'bulletLengthIn': _bulletLength,
      'muzzleVelocityFps': _mv,
      'zeroDistanceY': _zero,
      'sightHeightIn': _sightHeight,
      'twistIn': _twist,
      'sg': _sg,
    };
    var n = 0;
    for (final e in parsed.entries) {
      final c = ctrls[e.key];
      if (c != null) {
        c.text = e.value;
        n++;
      }
    }
    if (parsed.containsKey('dragModel')) {
      _dragModel = parsed['dragModel']!;
      n++;
    }
    if (parsed.containsKey('twistDirection')) {
      _twistDirection = parsed['twistDirection']!;
      n++;
    }
    setState(() {
      _importMsg =
          '${tr('ballistic_import_done_prefix')}$n${tr('ballistic_import_done_suffix')}';
    });
  }

  @override
  Widget build(BuildContext context) {
    final editing = _editing;
    return ValueListenableBuilder<String>(
      valueListenable: localeNotifier,
      builder: (_, __, ___) => Scaffold(
        appBar: SubPageAppBar(title: tr('ballistic_profile')),
        floatingActionButton: editing == null
            ? FloatingActionButton(
                onPressed: () => _openEditor(null),
                child: const Icon(Icons.add),
              )
            : null,
        body: editing == null ? _listView() : _editorView(editing),
      ),
    );
  }

  Widget _listView() {
    if (_profiles.isEmpty) {
      return Center(child: Text(tr('ballistic_no_profile')));
    }
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        for (final p in _profiles)
          Card(
            child: ListTile(
              title: Text(p.gunName.isEmpty ? '—' : p.gunName),
              subtitle: Text([
                if (p.dragModel.isNotEmpty) p.dragModel,
                if (p.bc.isNotEmpty) 'BC ${p.bc}',
                if (p.muzzleVelocityFps.isNotEmpty)
                  '${p.muzzleVelocityFps} fps',
                if (p.zeroDistanceY.isNotEmpty) '${p.zeroDistanceY} y',
              ].join(' · ')),
              onTap: () => _openEditor(p),
            ),
          ),
      ],
    );
  }

  Widget _numField(String labelKey, TextEditingController ctrl) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: TextField(
          controller: ctrl,
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: tr(labelKey),
            border: const OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(12))),
          ),
        ),
      );

  Widget _dropRow(
      String labelKey, String value, List<String> options, ValueChanged<String> onChanged) =>
      ListTile(
        title: Text(tr(labelKey)),
        trailing: DropdownButton<String>(
          value: value,
          items: options
              .map((o) => DropdownMenuItem(
                  value: o, child: Text(o.isEmpty ? '—' : o)))
              .toList(),
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      );

  Widget _editorView(BallisticProfile p) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(tr('ballistic_bullet'),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        _dropRow('ballistic_drag_model', _dragModel, ['', 'G1', 'G7'],
            (v) => setState(() => _dragModel = v)),
        _numField('ballistic_diameter', _diameter),
        _numField('ballistic_weight', _weight),
        _numField('ballistic_bc', _bc),
        _numField('ballistic_custom_drag', _customDrag),
        _numField('ballistic_bullet_length', _bulletLength),
        const SizedBox(height: 16),
        Text(tr('ballistic_rifle'),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        _numField('ballistic_mv', _mv),
        _numField('ballistic_zero', _zero),
        _numField('ballistic_sight_height', _sightHeight),
        _numField('ballistic_twist', _twist),
        _dropRow('ballistic_twist_dir', _twistDirection, ['', 'L', 'R'],
            (v) => setState(() => _twistDirection = v)),
        _numField('ballistic_sg', _sg),
        Text(tr('ballistic_sg_note'),
            style: const TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: () async {
            final gun = await showGunPickerDialog(context);
            if (gun != null) setState(() => p.gunName = gun.name);
          },
          icon: const Icon(Icons.search, size: 18),
          label: Text(
              p.gunName.isEmpty ? tr('ballistic_bind_gun') : p.gunName),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _importCtrl,
          minLines: 3,
          maxLines: 8,
          decoration: InputDecoration(
            hintText: tr('ballistic_import_hint'),
            border: const OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(12))),
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _import,
          icon: const Icon(Icons.file_download_outlined, size: 18),
          label: Text(tr('ballistic_import')),
        ),
        if (_importMsg.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(_importMsg,
                style: const TextStyle(color: Colors.grey, fontSize: 12)),
          ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: _save,
                child: Text(tr('ballistic_save')),
              ),
            ),
            if (!_editingIsNew) ...[
              const SizedBox(width: 8),
              TextButton(
                onPressed: _delete,
                child: Text(tr('ballistic_delete'),
                    style: const TextStyle(color: Colors.red)),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
