import 'package:flutter/material.dart';
import '../ballistic_store.dart';
import '../gun_setup_data.dart';
import '../data.dart';
import '../english_terms.dart';
import '../haptics.dart';
import '../i18n.dart';
import '../models.dart';
import '../widgets/app_toast.dart';
import '../widgets/parametric_silhouette.dart';
import '../widgets/family_diagram.dart';
import '../widgets/app_top_bar.dart';
import 'gun_compare_screen.dart';
import 'dope_screen.dart';

class GunDetailScreen extends StatefulWidget {
  final Gun gun;
  const GunDetailScreen({super.key, required this.gun});

  @override
  State<GunDetailScreen> createState() => _GunDetailScreenState();
}

class _GunDetailScreenState extends State<GunDetailScreen> {
  final Set<String> _assembled = {};
  late final Future<List<BallisticProfile>> _profilesFuture;
  Future<Map<String, GunSetup>> _setupFuture = loadGunSetups();

  @override
  void initState() {
    super.initState();
    _profilesFuture = loadBallisticProfiles();
  }

  /// 编辑个人配置：四项全是用户自填，空=未填；保存后只写 gun_setup_v1。
  Future<void> _editSetup() async {
    final setups = await loadGunSetups();
    final cur = setups[widget.gun.name] ?? GunSetup();
    final vCtrl = TextEditingController(text: cur.velocity);
    final zCtrl = TextEditingController(text: cur.zeroDistance);
    final sCtrl = TextEditingController(text: cur.sightHeight);
    final sgCtrl = TextEditingController(text: cur.sg);
    final saved = await showDialog<bool>(
      context: context,
      builder: (dctx) => AlertDialog(
        title: Text(tr('gun_data_edit')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: vCtrl,
              decoration: InputDecoration(labelText: tr('gun_data_velocity')),
            ),
            TextField(
              controller: zCtrl,
              decoration: InputDecoration(labelText: tr('gun_data_zero')),
            ),
            TextField(
              controller: sCtrl,
              decoration: InputDecoration(labelText: tr('gun_data_sight')),
            ),
            TextField(
              controller: sgCtrl,
              decoration: InputDecoration(labelText: tr('gun_data_sg')),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dctx).pop(false),
            child: Text(tr('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.of(dctx).pop(true),
            child: Text(tr('save')),
          ),
        ],
      ),
    );
    if (saved == true && mounted) {
      setups[widget.gun.name] = GunSetup(
        velocity: vCtrl.text.trim(),
        zeroDistance: zCtrl.text.trim(),
        sightHeight: sCtrl.text.trim(),
        sg: sgCtrl.text.trim(),
      );
      await saveGunSetups(setups);
      setState(() => _setupFuture = Future.value(setups));
      showAppToast(context, tr('gun_data_saved'));
    }
    vCtrl.dispose();
    zCtrl.dispose();
    sCtrl.dispose();
    sgCtrl.dispose();
  }

  static List<(String, String, double, double)> _hotspots() => [
        (tr('detail_hot_muzzle'), tr('detail_hot_muzzle_desc'), 0.08, 0.42),
        (tr('detail_hot_sight'), tr('detail_hot_sight_desc'), 0.38, 0.18),
        (tr('detail_hot_mag'), tr('detail_hot_mag_desc'), 0.45, 0.62),
        (tr('detail_hot_trigger'), tr('detail_hot_trigger_desc'), 0.55, 0.55),
        (tr('detail_hot_stock'), tr('detail_hot_stock_desc'), 0.88, 0.45),
      ];

