import 'package:flutter/material.dart';
import '../i18n.dart';
import '../tools_units.dart';

/// 归零助手算完要记卡时带给数据本的值：距离一律是米，方向是
/// 实际要拧的方向（向左/向右/向上/向下），没偏移的方向记不动、0 格。
class ZeroRecordInput {
  final int distanceM;
  final String hDir;
  final int hClicks;
  final String vDir;
  final int vClicks;
  const ZeroRecordInput({
    required this.distanceM,
    required this.hDir,
    required this.hClicks,
    required this.vDir,
    required this.vClicks,
  });
}

/// 归零助手卡：填距离与弹着中心偏移，出“往哪边拧几格”；
/// 结论出来后可一键把这次归零交给数据本记卡。只算输入的数，
/// 不画弹道；方向按光学瞄具通用规则，以瞄具说明书为准。
/// 本卡不持久化输入——记下来的卡就是 persistence，算完不记就丢。
class ZeroAssistantCard extends StatefulWidget {
  final void Function(ZeroRecordInput input) onRecord;
  const ZeroAssistantCard({super.key, required this.onRecord});

  @override
  State<ZeroAssistantCard> createState() => _ZeroAssistantCardState();
}

class _ZeroAssistantCardState extends State<ZeroAssistantCard> {
  final _distCtrl = TextEditingController(text: '100');
  final _hDevCtrl = TextEditingController();
  final _vDevCtrl = TextEditingController();
  String _clickUnit = '1/4 MOA';
  String _hDir = '偏左';
  String _vDir = '偏高';

  @override
  void dispose() {
    _distCtrl.dispose();
    _hDevCtrl.dispose();
    _vDevCtrl.dispose();
    super.dispose();
  }

  String _fmt(double v, [int digits = 2]) {
    var s = v.toStringAsFixed(digits);
    while (s.contains('.') && s.endsWith('0')) {
      s = s.substring(0, s.length - 1);
    }
    if (s.endsWith('.')) s = s.substring(0, s.length - 1);
    return s;
  }

