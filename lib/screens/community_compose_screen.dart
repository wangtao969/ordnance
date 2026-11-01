import 'package:flutter/material.dart';
import '../widgets/app_toast.dart';
import 'package:flutter/services.dart';
import '../community_store.dart';
import '../i18n.dart';
import '../sensors_api.dart';
import '../weather_api.dart';
import '../widgets/liquid_glass_nav.dart';

/// 发帖器（Threads 风格排版）：顶部左边取消、右边液态玻璃发布按钮；
/// 下方头像 + 用户名一行，配大面积无边框纯文本输入框；附件行：
/// 图片（已有链路）/ 定位（GPS）/ 天气快照（复用天气系统）/ 视频
/// （系统选视频，存沙盒路径）；附件不进草稿，只活在本次编辑器里；
/// 不加回复权限选择器（原先就没有）。
/// 标题（可选）、板块选择、自动草稿与清除草稿等已有能力全部保留。
/// 每敲一个字都更新草稿：写一半切后台再回来，内容还在；
/// 发布成功自动清草稿；草稿保存在本机。
class CommunityComposeScreen extends StatefulWidget {
  const CommunityComposeScreen({super.key});

  @override
  State<CommunityComposeScreen> createState() => _CommunityComposeScreenState();
}

class _CommunityComposeScreenState extends State<CommunityComposeScreen> {
  static const _pickImageChannel = MethodChannel('gunsmap/pick_image');
  late final TextEditingController _titleCtrl;
  late final TextEditingController _contentCtrl;
  String _board = '综合';
  final _images = <Uint8List>[];
  // 附件（不进草稿）：定位文字、天气快照文字、视频沙盒路径。
  String _location = '';
  String _weather = '';
  String _videoPath = '';

  @override
  void initState() {
    super.initState();
    final draft = communityStore.draft;
    _titleCtrl = TextEditingController(text: draft?.title ?? '');
    _contentCtrl = TextEditingController(text: draft?.content ?? '');
    if (draft != null) _board = draft.board;
  }

