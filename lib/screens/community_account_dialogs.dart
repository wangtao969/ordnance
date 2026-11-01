import 'dart:ui' as ui;
import '../widgets/app_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../community_store.dart';
import '../theme_accent.dart';
import '../i18n.dart';

/// 社区账号对话框（注册 / 登录 / 编辑资料）：社区首屏、个人主页、
/// 设置页、新手引导共用，逻辑只写一份。
/// 样式：统一毛玻璃弹窗（模糊背景 + 半透明填充 + 圆角 + 细边），
/// 不再用默认 AlertDialog 的毛坯样式。
const _pickImageChannel = MethodChannel('gunsmap/pick_image');

Future<Uint8List?> _pickAvatar(BuildContext context) async {
  try {
    final bytes = await _pickImageChannel.invokeMethod<Uint8List>('pickImage');
    if (bytes == null || bytes.isEmpty) return null;
    return bytes;
  } catch (_) {
    return null;
  }
}

/// 毛玻璃弹窗壳：标题 + 关闭钮 + 内容 + 底部按钮行。
class _GlassDialog extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;
  final Widget actions;
  const _GlassDialog({
    required this.title,
    this.subtitle,
    required this.child,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 30,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Container(
              decoration: BoxDecoration(
                color: dark
                    ? const Color(0xCC26221D)
                    : const Color(0xE8FFFFFF),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: Colors.white.withOpacity(dark ? 0.16 : 0.6),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(22, 18, 22, 20),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(title,
                              style: const TextStyle(
                                  fontSize: 20, fontWeight: FontWeight.bold)),
                        ),
                        _closeButton(context, dark),
                      ],
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(subtitle!,
                          style: TextStyle(
                              color: dark
                                  ? const Color(0xFFB0A99B)
                                  : const Color(0xFF8A8375),
                              fontSize: 13)),
                    ],
                    const SizedBox(height: 18),
                    child,
                    const SizedBox(height: 20),
                    actions,
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _closeButton(BuildContext context, bool dark) {
    return GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withOpacity(dark ? 0.12 : 0.6),
        ),
        child: Icon(Icons.close,
            size: 17,
            color: dark ? Colors.white70 : const Color(0xFF6B6257)),
      ),
    );
  }
}

/// 毛玻璃输入框。
InputDecoration _glassField(BuildContext context, String label) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  return InputDecoration(
    labelText: label,
    filled: true,
    fillColor: Colors.white.withOpacity(dark ? 0.08 : 0.55),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide.none,
    ),
  );
}

/// 底部按钮行：取消（文字）+ 主按钮（铜色满高）。
Widget _dialogActions(
  BuildContext context, {
    required VoidCallback onCancel,
    required VoidCallback onPrimary,
    required String primaryLabel,
  }) {
  return Row(
    children: [
      TextButton(
        onPressed: onCancel,
        child: Text(tr('cancel')),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: ValueListenableBuilder<Color>(
          valueListenable: accentNotifier,
          builder: (_, accent, __) => ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: accent,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: onPrimary,
            child: Text(primaryLabel,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.bold)),
          ),
        ),
      ),
    ],
  );
}

/// 错误提示：淡红圆角条。
Widget _errorBar(String error) {
  return Container(
    width: double.infinity,
    margin: const EdgeInsets.only(top: 10),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
    decoration: BoxDecoration(
      color: Colors.red.withOpacity(0.12),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(error, style: const TextStyle(color: Colors.red, fontSize: 13)),
  );
}

Widget _avatarPickerRow({
  required BuildContext context,
  required Uint8List? picked,
  required String nickname,
  required StateSetter setDialogState,
  required ValueChanged<Uint8List?> onPicked,
}) {
  return Row(
    children: [
      communityAvatar(
          bytes: picked,
          color: const Color(0xFFB8B8B8),
          nickname: nickname,
          radius: 26),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                side: BorderSide(
                    color: Colors.white.withOpacity(0.5)),
              ),
              onPressed: () async {
                final bytes = await _pickAvatar(context);
                if (bytes == null) {
                  if (context.mounted) {
                    showAppToast(context, tr('pick_failed'));
                  }
                  return;
                }
                setDialogState(() => onPicked(bytes));
              },
              icon: const Icon(Icons.photo_library_outlined, size: 18),
              label: Text(tr('upload_avatar')),
            ),
            if (picked != null)
              TextButton(
                onPressed: () => setDialogState(() => onPicked(null)),
                child: Text(tr('remove_photo')),
              ),
          ],
        ),
      ),
    ],
  );
}

const _avatarFrames = [
  '',
  'copper',
  'gold',
  'rainbow',
  'silver',
  'emerald',
  'sapphire',
  'violet',
  'crimson',
  'gunmetal',
];