  @override
  Widget build(BuildContext context) {
    final metric = isMetricUnits;
    final distM = (double.tryParse(_distCtrl.text) ?? 0) *
        (metric ? 1 : 0.9144);
    final hDev = (double.tryParse(_hDevCtrl.text) ?? 0) *
        (metric ? 1 : 2.54);
    final vDev = (double.tryParse(_vDevCtrl.text) ?? 0) *
        (metric ? 1 : 2.54);

    double perClickMoa;
    double perClickMrad;
    if (_clickUnit == '1/4 MOA') {
      perClickMoa = 0.25;
      perClickMrad = 0;
    } else if (_clickUnit == '1/2 MOA') {
      perClickMoa = 0.5;
      perClickMrad = 0;
    } else if (_clickUnit == '1 MOA') {
      perClickMoa = 1.0;
      perClickMrad = 0;
    } else {
      perClickMoa = 0;
      perClickMrad = 0.1;
    }
    final perClickCm = distM > 0
        ? (perClickMoa > 0
            ? perClickMoa * distM * 0.02909
            : perClickMrad * distM * 0.1)
        : 0.0;
    double clicks(double devCm) {
      if (distM <= 0 || perClickCm <= 0) return 0;
      return devCm / perClickCm;
    }

    final hExact = clicks(hDev);
    final vExact = clicks(vDev);
    final hRounded = hExact.round();
    final vRounded = vExact.round();
    final hTurn = _hDir == '偏左' ? '向右' : '向左';
    final vTurn = _vDir == '偏高' ? '向下' : '向上';
    final hasResult = distM > 0 && (hDev > 0 || vDev > 0);
    String dirLabel(String v) {
      switch (v) {
        case '偏左':
          return tr('zero_dev_left');
        case '偏右':
          return tr('zero_dev_right');
        case '偏高':
          return tr('zero_dev_high');
        case '偏低':
          return tr('zero_dev_low');
        case '向左':
          return tr('zero_dir_left');
        case '向右':
          return tr('zero_dir_right');
        case '向上':
          return tr('zero_dir_up');
        case '向下':
          return tr('zero_dir_down');
        default:
          return v;
      }
    }

    Widget dirChips(String value, List<String> options,
        ValueChanged<String> onPick) {
      return Wrap(
        spacing: 6,
        children: options
            .map((o) => ChoiceChip(
                  label: Text(dirLabel(o)),
                  selected: value == o,
                  onSelected: (_) => setState(() => onPick(o)),
                ))
            .toList(),
      );
    }

    Widget numberField(TextEditingController c, String label) {
      return TextField(
        controller: c,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(12))),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tr('zero_title'),
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            numberField(
                _distCtrl, metric ? tr('zero_dist_m') : tr('zero_dist_yd')),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              children: ['50', '100', '200', '300']
                  .map((d) => ActionChip(
                        label: Text('$d' + (metric ? tr('range_unit_m') : tr('range_unit_yd'))),
                        onPressed: () => setState(() => _distCtrl.text = d),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 12),
            Text(tr('zero_h_offset_title'),
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            dirChips(_hDir, const ['偏左', '偏右'],
                (v) => setState(() => _hDir = v)),
            const SizedBox(height: 8),
            numberField(_hDevCtrl,
                metric ? tr('zero_dev_cm') : tr('zero_dev_in')),
            const SizedBox(height: 12),
            Text(tr('zero_v_offset_title'),
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            dirChips(_vDir, const ['偏高', '偏低'],
                (v) => setState(() => _vDir = v)),
            const SizedBox(height: 8),
            numberField(_vDevCtrl,
                metric ? tr('zero_dev_cm') : tr('zero_dev_in')),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(tr('zero_per_click')),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: _clickUnit,
                  items: const [
                    DropdownMenuItem(
                        value: '1/4 MOA', child: Text('1/4 MOA')),
                    DropdownMenuItem(
                        value: '1/2 MOA', child: Text('1/2 MOA')),
                    DropdownMenuItem(value: '1 MOA', child: Text('1 MOA')),
                    DropdownMenuItem(
                        value: '0.1 密位', child: Text('0.1 密位')),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _clickUnit = v);
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (hasResult) ...[
              Text(
                  (hDev > 0 ? dirLabel(hTurn) + tr('zero_turn_mid') + '$hRounded' + tr('zero_turn_suffix') : '') + (hDev > 0 && vDev > 0 ? tr('zero_turn_join') : '') + (vDev > 0 ? dirLabel(vTurn) + tr('zero_turn_mid') + '$vRounded' + tr('zero_turn_suffix') : '') + tr('zero_turn_unit_prefix') + (_clickUnit == '0.1 密位' ? tr('zero_mrad_unit') : _clickUnit) + tr('zero_turn_unit_suffix'),
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFE86A1C),
                      fontSize: 15)),
              if (hDev > 0 && (hExact - hRounded).abs() > 0.05)
                Text(
                    tr('zero_remain_h_prefix') + '${_fmt((hExact - hRounded).abs() * perClickCm)}' + tr('zero_remain_suffix'),
                    style: const TextStyle(color: Colors.grey, fontSize: 12)),
              if (vDev > 0 && (vExact - vRounded).abs() > 0.05)
                Text(
                    tr('zero_remain_v_prefix') + '${_fmt((vExact - vRounded).abs() * perClickCm)}' + tr('zero_remain_suffix'),
                    style: const TextStyle(color: Colors.grey, fontSize: 12)),
              Text(tr('zero_dir_note'),
                  style: TextStyle(color: Colors.grey, fontSize: 12)),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => widget.onRecord(ZeroRecordInput(
                  distanceM: distM.round(),
                  hDir: hDev > 0 ? hTurn : '不动',
                  hClicks: hDev > 0 ? hRounded : 0,
                  vDir: vDev > 0 ? vTurn : '不动',
                  vClicks: vDev > 0 ? vRounded : 0,
                )),
                icon: const Icon(Icons.bookmark_add_outlined, size: 18),
                label: Text(tr('zero_save_card')),
              ),
            ] else
              Text(tr('zero_empty_result'),
                  style: TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