  @override
  void dispose() {
    _saveDraft();
    communityStore.persist();
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  void _saveDraft() {
    communityStore.saveDraft(
      title: _titleCtrl.text,
      content: _contentCtrl.text,
      board: _board,
    );
  }

  Future<void> _addImage() async {
    try {
      final bytes = await _pickImageChannel.invokeMethod<Uint8List>('pickImage');
      if (bytes == null || bytes.isEmpty) {
        if (mounted) {
          showAppToast(context, tr('pick_failed'));
        }
        return;
      }
      setState(() => _images.add(bytes));
    } catch (_) {
      if (mounted) {
        showAppToast(context, tr('pick_failed'));
      }
    }
  }

  /// 定位附件：先申请定位权限，再取 GPS 经纬度（5 位小数）存文字；
  /// 被拒或失败给可读提示，不阻塞发帖。
  Future<void> _addLocation() async {
    final granted = await requestLocationPermission();
    if (!granted) {
      if (mounted) showAppToast(context, tr('compose_location_denied'));
      return;
    }
    final fix = await getGpsPosition();
    final v = fix.value;
    if (v == null) {
      if (mounted) showAppToast(context, tr('compose_location_failed'));
      return;
    }
    setState(() => _location =
        '${v.latitude.toStringAsFixed(5)}, ${v.longitude.toStringAsFixed(5)}');
  }

  /// 天气快照附件：GPS → Open-Meteo 实况 → buildWeatherSnapshot
  /// （复用天气系统格式）；只填天气字段，不顺带写定位。
  Future<void> _addWeather() async {
    final granted = await requestLocationPermission();
    if (!granted) {
      if (mounted) showAppToast(context, tr('compose_location_denied'));
      return;
    }
    final fix = await getGpsPosition();
    final v = fix.value;
    if (v == null) {
      if (mounted) showAppToast(context, tr('compose_location_failed'));
      return;
    }
    try {
      final w = await fetchWeather(v.latitude, v.longitude);
      final snap = buildWeatherSnapshot(w, _location);
      if (mounted) setState(() => _weather = snap);
    } catch (_) {
      if (mounted) showAppToast(context, tr('compose_weather_failed'));
    }
  }

  /// 视频附件：系统选视频（ACTION_GET_CONTENT video/*），原生侧拷到
  /// cacheDir/videos 后返回沙盒路径，存 post.videoPath；用户取消不提示。
  Future<void> _addVideo() async {
    try {
      final path =
          await _pickImageChannel.invokeMethod<String>('pickVideo');
      if (path == null || path.isEmpty) return;
      if (mounted) setState(() => _videoPath = path);
    } catch (_) {
      if (mounted) showAppToast(context, tr('compose_video_failed'));
    }
  }

  Widget _attachButton(IconData icon, String label, VoidCallback onTap) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final grey = dark ? const Color(0xFF8A8578) : const Color(0xFF9A917F);
    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 22, color: grey),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: grey, fontSize: 14)),
        ],
      ),
    );
  }

  /// 已选附件行：值 + 删除叉号（附件不进草稿，删了就没了）。
  Widget _attachedRow(IconData icon, String value, VoidCallback onClear) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final grey = dark ? const Color(0xFF8A8578) : const Color(0xFF9A917F);
    return Row(
      children: [
        Icon(icon, size: 16, color: grey),
        const SizedBox(width: 6),
        Expanded(
          child: Text(value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: grey, fontSize: 13)),
        ),
        GestureDetector(
          onTap: onClear,
          child: Icon(Icons.close, size: 16, color: grey),
        ),
      ],
    );
  }

  void _publish() {
    final content = _contentCtrl.text.trim();
    if (content.isEmpty) {
      showAppToast(context, tr('compose_body_empty'));
      return;
    }
    final err = communityStore.createPost(
      title: _titleCtrl.text,
      content: content,
      board: _board,
      images: _images,
      location: _location,
      weather: _weather,
      videoPath: _videoPath,
    );
    if (err != null) {
      if (err == tr('store_err_not_logged')) {
        showAppToast(context, tr('login_required_body'));
      } else if (err == tr('store_err_muted') ||
          err == tr('store_err_banned') ||
          err == tr('store_err_board_closed')) {
        showAppToast(context, err);
      } else {
        showAppToast(context, err);
      }
      return;
    }
    // 发布成功返回 true，让动态页提示（签到已随任务屏删除，不再自动签到）。
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final grey = dark ? const Color(0xFF8A8578) : const Color(0xFF9A917F);
    final fg = dark ? const Color(0xFFF5F0E6) : const Color(0xFF1E1B16);
    final me = communityStore.current;
    final hasDraft = communityStore.draft != null;
    final boards = communityBoards
        .where((b) => !communityStore.disabledBoards.contains(b))
        .toList();
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            // 顶行：左边取消，右边液态玻璃发布按钮。
            Row(
              children: [
                TextButton(
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(48, 40),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(tr('cancel'),
                      style: TextStyle(color: fg, fontSize: 16)),
                ),
                const Spacer(),
                // 只监听正文变化刷新按钮的可用外观，不整页重建。
                AnimatedBuilder(
                  animation: _contentCtrl,
                  builder: (_, __) => _GlassPublishButton(
                    enabled: _contentCtrl.text.trim().isNotEmpty,
                    onTap: _publish,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // 头像 + 用户名一行。
            Row(
              children: [
                communityAvatar(
                  bytes: me?.avatarBytes,
                  color: me?.avatarColor ?? const Color(0xFFB8B8B8),
                  nickname: me?.nickname ?? '',
                  radius: 20,
                  frame: me?.avatarFrame ?? '',
                  verified: me == null ? false : isSpecialAccount(me),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    me?.nickname ?? tr('login'),
                    style: TextStyle(
                        color: fg,
                        fontSize: 15,
                        fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // 标题（可选）：无边框单行，保留原有能力。
            TextField(
              controller: _titleCtrl,
              onChanged: (_) => _saveDraft(),
              style: TextStyle(
                  color: fg, fontSize: 16, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                hintText: tr('compose_title_hint'),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
            // 板块：中性文字选项，选中加粗，不用彩色填充。
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: boards.map((b) {
                  final selected = _board == b;
                  return GestureDetector(
                    onTap: () {
                      setState(() => _board = b);
                      _saveDraft();
                    },
                    child: Padding(
                      padding: const EdgeInsets.only(right: 16, top: 10),
                      child: Text(
                        trBoard(b),
                        style: TextStyle(
                          color: selected ? fg : grey,
                          fontSize: 13,
                          fontWeight:
                              selected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 12),
            // 正文：大面积无边框纯文本输入框。
            TextField(
              controller: _contentCtrl,
              onChanged: (_) => _saveDraft(),
              minLines: 10,
              maxLines: null,
              keyboardType: TextInputType.multiline,
              style: TextStyle(color: fg, fontSize: 16, height: 1.5),
              decoration: InputDecoration(
                hintText: tr('compose_body_hint'),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const SizedBox(height: 8),
            Text(tr('compose_tag_note'),
                style: TextStyle(color: grey, fontSize: 12)),
            const SizedBox(height: 16),
            // 附件行：图片 / 定位 / 天气快照 / 视频。
            Wrap(
              spacing: 20,
              runSpacing: 12,
              children: [
                _attachButton(
                  Icons.add_photo_alternate_outlined,
                  _images.isEmpty
                      ? tr('compose_add_image')
                      : tr('compose_add_image_prefix') +
                          '${_images.length}' +
                          tr('compose_add_image_suffix'),
                  _addImage,
                ),
                _attachButton(
                  Icons.location_on_outlined,
                  _location.isEmpty
                      ? tr('compose_add_location')
                      : tr('compose_location_added'),
                  _addLocation,
                ),
                _attachButton(
                  Icons.cloud_outlined,
                  _weather.isEmpty
                      ? tr('compose_add_weather')
                      : tr('compose_weather_added'),
                  _addWeather,
                ),
                _attachButton(
                  Icons.videocam_outlined,
                  _videoPath.isEmpty
                      ? tr('compose_add_video')
                      : _videoPath.split('/').last,
                  _addVideo,
                ),
              ],
            ),
            if (_location.isNotEmpty) ...[
              const SizedBox(height: 10),
              _attachedRow(Icons.location_on_outlined, _location,
                  () => setState(() => _location = '')),
            ],
            if (_weather.isNotEmpty) ...[
              const SizedBox(height: 8),
              _attachedRow(Icons.cloud_outlined, _weather,
                  () => setState(() => _weather = '')),
            ],
            if (_videoPath.isNotEmpty) ...[
              const SizedBox(height: 8),
              _attachedRow(Icons.videocam_outlined,
                  _videoPath.split('/').last,
                  () => setState(() => _videoPath = '')),
            ],
            if (_images.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _images.asMap().entries.map((e) {
                  return Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.memory(
                          e.value,
                          width: 110,
                          height: 110,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        right: 2,
                        top: 2,
                        child: GestureDetector(
                          onTap: () => setState(() => _images.removeAt(e.key)),
                          child: Container(
                            decoration: const BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close,
                                size: 18, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ],
            const SizedBox(height: 24),
            // 底部：草稿说明 + 清除草稿（仅有草稿时出现）。
            Row(
              children: [
                Expanded(
                  child: Text(tr('compose_draft_note'),
                      style: TextStyle(color: grey, fontSize: 12)),
                ),
                if (hasDraft)
                  GestureDetector(
                    onTap: () {
                      communityStore.clearDraft();
                      setState(() {
                        _titleCtrl.clear();
                        _contentCtrl.clear();
                        _board = '综合';
                        _images.clear();
                        _location = '';
                        _weather = '';
                        _videoPath = '';
                      });
                    },
                    child: Text(tr('compose_clear_draft'),
                        style: TextStyle(color: grey, fontSize: 12)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 液态玻璃发布按钮：药丸形，底只用 [LiquidGlassBackdrop] 的折射
/// （着色器不可用时自动退回毛玻璃），不设任何背景色与描边；
/// 文字用主题前景色（白天近黑、夜晚近白）；内容为空时只把文字
/// 降透明度，不换颜色。
class _GlassPublishButton extends StatelessWidget {
  const _GlassPublishButton({required this.enabled, required this.onTap});

  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final fg = dark ? const Color(0xFFF5F0E6) : const Color(0xFF1E1B16);
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        // 发布按钮保持旧强度（tint 0.08 / blur 28），2.2.5 只加重底部导航。
        child: LiquidGlassBackdrop(
          radius: 18,
          tint: 0.08,
          fallbackSigma: 28,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Text(
              tr('publish'),
              style: TextStyle(
                color: fg.withValues(alpha: enabled ? 1 : 0.4),
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