String _frameLabel(String frame) {
  switch (frame) {
    case 'copper':
      return tr('frame_copper');
    case 'gold':
      return tr('frame_gold');
    case 'rainbow':
      return tr('frame_rainbow');
    case 'silver':
      return tr('frame_silver');
    case 'emerald':
      return tr('frame_emerald');
    case 'sapphire':
      return tr('frame_sapphire');
    case 'violet':
      return tr('frame_violet');
    case 'crimson':
      return tr('frame_crimson');
    case 'gunmetal':
      return tr('frame_gunmetal');
    default:
      return tr('frame_none');
  }
}

Widget _framePickerRow({
  required Uint8List? picked,
  required String nickname,
  required String frame,
  required StateSetter setDialogState,
  required ValueChanged<String> onPick,
}) {
  // 2.2.5：10 个框横排会溢出，改 Wrap 换行（横向间距仍用内层 right:16）。
  return Wrap(
    runSpacing: 12,
    children: _avatarFrames.map((f) {
      final selected = f == frame;
      return Padding(
        padding: const EdgeInsets.only(right: 16),
        child: GestureDetector(
          onTap: () => setDialogState(() => onPick(f)),
          child: Column(
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected ? Colors.white : Colors.transparent,
                    width: 2.5,
                  ),
                  boxShadow: [
                    if (selected)
                      const BoxShadow(
                        color: Colors.black26,
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                  ],
                ),
                child: communityAvatar(
                  bytes: picked,
                  color: const Color(0xFFB8B8B8),
                  nickname: nickname,
                  radius: 22,
                  frame: f,
                ),
              ),
              const SizedBox(height: 4),
              Text(_frameLabel(f), style: const TextStyle(fontSize: 11)),
            ],
          ),
        ),
      );
    }).toList(),
  );
}

Widget _glassSwitchRow({
  required String title,
  required bool value,
  required ValueChanged<bool> onChanged,
}) {
  return Row(
    children: [
      Expanded(child: Text(title, style: const TextStyle(fontSize: 14))),
      ValueListenableBuilder<Color>(
        valueListenable: accentNotifier,
        builder: (_, accent, __) => Switch(
          value: value,
          activeColor: accent,
          onChanged: onChanged,
        ),
      ),
    ],
  );
}

Future<bool> showRegisterDialog(BuildContext context) async {
  final nickCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  final confirmCtrl = TextEditingController();
  final inviteCtrl = TextEditingController();
  Uint8List? pickedAvatar;
  String? error;
  var obscure = true;
  final ok = await showDialog<bool>(
    context: context,
    barrierColor: Colors.black.withOpacity(0.35),
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) => _GlassDialog(
        title: tr('register_title'),
        subtitle: tr('register_subtitle'),
        actions: _dialogActions(
          context,
          onCancel: () => Navigator.of(dialogContext).pop(false),
          onPrimary: () {
            final nick = nickCtrl.text.trim();
            final pass = passCtrl.text;
            String? e;
            if (pass != confirmCtrl.text) {
              e = tr('err_mismatch');
            } else {
              e = communityStore.register(
                nickname: nick,
                password: pass,
                avatarBytes: pickedAvatar,
                invitedBy: inviteCtrl.text.trim(),
              );
            }
            if (e != null) {
              setDialogState(() => error = e);
              return;
            }
            Navigator.of(dialogContext).pop(true);
          },
          primaryLabel: tr('register'),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _avatarPickerRow(
              context: context,
              picked: pickedAvatar,
              nickname: nickCtrl.text,
              setDialogState: setDialogState,
              onPicked: (b) => pickedAvatar = b,
            ),
            const SizedBox(height: 14),
            Text(
              '${tr('assigned_id')}：${communityStore.nextUserId}',
              style:
                  const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 2),
            Text(tr('id_auto_note'),
                style: const TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 18),
            TextField(
              controller: nickCtrl,
              decoration: _glassField(context, tr('nickname_label')),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: passCtrl,
              obscureText: obscure,
              decoration: _glassField(context, tr('password_label'))
                  .copyWith(
                suffixIcon: IconButton(
                  icon: Icon(
                      obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      size: 20),
                  onPressed: () => setDialogState(() => obscure = !obscure),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: confirmCtrl,
              obscureText: obscure,
              decoration: _glassField(context, tr('confirm_password')),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: inviteCtrl,
              decoration: _glassField(context, tr('dialogs_invite_hint')),
            ),
            if (error != null) _errorBar(error!),
          ],
        ),
      ),
    ),
  );
  nickCtrl.dispose();
  passCtrl.dispose();
  confirmCtrl.dispose();
  inviteCtrl.dispose();
  return ok == true;
}

