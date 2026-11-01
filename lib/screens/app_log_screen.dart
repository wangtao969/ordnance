import 'package:flutter/material.dart';
import '../i18n.dart';
import 'package:flutter/services.dart';
import '../app_log.dart';
import '../widgets/app_top_bar.dart';
import '../widgets/app_toast.dart';

/// 设备日志查看页：只显示本机记下的关键事件摘要，
/// 可一键复制全部（发给开发者定位问题）、可清空。
class AppLogScreen extends StatefulWidget {
  const AppLogScreen({super.key});

  @override
  State<AppLogScreen> createState() => _AppLogScreenState();
}

class _AppLogScreenState extends State<AppLogScreen> {
  var _entries = <String>[];

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final list = await readAppLog();
    if (mounted) setState(() => _entries = list);
  }

  Future<void> _copyAll() async {
    if (_entries.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: _entries.join('\n')));
    if (mounted) showAppToast(context, tr('app_log_copied'));
  }

  Future<void> _confirmClear() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('app_log_clear_title')),
        content: Text(tr('app_log_clear_body')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(tr('cancel'))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(tr('app_log_clear'))),
        ],
      ),
    );
    if (ok != true) return;
    await clearAppLog();
    await _reload();
    if (mounted) showAppToast(context, tr('app_log_cleared'));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: SubPageAppBar(title: tr('app_log_title')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                      tr('app_log_note'),
                      style: TextStyle(color: Colors.grey, fontSize: 12)),
                ),
                TextButton.icon(
                  onPressed: _entries.isEmpty ? null : _copyAll,
                  icon: const Icon(Icons.copy, size: 18),
                  label: Text(tr('app_log_copy_all')),
                ),
                TextButton.icon(
                  onPressed: _entries.isEmpty ? null : _confirmClear,
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: Text(tr('app_log_clear')),
                ),
              ],
            ),
          ),
          Expanded(
            child: _entries.isEmpty
                ? Center(
                    child: Text(tr('app_log_empty'),
                        style: TextStyle(color: Colors.grey)))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _entries.length,
                    itemBuilder: (_, i) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: SelectableText(_entries[i],
                          style: const TextStyle(fontSize: 12)),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