  @override
  Widget build(BuildContext context) {
    final gun = widget.gun;
    // 图区三层：实物照片 > 族系识别图 > 参数化轮廓。
    final diagramKey = familyDiagramOf(gun);
    // 英文界面显示英文版族系名与识别要点（与中文表同 key）。
    final diagramInfo = diagramKey == null
        ? null
        : (localeNotifier.value == localeEn
            ? familyDiagramInfoEn[diagramKey]
            : familyDiagramInfo[diagramKey]);
    return Scaffold(
      appBar: SubPageAppBar(title: gunDisplayName(gun)),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          // 图区：静态展示，热点可点看部位说明
          Container(
            height: 220,
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.black
                  : const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Stack(
              children: [
                Center(
                  child: gun.image != null
                        ? Image.asset(gun.image!, fit: BoxFit.contain)
                        : diagramKey != null
                            ? FamilyDiagram(
                                family: diagramKey,
                                width: MediaQuery.of(context).size.width -
                                    72,
                                height:
                                    (MediaQuery.of(context).size.width -
                                            72) *
                                        0.5,
                              )
                            : ParametricSilhouette(
                                gun: gun,
                                width: MediaQuery.of(context).size.width -
                                    72,
                                height:
                                    (MediaQuery.of(context).size.width -
                                            72) *
                                        0.44,
                              ),
                ),
                for (final h in _hotspots())
                  Positioned(
                    left: MediaQuery.of(context).size.width * h.$3 - 14,
                    top: 220 * h.$4 - 14,
                    child: GestureDetector(
                      onTap: () => showDialog(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: Text(h.$1),
                          content: Text(h.$2),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: Text(tr('got_it')),
                            ),
                          ],
                        ),
                      ),
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: const BoxDecoration(
                          color: Colors.amber,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.add,
                            size: 18, color: Colors.black),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          if (gun.image == null)
            if (diagramInfo != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tr('detail_family_prefix') + diagramInfo.$1 + tr('detail_family_suffix'),
                      style:
                          const TextStyle(color: Colors.grey, fontSize: 12)),
                  for (final p in diagramInfo.$2)
                    Text('· $p',
                        style: const TextStyle(
                            color: Colors.grey, fontSize: 12)),
                ],
              )
            else
              Text(
                  tr('detail_no_photo_note'),
                  style: TextStyle(color: Colors.grey, fontSize: 12)),
          if (_assembled.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Wrap(
                spacing: 6,
                children: _assembled
                    .map((a) => Chip(
                        label: Text(
                            '${tr('assembled_prefix')}${accessoryDisplay(a)}'),
                        backgroundColor: Colors.amber.withOpacity(0.2)))
                    .toList(),
              ),
            ),
          const SizedBox(height: 12),
          Text(gunDisplayName(gun),
              style:
                  const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          Text('${vendorDisplay(gun.vendor)} · ${gun.caliber}',
              style: const TextStyle(color: Colors.grey, fontSize: 16)),
          Text(gun.name,
              style: const TextStyle(color: Colors.grey, fontSize: 14)),
          if (gun.price != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(tr('detail_price_prefix') + '${gun.price}' + tr('detail_price_suffix'),
                  style: const TextStyle(color: Colors.grey, fontSize: 14)),
            ),
          const SizedBox(height: 12),
          Text(tr('params'),
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          _spec('Caliber', gun.caliber),
          _spec('Action', actionDisplay(gun.action)),
          _spec('Barrel', gun.barrel),
          _spec('Overall Length', gun.length),
          _spec('Weight', gun.weight),
          _spec('Capacity', gun.capacity),
          _spec('Origin', originDisplay(gun.origin)),
          _spec('Year', gun.year),
          if (gun.caliberOptions.isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                Text(tr('caliber_options'),
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                for (final o in gun.caliberOptions)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                            width: 150,
                            child: Text(o.caliber,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold))),
                        Expanded(
                            child: Text(
                                o.barrel.isEmpty
                                    ? tr('barrel_not_confirmed')
                                    : o.barrel,
                                style: o.barrel.isEmpty
                                    ? const TextStyle(color: Colors.grey)
                                    : null)),
                      ],
                    ),
                  ),
              ],
            ),
          const SizedBox(height: 12),
          Text(tr('gun_data_title'),
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          _spec(tr('gun_data_twist'),
              gun.twist.isEmpty ? tr('gun_data_not_listed') : gun.twist),
          _spec(tr('gun_data_twist_dir'),
              gun.twistDir.isEmpty ? tr('gun_data_not_listed') : gun.twistDir),
          FutureBuilder<Map<String, GunSetup>>(
            future: _setupFuture,
            builder: (_, snap) {
              final setup = snap.data?[gun.name] ?? GunSetup();
              String show(String v) =>
                  v.isEmpty ? tr('gun_data_empty') : v;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _spec(tr('gun_data_velocity'), show(setup.velocity)),
                  _spec(tr('gun_data_zero'), show(setup.zeroDistance)),
                  _spec(tr('gun_data_sight'), show(setup.sightHeight)),
                  _spec(tr('gun_data_sg'), show(setup.sg)),
                  const SizedBox(height: 4),
                  OutlinedButton(
                    onPressed: _editSetup,
                    child: Text(tr('gun_data_edit')),
                  ),
                ],
              );
            },
          ),
          FutureBuilder<List<BallisticProfile>>(
            future: _profilesFuture,
            builder: (_, snap) {
              if (!snap.hasData) return const SizedBox.shrink();
              BallisticProfile? bound;
              for (final p in snap.data!) {
                if (p.gunName == gun.name) {
                  bound = p;
                  break;
                }
              }
              if (bound == null) return const SizedBox.shrink();
              final b = bound;
              final rows = <(String, String)>[];
              if (b.dragModel.isNotEmpty) {
                rows.add((tr('ballistic_drag_model'), b.dragModel));
              }
              if (b.bc.isNotEmpty) rows.add((tr('ballistic_bc'), b.bc));
              if (b.muzzleVelocityFps.isNotEmpty) {
                rows.add(
                    (tr('ballistic_mv'), '${b.muzzleVelocityFps} fps'));
              }
              if (b.zeroDistanceY.isNotEmpty) {
                rows.add((tr('ballistic_zero'), '${b.zeroDistanceY} y'));
              }
              if (b.twistIn.isNotEmpty) {
                rows.add((tr('ballistic_twist'),
                    '${b.twistIn}″${b.twistDirection.isEmpty ? '' : ' ${b.twistDirection}'}'));
              }
              if (b.sg.isNotEmpty) rows.add((tr('ballistic_sg'), b.sg));
              if (rows.isEmpty) return const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),
                  Text(tr('ballistic_summary'),
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  for (final r in rows) _spec(r.$1, r.$2),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => GunCompareScreen(initialGun: gun),
              ),
            ),
            icon: const Icon(Icons.compare_arrows, size: 18),
            label: Text(tr('detail_compare')),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => DopeScreen(gun: gun),
              ),
            ),
            icon: const Icon(Icons.book_outlined, size: 18),
            label: Text(tr('tool_dope')),
          ),
          const SizedBox(height: 12),
          Text(tr('intro'),
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          // 英文界面显示英文简介（空时回落中文简介）。
          Text(localeNotifier.value == localeEn &&
                  gun.descriptionEn.isNotEmpty
              ? gun.descriptionEn
              : gun.description),
          const SizedBox(height: 12),
          Text(tr('ammo_fit'),
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          Wrap(
            spacing: 6,
            children:
                gun.ammo.map((a) => Chip(label: Text(a))).toList(),
          ),
          const SizedBox(height: 12),
          Builder(
            builder: (context) {
              // 工厂弹售价：按本枪适配弹药口径，从口径图鉴取已核实的参考价。
              final priced = <({String caliber, String price})>[];
              for (final a in gun.ammo) {
                for (final c in caliberInfos) {
                  if (c.caliber == a && c.factoryPrice != null) {
                    priced.add((caliber: a, price: c.factoryPrice!));
                  }
                }
              }
              if (priced.isEmpty) return const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tr('factory_price'),
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  ...priced.map((p) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                                width: 110,
                                child: Text(p.caliber,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold))),
                            Expanded(child: Text(p.price)),
                          ],
                        ),
                      )),
                  Text(tr('detail_price_note'),
                      style: TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          Text(tr('accessories_pick'),
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ...gun.accessories.map((a) => ListTile(
                title: Text(accessoryDisplay(a)),
                trailing: _assembled.contains(a)
                    ? Text(tr('assembled'), style: TextStyle(color: Colors.amber))
                    : TextButton(
                        onPressed: () =>
                            setState(() => _assembled.add(a)),
                        child: Text(tr('preview')),
                      ),
                onTap: () {
                  tapHaptic();
                  setState(() {
                    if (_assembled.contains(a)) {
                      _assembled.remove(a);
                    } else {
                      _assembled.add(a);
                    }
                  });
                },
              )),
        ],
      ),
    );
  }

  Widget _spec(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            SizedBox(
                width: 80,
                child: Text(k, style: const TextStyle(color: Colors.grey))),
            Expanded(child: Text(v)),
          ],
        ),
      );
}
