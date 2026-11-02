import 'dart:convert';
import '../widgets/app_toast.dart';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../i18n.dart';
import '../theme_accent.dart';
import '../main.dart';
import '../system_actions.dart';
import '../widgets/app_top_bar.dart';
import '../widgets/glass_dialog.dart';
import '../community_store.dart';
import 'about_screen.dart';
import 'theme_screen.dart';
import 'app_log_screen.dart';
import 'feedback_screen.dart';

/// 当前版本：每次发版时与 pubspec.yaml 一起改。
const String appVersion = '2.3.1';

/// 设置页：主题切换与关于信息。
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final grey = dark ? const Color(0xFF8A8578) : const Color(0xFF9A917F);
    // 语言切换时整页重译。
    return ValueListenableBuilder<String>(
      valueListenable: localeNotifier,
      builder: (_, __, ___) => Scaffold(
      extendBodyBehindAppBar: true,
      appBar: SubPageAppBar(title: tr('settings_title')),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
            16, MediaQuery.of(context).padding.top + kToolbarHeight + 16, 16, 16),
        children: [
          // 顶部：App 图标 + 名称 + 同色小药丸当前版本号。
          Center(
            child: Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Image.asset('assets/images/app-icon.png',
                      width: 72, height: 72, fit: BoxFit.cover),
                ),
                const SizedBox(height: 10),
                const Text("Ordnance",
                    style: TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 20,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('Firearms Atlas · Accessories · Reloading · Community',
                    style: TextStyle(color: grey, fontSize: 12)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: dark
                        ? const Color(0xFFC9A86A)
                        : const Color(0xFF6B5B3E),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text('v$appVersion',
                      style: TextStyle(
                          color: dark
                              ? const Color(0xFF000000)
                              : Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 6),
                Text(tr('settings_engine_prefix') + 'Flutter 3.47.8',
                    style: TextStyle(color: grey, fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // 快捷操作：默认收起，只留一行入口，点开才展开四项，
          // 免得顶部一大块面板抢眼；后台入口仍只对管理员/版主显示。
          _QuickActionsCard(
            onCheckUpdate: (ctx) => _checkUpdate(ctx),
            onExportData: (ctx) => _exportData(ctx),
          ),
          ListTile(
            leading: const Icon(Icons.bug_report_outlined, size: 22),
            title: Text(tr('app_log_title')),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AppLogScreen()),
            ),
          ),
          const SizedBox(height: 24),
          ValueListenableBuilder<Color>(
            valueListenable: accentNotifier,
            builder: (_, accent, __) => ValueListenableBuilder<ThemeMode>(
              valueListenable: themeModeNotifier,
              builder: (_, mode, __) => ListTile(
                leading: const Icon(Icons.palette_outlined, size: 22),
                title: Text(tr('appearance')),
                subtitle: Text(mode == ThemeMode.system
                    ? tr('theme_system')
                    : mode == ThemeMode.light
                        ? tr('theme_light')
                        : tr('theme_dark')),
                trailing: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: accent,
                    border: Border.all(
                        color: Colors.grey.withValues(alpha: 0.4)),
                  ),
                ),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ThemeScreen()),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              const Icon(Icons.language_outlined, size: 22),
              const SizedBox(width: 8),
              Text(tr('language'),
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          ValueListenableBuilder<String>(
            valueListenable: localeNotifier,
            builder: (_, locale, __) => RadioGroup<String>(
              groupValue: locale,
              onChanged: (v) => localeNotifier.value = v!,
              child: Column(
                children: [
                  for (final entry in localeNames.entries)
                    RadioListTile<String>(
                      title: Text(entry.value),
                      value: entry.key,
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              const Icon(Icons.info_outlined, size: 22),
              const SizedBox(width: 8),
              Text(tr('about'),
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.apps_outlined, size: 22),
            title: const Text("Ordnance"),
            subtitle: Text('${tr('version_prefix')}v$appVersion${Platform.isIOS ? tr('version_suffix_ios') : tr('version_suffix')}'),
          ),
          ListTile(
            leading: const Icon(Icons.feedback_outlined, size: 22),
            title: Text(tr('feedback')),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const FeedbackScreen()),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.person_add_outlined, size: 22),
            title: Text(tr('settings_invite')),
            onTap: () => _showInviteDialog(context),
          ),
          ListTile(
            leading: const Icon(Icons.code, size: 22),
            title: Text(tr('about_github')),
            subtitle: const Text('wangtao969/ordnance'),
            onTap: () async {
              final ok = await openSystemUrl(
                  'https://github.com/wangtao969/ordnance');
              if (!ok && context.mounted) {
                showAppToast(context, tr('browser_open_failed'));
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.book_outlined, size: 22),
            title: Text(tr('about_title')),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AboutScreen()),
            ),
          ),
        ],
      ),
      ),
    );
  }

  /// 导出我的数据：与快捷操作面板里的“导出我的数据”共用同一份逻辑。
  Future<void> _exportData(BuildContext context) async {
    final me = communityStore.current;
    if (me == null) {
      showAppToast(context, tr('settings_login_export'));
      return;
    }
    final data = {
      'app': 'Ordnance',
      'version': appVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'account': {
        'id': me.id,
        'nickname': me.nickname,
        'level': me.level,
        'totalXp': me.totalXp,
      },
      'collection': me.collection.map((c) => c.toJson()).toList(),
      'rangeScores': me.rangeScores.map((r) => r.toJson()).toList(),
      'earnedMedals':
          communityStore.earnedMedals(me).map((m) => m.id).toList(),
    };
    try {
      const share = MethodChannel('gunsmap/share');
      final ok =
          await share.invokeMethod<bool>('shareText', {'text': jsonEncode(data)});
      if (ok != true && context.mounted) {
        showAppToast(context, tr('settings_share_failed'));
      }
    } catch (_) {
      if (context.mounted) showAppToast(context, tr('settings_export_failed'));
    }
  }

  /// 邀请好友：邀请码就是自己的 ID；新用户注册时填码，
  /// 邀请人在本机可直接 +100 经验，跨设备部分联网版按 invitedBy 结算。
  void _showInviteDialog(BuildContext context) {
    final me = communityStore.current;
    if (me == null) {
      showAppToast(context, tr('settings_login_invite'));
      return;
    }
    final invitedCount =
        communityStore.accounts.where((a) => a.invitedBy == me.id).length;
    const shareChannel = MethodChannel('gunsmap/share');
    showDialog(
      context: context,
      builder: (dialogContext) => GlassDialog(
        title: tr('settings_invite'),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tr('settings_invite_code'), style: TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 4),
            Text(me.id,
                style: const TextStyle(
                    fontSize: 28, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(tr('settings_invite_note'),
                style: TextStyle(fontSize: 13)),
            const SizedBox(height: 4),
            Text(tr('settings_invite_count_prefix') + '$invitedCount' + tr('settings_invite_count_suffix'),
                style: const TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: me.id));
              if (dialogContext.mounted) {
                showAppToast(dialogContext, tr('settings_invite_copied'));
              }
            },
            child: Text(tr('settings_copy_invite')),
          ),
          glassPrimaryButton(
            dialogContext,
            tr('settings_share_invite'),
            onPressed: () async {
              await shareChannel.invokeMethod('shareText', {
                'text':
                    '来玩 Ordnance，一起聊枪、晒收藏！下载：https://github.com/wangtao969/ordnance/releases/latest 邀请码：${me.id}（注册时填写）'
              });
            },
          ),
        ],
      ),
    );
  }

  /// 检查更新：只用 Dart 核心库查 GitHub 最新 Release，不引第三方包。
  /// iOS 版不走这条路：点开即提示走 TestFlight 更新，不查 Release、不下载。
  Future<void> _checkUpdate(BuildContext context) async {
    if (Platform.isIOS) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(tr('ios_update_title')),
          content: Text(tr('ios_update_body')),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(tr('ok')),
            ),
          ],
        ),
      );
      return;
    }
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text(tr('checking')),
          ],
        ),
      ),
    );
    try {
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 10);
      final request = await client.getUrl(Uri.parse(
          'https://api.github.com/repos/wangtao969/ordnance/releases/latest'));
      request.headers.set('Accept', 'application/vnd.github+json');
      request.headers.set('User-Agent', 'Ordnance');
      final response =
          await request.close().timeout(const Duration(seconds: 15));
      final body = await response.transform(utf8.decoder).join();
      client.close();
      if (response.statusCode != 200) {
        throw HttpException('HTTP ${response.statusCode}');
      }
      final data = jsonDecode(body) as Map<String, dynamic>;
      final tag = (data['tag_name'] as String?) ?? '';
      final latest = tag.replaceFirst(RegExp(r'^v'), '').split('-').first;
      final notes = (data['body'] as String?) ?? '';
      String? apkUrl;
      for (final a in (data['assets'] as List? ?? [])) {
        final asset = a as Map;
        final name = (asset['name'] as String?) ?? '';
        if (name.endsWith('.apk')) {
          apkUrl = asset['browser_download_url'] as String?;
          break;
        }
      }
      final link =
          apkUrl ?? (data['html_url'] as String? ?? 'https://github.com/wangtao969/ordnance/releases');
      if (!context.mounted) return;
      Navigator.of(context).pop();
      if (latest.isEmpty || _compareVersions(latest, appVersion) <= 0) {
        if (!context.mounted) return;
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: Text(tr('latest_title')),
            content: Text('${tr('latest_body_prefix')}$appVersion${tr('latest_body_suffix')}'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(tr('ok')),
              ),
            ],
          ),
        );
        return;
      }
      final shownNotes =
          notes.length > 500 ? '${notes.substring(0, 500)}…' : notes;
      if (!context.mounted) return;
      showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text('${tr('new_title_prefix')}$latest'),
          content: SingleChildScrollView(
            child: Text(shownNotes.isEmpty ? tr('new_empty') : shownNotes),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(tr('close')),
            ),
            TextButton(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: link));
                if (!dialogContext.mounted) return;
                Navigator.of(dialogContext).pop();
                if (!context.mounted) return;
                showAppToast(context, tr('copied'));
              },
              child: Text(tr('copy_link')),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _downloadAndInstall(context, apkUrl ?? link, latest);
              },
              child: Text(tr('settings_download_install')),
            ),
          ],
        ),
      );
    } catch (_) {
      if (!context.mounted) return;
      Navigator.of(context).pop();
      if (!context.mounted) return;
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(tr('check_failed')),
          content: Text(tr('check_failed_body')),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(tr('ok')),
            ),
          ],
        ),
      );
    }
  }

  /// 下载安装包并拉起系统安装器：只用 Dart 核心库下载到本机缓存，
  /// 再经 gunsmap/system 通道走 FileProvider 安装，不引第三方包。
  Future<void> _downloadAndInstall(
      BuildContext context, String apkUrl, String latest) async {
    if (Platform.isIOS) {
      // iOS 兜底：绝不调 installApk，统一提示走 TestFlight。
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: Text(tr('ios_update_title')),
            content: Text(tr('ios_update_body')),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(tr('ok')),
              ),
            ],
          ),
        );
      }
      return;
    }
    if (!apkUrl.endsWith('.apk')) {
      if (context.mounted) {
        showAppToast(context, tr('settings_apk_missing'));
      }
      return;
    }
    final cacheDir =
        await getCacheDirPath() ?? Directory.systemTemp.path;
    final path = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          _DownloadDialog(url: apkUrl, version: latest, dir: cacheDir),
    );
    if (path == null) {
      if (context.mounted) {
        showAppToast(context, tr('settings_download_failed'));
      }
      return;
    }
    final ok = await installDownloadedApk(path);
    if (!context.mounted) return;
    showAppToast(context, ok
            ? tr('settings_installer_open')
            : tr('settings_installer_failed'), onTap: ok ? null : () => Clipboard.setData(ClipboardData(text: apkUrl)), actionLabel: ok ? null : tr('copy_link'));
  }

  /// 版本号比较：1.4.0 这种三段数字，返回负数表示 a 更旧。
  int _compareVersions(String a, String b) {
    final pa = a.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final pb = b.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    for (var i = 0; i < 3; i++) {
      final x = i < pa.length ? pa[i] : 0;
      final y = i < pb.length ? pb[i] : 0;
      if (x != y) return x.compareTo(y);
    }
    return 0;
  }
}

