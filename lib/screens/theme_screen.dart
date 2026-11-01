import 'package:flutter/material.dart';

import '../haptics.dart';
import '../i18n.dart';
import '../main.dart';
import '../theme_accent.dart';
import '../widgets/app_top_bar.dart';

/// 主题页：白天/黑夜模式三选一（跟随系统、白天、夜晚，仅本次打开期间
/// 生效，与设置页原有行为一致）＋主题颜色预设（持久化，重启后保持）
/// ＋自定义颜色（色板点选 + 十六进制输入，同样走 theme_accent_v1）。
class ThemeScreen extends StatefulWidget {
  const ThemeScreen({super.key});

  @override
  State<ThemeScreen> createState() => _ThemeScreenState();
}

/// 自定义色板：16 个点选色（不含橙色系），点选即保存。
const _customSwatches = <Color>[
  Color(0xFFB71C1C),
  Color(0xFFE53935),
  Color(0xFFEC407A),
  Color(0xFF8E24AA),
  Color(0xFF5E35B1),
  Color(0xFF3949AB),
  Color(0xFF1E88E5),
  Color(0xFF039BE5),
  Color(0xFF00ACC1),
  Color(0xFF00897B),
  Color(0xFF43A047),
  Color(0xFF7CB342),
  Color(0xFFC0CA33),
  Color(0xFFFDD835),
  Color(0xFF6D4C41),
  Color(0xFF78909C),
];

class _ThemeScreenState extends State<ThemeScreen> {
  final _hexCtrl = TextEditingController();
  var _hexError = false;

  @override
  void dispose() {
    _hexCtrl.dispose();
    super.dispose();
  }

  void _applyHex() {
    final c = parseHexColor(_hexCtrl.text);
    if (c == null) {
      setState(() => _hexError = true);
    } else {
      setState(() => _hexError = false);
      saveAccent(c);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final grey = dark ? const Color(0xFF8A8578) : const Color(0xFF9A917F);
    return ValueListenableBuilder<String>(
      valueListenable: localeNotifier,
      builder: (_, __, ___) => Scaffold(
        extendBodyBehindAppBar: true,
        appBar: SubPageAppBar(title: tr('appearance')),
        body: ListView(
          padding: EdgeInsets.fromLTRB(16,
              MediaQuery.of(context).padding.top + kToolbarHeight + 16, 16, 16),
          children: [
            Row(
              children: [
                const Icon(Icons.brightness_6_outlined, size: 22),
                const SizedBox(width: 8),
                Text(tr('theme_mode'),
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),
            ValueListenableBuilder<ThemeMode>(
              valueListenable: themeModeNotifier,
              builder: (_, mode, __) => RadioGroup<ThemeMode>(
                groupValue: mode,
                onChanged: (v) => themeModeNotifier.value = v!,
                child: Column(
                  children: [
                    RadioListTile<ThemeMode>(
                      title: Text(tr('theme_system')),
                      value: ThemeMode.system,
                    ),
                    RadioListTile<ThemeMode>(
                      title: Text(tr('theme_light')),
                      value: ThemeMode.light,
                    ),
                    RadioListTile<ThemeMode>(
                      title: Text(tr('theme_dark')),
                      value: ThemeMode.dark,
                    ),
                  ],
                ),
              ),
            ),
            Text(tr('theme_note'),
                style: TextStyle(color: grey, fontSize: 12)),
            const SizedBox(height: 24),
            Row(
              children: [
                const Icon(Icons.palette_outlined, size: 22),
                const SizedBox(width: 8),
                Text(tr('theme_accent'),
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),
            ValueListenableBuilder<Color>(
              valueListenable: accentNotifier,
              builder: (_, current, __) => Column(
                children: [
                  for (final preset in accentPresets)
                    ListTile(
                      leading: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: preset.color,
                          border: Border.all(
                              color: Colors.grey.withValues(alpha: 0.4)),
                        ),
                      ),
                      title: Text(tr(preset.nameKey)),
                      trailing: current.toARGB32() == preset.color.toARGB32()
                          ? Icon(Icons.check,
                              color: dark
                                  ? lightenedAccent(current)
                                  : current)
                          : null,
                      onTap: () => saveAccent(preset.color),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                const Icon(Icons.color_lens_outlined, size: 22),
                const SizedBox(width: 8),
                Text(tr('accent_custom'),
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),
            ValueListenableBuilder<Color>(
              valueListenable: accentNotifier,
              builder: (_, current, __) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('#${accentHex(current)}',
                      style: TextStyle(color: grey, fontSize: 12)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (final c in _customSwatches)
                        GestureDetector(
                          onTap: () => saveAccent(c),
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: c,
                              border: Border.all(
                                  color:
                                      Colors.grey.withValues(alpha: 0.4)),
                            ),
                            child: current.toARGB32() == c.toARGB32()
                                ? Icon(Icons.check,
                                    size: 18,
                                    color: c.computeLuminance() > 0.5
                                        ? Colors.black
                                        : Colors.white)
                                : null,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _hexCtrl,
                          onSubmitted: (_) => _applyHex(),
                          decoration: InputDecoration(
                            hintText: tr('accent_custom_hint'),
                            errorText: _hexError
                                ? tr('accent_custom_invalid')
                                : null,
                            border: const OutlineInputBorder(
                                borderRadius: BorderRadius.all(
                                    Radius.circular(12))),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: _applyHex,
                        icon: const Icon(Icons.check),
                        tooltip: tr('accent_custom'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                const Icon(Icons.vibration_outlined, size: 22),
                const SizedBox(width: 8),
                Text(tr('haptics'),
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),
            ValueListenableBuilder<bool>(
              valueListenable: hapticsEnabledNotifier,
              builder: (_, enabled, __) => SwitchListTile(
                title: Text(tr('haptics_title')),
                value: enabled,
                onChanged: (v) => hapticsEnabledNotifier.value = v,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
