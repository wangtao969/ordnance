import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 主题强调色：设置页主题页写入，各页主要强调处（导航选中药丸、
/// 开关开启色、主要操作按钮、colorScheme primary）读取。
/// 默认铜色不变；颜色值持久化，启动时读回。
const accentPrefsKey = 'theme_accent_v1';
const defaultAccent = Color(0xFF8C6A2F);

class AccentPreset {
  final String nameKey;
  final Color color;
  const AccentPreset(this.nameKey, this.color);
}

const accentPresets = <AccentPreset>[
  AccentPreset('accent_copper', Color(0xFF8C6A2F)),
  AccentPreset('accent_forest', Color(0xFF2F5D50)),
  AccentPreset('accent_navy', Color(0xFF2E4A6B)),
  AccentPreset('accent_oxblood', Color(0xFF7A2E2E)),
  AccentPreset('accent_slatepurple', Color(0xFF5A5470)),
  // 2.2.5 新增 5 个预设，总数 10 个。
  AccentPreset('accent_blue', Color(0xFF2F5DA8)),
  AccentPreset('accent_green', Color(0xFF3E7A4E)),
  AccentPreset('accent_grey', Color(0xFF6B7280)),
  AccentPreset('accent_gold', Color(0xFFB8963E)),
  AccentPreset('accent_violet', Color(0xFF6B4FA1)),
];

final ValueNotifier<Color> accentNotifier = ValueNotifier(defaultAccent);

/// 夜晚模式用的提亮版强调色：亮度不足时提到 0.62，与原有
/// 深色铜色提亮（bronzeLight）的做法一致，保证黑底上可读。
Color lightenedAccent(Color c) {
  final hsl = HSLColor.fromColor(c);
  if (hsl.lightness >= 0.62) return c;
  return hsl.withLightness(0.62).toColor();
}

Future<void> loadAccent() async {
  try {
    const channel = MethodChannel('gunsmap/prefs');
    final raw = await channel
        .invokeMethod<String>('getString', {'key': accentPrefsKey}).timeout(
            const Duration(seconds: 2));
    if (raw == null) return;
    final v = int.tryParse(raw);
    // 2.2.5：接受任意合法不透明 ARGB（含自定义色），不再只认预设；
    // 非法值回落默认铜色。
    if (v == null || v < 0xFF000000 || v > 0xFFFFFFFF) {
      accentNotifier.value = defaultAccent;
      return;
    }
    accentNotifier.value = Color(v);
  } catch (_) {}
}

/// 十六进制颜色解析：接受 RRGGBB 或 #RRGGBB（不透明），以及 AARRGGBB
///（仅 alpha 为 FF 时接受）；其余一律返回 null，调用方显示错误、不改色。
Color? parseHexColor(String input) {
  var s = input.trim();
  if (s.startsWith('#')) s = s.substring(1);
  if (s.length == 6) {
    final v = int.tryParse(s, radix: 16);
    if (v == null) return null;
    return Color(0xFF000000 | v);
  }
  if (s.length == 8) {
    final v = int.tryParse(s, radix: 16);
    if (v == null || v < 0xFF000000) return null;
    return Color(v);
  }
  return null;
}

/// 当前强调色的 RRGGBB 大写串（不含 # 与 alpha），用于自定义区回显。
String accentHex(Color c) =>
    c.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase();

Future<void> saveAccent(Color c) async {
  accentNotifier.value = c;
  try {
    const channel = MethodChannel('gunsmap/prefs');
    await channel.invokeMethod('setString',
        {'key': accentPrefsKey, 'value': c.toARGB32().toString()}).timeout(
            const Duration(seconds: 2));
  } catch (_) {}
}