/// 清理缓存行：只删原生 cacheDir 下的临时文件（主要是更新时下载的安装包），
/// 绝不碰 SharedPreferences 里的账号、收藏柜、靶场成绩、弹药库存、保养记录、
/// 复装记录等本机数据；删完重新计算一次大小，副标题即刷新。
class _ClearCacheTile extends StatefulWidget {
  const _ClearCacheTile();

  @override
  State<_ClearCacheTile> createState() => _ClearCacheTileState();
}

class _ClearCacheTileState extends State<_ClearCacheTile> {
  int? _size;
  bool _clearing = false;

  @override
  void initState() {
    super.initState();
    _refreshSize();
  }

  Future<Directory?> _cacheDir() async {
    final path = await getCacheDirPath();
    if (path == null) return null;
    return Directory(path);
  }

  Future<int> _dirSize(Directory dir) async {
    var total = 0;
    try {
      await for (final e in dir.list(recursive: true, followLinks: false)) {
        try {
          if (e is File) total += await e.length();
        } catch (_) {}
      }
    } catch (_) {}
    return total;
  }

  Future<void> _refreshSize() async {
    final dir = await _cacheDir();
    final size = dir == null ? 0 : await _dirSize(dir);
    if (!mounted) return;
    setState(() => _size = size);
  }

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Future<void> _onTap() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => GlassDialog(
        title: tr('settings_clear_cache'),
        content: Text(tr('settings_clear_body')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(tr('cancel')),
          ),
          glassPrimaryButton(ctx, tr('settings_clear_action'), popTrue: true),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _clearing = true);
    final dir = await _cacheDir();
    var freed = 0;
    if (dir != null) {
      freed = await _dirSize(dir);
      try {
        await for (final e in dir.list(followLinks: false)) {
          try {
            await e.delete(recursive: true);
          } catch (_) {}
        }
      } catch (_) {}
    }
    if (!mounted) return;
    setState(() {
      _clearing = false;
      _size = 0;
    });
    showAppToast(context,
        freed > 0 ? tr('settings_cleared_prefix') + _formatBytes(freed) : tr('settings_cache_empty'));
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.cleaning_services_outlined, size: 22),
      title: Text(tr('settings_clear_cache')),
      subtitle: Text(_clearing
          ? tr('settings_clearing')
          : _size == null
              ? tr('settings_calculating')
              : tr('settings_cache_now_prefix') + _formatBytes(_size!) + tr('settings_cache_now_suffix')),
      onTap: _clearing ? null : _onTap,
    );
  }
}