Future<bool> showLoginDialog(BuildContext context) async {
  final idCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  String? error;
  var obscure = true;
  final ok = await showDialog<bool>(
    context: context,
    barrierColor: Colors.black.withOpacity(0.35),
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) => _GlassDialog(
        title: tr('login'),
        subtitle: tr('login_subtitle'),
        actions: _dialogActions(
          context,
          onCancel: () => Navigator.of(dialogContext).pop(false),
          onPrimary: () {
            final e = communityStore.login(
              id: idCtrl.text.trim(),
              password: passCtrl.text,
            );
            if (e != null) {
              setDialogState(() => error = e);
              return;
            }
            Navigator.of(dialogContext).pop(true);
          },
          primaryLabel: tr('login'),
        ),
        child: Column(
          children: [
            TextField(
              controller: idCtrl,
              decoration: _glassField(context, tr('id_field')),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: passCtrl,
              obscureText: obscure,
              decoration: _glassField(context, tr('password_label'))
                  .copyWith(
                suffixIcon: IconButton(
                  icon: Icon(
                      obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      size: 20),
                  onPressed: () => setDialogState(() => obscure = !obscure),
                ),
              ),
            ),
            if (error != null) _errorBar(error!),
          ],
        ),
      ),
    ),
  );
  idCtrl.dispose();
  passCtrl.dispose();
  return ok == true;
}

Future<void> showEditProfileDialog(BuildContext context) async {
  final account = communityStore.current;
  if (account == null) return;
  final nickCtrl = TextEditingController(text: account.nickname);
  final bioCtrl = TextEditingController(text: account.bio);
  Uint8List? pickedAvatar = account.avatarBytes;
  var frame = account.avatarFrame;
  var showId = account.showIdPublic;
  var favPublic = account.favoritesPublic;
  final saved = await showDialog<bool>(
    context: context,
    barrierColor: Colors.black.withOpacity(0.35),
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) => _GlassDialog(
        title: tr('edit_profile'),
        actions: _dialogActions(
          context,
          onCancel: () => Navigator.of(dialogContext).pop(false),
          onPrimary: () => Navigator.of(dialogContext).pop(true),
          primaryLabel: tr('save'),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _avatarPickerRow(
              context: context,
              picked: pickedAvatar,
              nickname: nickCtrl.text,
              setDialogState: setDialogState,
              onPicked: (b) => pickedAvatar = b,
            ),
            const SizedBox(height: 16),
            Text(tr('avatar_frame'),
                style:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            _framePickerRow(
              picked: pickedAvatar,
              nickname: nickCtrl.text,
              frame: frame,
              setDialogState: setDialogState,
              onPick: (f) => frame = f,
            ),
            const SizedBox(height: 18),
            TextField(
              controller: nickCtrl,
              decoration: _glassField(context, tr('nickname_label')),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: bioCtrl,
              maxLines: 3,
              decoration: _glassField(context, tr('bio_label')),
            ),
            const SizedBox(height: 6),
            _glassSwitchRow(
              title: tr('show_id_switch'),
              value: showId,
              onChanged: (v) => setDialogState(() => showId = v),
            ),
            _glassSwitchRow(
              title: tr('favorites_public_switch'),
              value: favPublic,
              onChanged: (v) => setDialogState(() => favPublic = v),
            ),
            const SizedBox(height: 4),
            Text(
                '${tr('id_field')}：${account.id}${tr('id_fixed_suffix')}',
                style: const TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
      ),
    ),
  );
  if (saved == true) {
    if (nickCtrl.text.trim().isNotEmpty) {
      account.nickname = maskSensitiveWords(nickCtrl.text.trim());
    }
    account.bio = maskSensitiveWords(bioCtrl.text.trim());
    account.avatarBytes = pickedAvatar;
    account.avatarFrame = frame;
    account.showIdPublic = showId;
    account.favoritesPublic = favPublic;
    communityStore.refresh();
  }
  nickCtrl.dispose();
  bioCtrl.dispose();
}

/// 未登录时弹的登录/注册二选一。
void askLoginDialog(BuildContext context) {
  showDialog(
    context: context,
    barrierColor: Colors.black.withOpacity(0.35),
    builder: (dialogContext) => _GlassDialog(
      title: tr('login_required_title'),
      actions: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ValueListenableBuilder<Color>(
            valueListenable: accentNotifier,
            builder: (_, accent, __) => ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () {
                Navigator.of(dialogContext).pop();
                showLoginDialog(context);
              },
              child: Text(tr('login'),
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: () {
              Navigator.of(dialogContext).pop();
              showRegisterDialog(context);
            },
            child: Text(tr('register'),
                style:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 4),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(tr('cancel')),
          ),
        ],
      ),
      child: Text(tr('login_required_body'),
          style: const TextStyle(fontSize: 14, height: 1.5)),
    ),
  );
}