/// 下载进度对话框：弹出即开始下载，完成后带文件路径退出，失败带 null 退出。
class _DownloadDialog extends StatefulWidget {
  final String url;
  final String version;
  final String dir;
  const _DownloadDialog(
      {required this.url, required this.version, required this.dir});

  @override
  State<_DownloadDialog> createState() => _DownloadDialogState();
}

class _DownloadDialogState extends State<_DownloadDialog> {
  double _progress = 0;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    try {
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 15);
      final request = await client.getUrl(Uri.parse(widget.url));
      request.headers.set('User-Agent', 'Ordnance');
      final response =
          await request.close().timeout(const Duration(seconds: 30));
      if (response.statusCode != 200) {
        throw HttpException('HTTP ${response.statusCode}');
      }
      final total = response.contentLength;
      final file =
          File('${widget.dir}/Ordnance-v${widget.version}-arm64.apk');
      final sink = file.openWrite();
      var received = 0;
      await for (final chunk in response) {
        received += chunk.length;
        sink.add(chunk);
        if (mounted && total > 0) {
          setState(() => _progress = received / total);
        }
      }
      await sink.close();
      client.close();
      if (!mounted) return;
      Navigator.of(context).pop(file.path);
    } catch (_) {
      if (!mounted) return;
      Navigator.of(context).pop(null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      content: Row(
        children: [
          const CircularProgressIndicator(),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tr('settings_downloading')),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                    value: _progress > 0 ? _progress : null),
                const SizedBox(height: 4),
                Text(_progress > 0
                    ? '${(_progress * 100).toStringAsFixed(0)}%'
                    : '…'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 快捷操作卡片：默认收起只留一行入口，点开才展开四项。
class _QuickActionsCard extends StatefulWidget {
  final void Function(BuildContext context) onCheckUpdate;
  final void Function(BuildContext context) onExportData;
  const _QuickActionsCard(
      {required this.onCheckUpdate, required this.onExportData});

  @override
  State<_QuickActionsCard> createState() => _QuickActionsCardState();
}

class _QuickActionsCardState extends State<_QuickActionsCard> {
  var _expanded = false;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      color: dark ? const Color(0xFF0D0D0D) : const Color(0xFFF3E9D8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
            color: const Color(0xFFE86A1C).withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Row(
                children: [
                  const Icon(Icons.bolt_outlined,
                      size: 22, color: Color(0xFFE86A1C)),
                  const SizedBox(width: 8),
                  Text(tr('settings_quick'),
                      style: TextStyle(
                          fontSize: 17, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 6),
                  if (localeNotifier.value == localeHans)
                    const Text('Quick Actions',
                        style: TextStyle(color: Colors.grey, fontSize: 12)),
                  const Spacer(),
                  Icon(
                      _expanded
                          ? Icons.expand_less
                          : Icons.expand_more,
                      size: 22,
                      color: Colors.grey),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            ListTile(
              leading: const Icon(Icons.system_update_alt, size: 22),
              title: Text(tr('check_update')),
              subtitle: Platform.isIOS ? Text(tr('ios_update_title')) : null,
              onTap: () => widget.onCheckUpdate(context),
            ),
            const _ClearCacheTile(),
            ListTile(
              leading: const Icon(Icons.file_download_outlined, size: 22),
              title: Text(tr('settings_export')),
              onTap: () => widget.onExportData(context),
            ),

            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

