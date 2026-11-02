import 'dart:io';
import 'package:flutter/material.dart';
import '../widgets/app_toast.dart';
import 'package:flutter/services.dart';
import '../community_store.dart';
import '../i18n.dart';
import '../location_flow.dart';
import '../system_actions.dart';
import '../widgets/app_top_bar.dart';
import '../widgets/community_theme.dart';
import '../widgets/level_badge.dart';
import '../widgets/score_grade_chip.dart';
import '../widgets/map_preview.dart';
import '../widgets/poll_card.dart';
import 'community_board_screen.dart';
import 'community_profile_screen.dart';

/// 帖子详情：完整内容、图片、@高亮、点赞收藏分享、评论列表、底部快捷回复。
/// 附件行：定位、天气快照、视频系统播放；成就动态在昵称行带成就 chip。
/// 作者本人的管理菜单：置顶 / 精华 / 删除；别人的帖子：举报。
class CommunityPostDetailScreen extends StatefulWidget {
  final CommunityPost post;
  const CommunityPostDetailScreen({super.key, required this.post});

  @override
  State<CommunityPostDetailScreen> createState() =>
      _CommunityPostDetailScreenState();
}

class _CommunityPostDetailScreenState
    extends State<CommunityPostDetailScreen> {
  static const _shareChannel = MethodChannel('gunsmap/share');
  final _replyCtrl = TextEditingController();

  @override
  void dispose() {
    _replyCtrl.dispose();
    super.dispose();
  }

  /// 正文渲染：@ID 高亮为加粗棕色，话题保持原文。
  Widget _richContent(String content) {
    final spans = <TextSpan>[];
    final regex = RegExp(r'@([^\s@#]+)');
    var last = 0;
    for (final m in regex.allMatches(content)) {
      if (m.start > last) {
        spans.add(TextSpan(text: content.substring(last, m.start)));
      }
      spans.add(TextSpan(
        text: m.group(0),
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          color: Color(0xFF8C6A2F),
        ),
      ));
      last = m.end;
    }
    if (last < content.length) {
      spans.add(TextSpan(text: content.substring(last)));
    }
    return Text.rich(TextSpan(children: spans, style: const TextStyle(fontSize: 15)));
  }

  /// 视频附件系统播放：先查文件在不在——不在报“视频文件已丢失”，
  /// 在但原生返回 false 说明没有可播放视频的应用；两种都不闪退。
  Future<void> _playVideo(String path) async {
    if (!await File(path).exists()) {
      if (mounted) showAppToast(context, tr('post_video_missing'));
      return;
    }
    final ok = await openVideoFile(path);
    if (!ok && mounted) showAppToast(context, tr('post_video_no_player'));
  }

  Future<void> _share() async {
    final p = widget.post;
    // 分享文案后缀按语言切换（2.2.5 全量英文）。
    final suffix = localeNotifier.value == localeEn
        ? '— From the Gun’s Map community'
        : '—— 来自 Gun’s Map 社区';
    final text = '${p.title}\n${p.content}\n$suffix';
    try {
      // 分享优化（第 11 项）：有图时文字 + 图片 + 作者拼成一次系统分享
      // （shareImage 可选 text 参数，EXTRA_TEXT + EXTRA_STREAM 同发）；
      // 无图时仍走纯文字分享。
      if (p.images.isNotEmpty) {
        await _shareChannel.invokeMethod('shareImage', {
          'bytes': p.images.first,
          'text': text,
        });
      } else {
        await _shareChannel.invokeMethod('shareText', {'text': text});
      }
    } catch (_) {
      if (mounted) {
        showAppToast(context, tr('post_share_failed'));
      }
    }
  }

  void _sendReply() {
    final me = communityStore.current;
    if (me == null) {
      showAppToast(context, tr('login_required_body'));
      return;
    }
    final content = _replyCtrl.text.trim();
    if (content.isEmpty) return;
    final err = communityStore.addComment(widget.post, content);
    if (err != null) {
      showAppToast(context, err);
      return;
    }
    _replyCtrl.clear();
  }

  Future<void> _managementMenu() async {
    final p = widget.post;
    final me = communityStore.current;
    if (me == null) return;
    final isMine = me.id == p.authorId;
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isMine) ...[
              ListTile(
                leading: const Icon(Icons.push_pin_outlined),
                title: Text(p.pinned ? tr('admin_btn_unpin') : tr('admin_btn_pin')),
                onTap: () => Navigator.pop(context, 'pin'),
              ),
              ListTile(
                leading: const Icon(Icons.star_outline),
                title: Text(p.essence ? tr('admin_btn_unessence') : tr('post_set_essence')),
                onTap: () => Navigator.pop(context, 'essence'),
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: Text(tr('post_delete'),
                    style: TextStyle(color: Colors.red)),
                onTap: () => Navigator.pop(context, 'delete'),
              ),
            ] else
              ListTile(
                leading: const Icon(Icons.flag_outlined),
                title: Text(tr('post_report')),
                onTap: () => Navigator.pop(context, 'report'),
              ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    switch (action) {
      case 'pin':
        communityStore.setPinned(p, !p.pinned);
        break;
      case 'essence':
        communityStore.setEssence(p, !p.essence);
        break;
      case 'delete':
        final confirm = await showDialog<bool>(
          context: context,
          builder: (d) => AlertDialog(
            title: Text(tr('post_delete_title')),
            content: Text(tr('admin_delete_post_body')),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(d, false),
                  child: Text(tr('cancel'))),
              TextButton(
                  onPressed: () => Navigator.pop(d, true),
                  child: Text(tr('admin_btn_delete'),
                      style: TextStyle(color: Colors.red))),
            ],
          ),
        );
        if (confirm == true) {
          communityStore.deletePost(p);
          if (mounted) Navigator.of(context).pop();
        }
        break;
      case 'report':
        final reasons = [('违法违规', 'post_report_reason_illegal'), ('辱骂攻击', 'post_report_reason_abuse'), ('广告引流', 'post_report_reason_ads'), ('与枪无关', 'post_report_reason_offtopic'), ('其他', 'feedback_type_other')];
        final reason = await showDialog<String>(
          context: context,
          builder: (d) => AlertDialog(
            title: Text(tr('post_report_title')),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: reasons
                  .map((r) => ListTile(
                        title: Text(tr(r.$2)),
                        onTap: () => Navigator.pop(d, r.$1),
                      ))
                  .toList(),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(d),
                  child: Text(tr('cancel'))),
            ],
          ),
        );
        if (reason != null && mounted) {
          communityStore.reportPost(p, reason);
          showAppToast(context, tr('post_reported'));
        }
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final grey = communitySecondary(dark);
    return AnimatedBuilder(
      animation: communityStore,
      builder: (_, __) {
        final p = widget.post;
        final me = communityStore.current;
        final liked = me != null && p.likedBy.contains(me.id);
        final favorited = me != null && p.favoritedBy.contains(me.id);
        final authorAccount = communityStore.findAccount(p.authorId);
        return Scaffold(
          appBar: SubPageAppBar(title: tr('post_detail_title')),
          body: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () {
                            if (authorAccount != null) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => CommunityProfileScreen(
                                        account: authorAccount)),
                              );
                            }
                          },
                          child: communityAvatar(
                            bytes: p.authorAvatar,
                            color: p.authorColor,
                            nickname: p.authorNickname,
                            radius: 20,
                            frame: p.authorFrame,
                            verified: isVerifiedAuthorId(p.authorId),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(p.authorNickname,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold)),
                                  ),
                                  if (authorAccount != null) ...[
                                    const SizedBox(width: 6),
                                    LevelBadge(account: authorAccount),
                                  ],
                                  if (p.achievement.isNotEmpty) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 1),
                                      decoration: BoxDecoration(
                                        borderRadius:
                                            BorderRadius.circular(8),
                                        border: Border.all(
                                            color:
                                                const Color(0xFFD4A017)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                              Icons.emoji_events_outlined,
                                              size: 12,
                                              color: Color(0xFFD4A017)),
                                          const SizedBox(width: 2),
                                          Text(tr('achievement_badge'),
                                              style: const TextStyle(
                                                  fontSize: 11,
                                                  color: Color(0xFFD4A017),
                                                  fontWeight:
                                                      FontWeight.bold)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              Text(
                                  '${CommunityStore.formatTime(p.time)} · ${trBoard(p.board)}',
                                  style: TextStyle(color: grey, fontSize: 12)),
                            ],
                          ),
                        ),
                        if (me != null)
                          IconButton(
                            onPressed: _managementMenu,
                            icon: const Icon(Icons.more_horiz),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(p.title,
                              style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold)),
                        ),
                        // 靶场成绩公开动态的系统档位徽章。
                        if (p.scoreGrade.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          ScoreGradeChip(grade: p.scoreGrade),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (p.content.isNotEmpty) _richContent(p.content),
                    if (p.tags.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 6,
                        children: p.tags
                            .map((t) => GestureDetector(
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) =>
                                            CommunityBoardScreen(
                                                board: '全部',
                                                initialTag: t)),
                                  ),
                                  child: Chip(
                                    label: Text('#$t#'),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ))
                            .toList(),
                      ),
                    ],
                    if (p.images.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      for (final img in p.images) ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.memory(img, fit: BoxFit.cover),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ],
                    // 发帖附件行（tags/图片区之后）：定位、天气快照、视频播放。
                    // 定位是经纬度时显示地图预览 + 地名（反查不到回落经纬度），
                    // 纯地名时仍按原样显示文字。
                    if (p.location.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Builder(
                        builder: (_) {
                          final coords = parseLatLon(p.location);
                          if (coords == null) {
                            return Row(
                              children: [
                                Icon(Icons.location_on_outlined,
                                    size: 16, color: grey),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(p.location,
                                      style: TextStyle(
                                          color: grey, fontSize: 13)),
                                ),
                              ],
                            );
                          }
                          return MapPreview(
                              lat: coords.lat, lon: coords.lon);
                        },
                      ),
                    ],
                    if (p.weather.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.cloud_outlined,
                              size: 16, color: grey),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(p.weather,
                                style: TextStyle(
                                    color: grey, fontSize: 13)),
                          ),
                        ],
                      ),
                    ],
                    if (p.videoPath.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: () => _playVideo(p.videoPath),
                        icon: const Icon(Icons.play_circle_outlined,
                            size: 20),
                        label: Text(p.videoPath.split('/').last),
                      ),
                    ],
                    // 投票区（第 11 项）：选项 + 票数 + 百分比，点选项投票。
                    if (p.pollOptions.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      PollCard(post: p),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        TextButton.icon(
                          onPressed: me == null
                              ? null
                              : () => communityStore.toggleLike(p),
                          icon: Icon(liked
                              ? Icons.thumb_up
                              : Icons.thumb_up_outlined),
                          label: Text('${p.likedBy.length}'),
                        ),
                        TextButton.icon(
                          onPressed: me == null
                              ? null
                              : () => communityStore.toggleFavorite(p),
                          icon: Icon(
                              favorited ? Icons.star : Icons.star_border),
                          label: Text('${p.favoritedBy.length}'),
                        ),
                        TextButton.icon(
                          onPressed: _share,
                          icon: const Icon(Icons.share_outlined),
                          label: Text(tr('post_share')),
                        ),
                        if (p.reported) ...[
                          const Spacer(),
                          Text(tr('post_reported_badge'),
                              style: TextStyle(
                                  color: Colors.orange, fontSize: 12)),
                        ],
                      ],
                    ),
                    const Divider(),
                    Text(tr('post_comments_prefix') + '${p.comments.length}' + tr('post_comments_suffix'),
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    if (p.comments.isEmpty)
                      Text(tr('post_no_comments'),
                          style: TextStyle(color: grey)),
                    ...p.comments.map((c) {
                      final cLiked =
                          me != null && c.likedBy.contains(me.id);
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  communityAvatar(
                                    bytes: c.authorAvatar,
                                    color: c.authorColor,
                                    nickname: c.authorNickname,
                                    radius: 14,
                                    frame: c.authorFrame,
                                    verified: isVerifiedAuthorId(c.authorId),
                                  ),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(c.authorNickname,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13)),
                                  ),
                                  Builder(builder: (_) {
                                    final account = communityStore
                                        .findAccount(c.authorId);
                                    if (account == null) {
                                      return const SizedBox.shrink();
                                    }
                                    return Padding(
                                      padding: const EdgeInsets.only(
                                          right: 6),
                                      child: LevelBadge(account: account, nicknameFontSize: 13),
                                    );
                                  }),
                                  const Spacer(),
                                  Text(CommunityStore.formatTime(c.time),
                                      style: TextStyle(
                                          color: grey, fontSize: 11)),
                                ],
                              ),
                              const SizedBox(height: 6),
                              _richContent(c.content),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  TextButton.icon(
                                    onPressed: me == null
                                        ? null
                                        : () => communityStore
                                            .toggleCommentLike(p, c),
                                    icon: Icon(
                                        cLiked
                                            ? Icons.thumb_up
                                            : Icons.thumb_up_outlined,
                                        size: 16),
                                    label: Text('${c.likedBy.length}'),
                                  ),
                                  TextButton(
                                    onPressed: me == null
                                        ? null
                                        : () {
                                            _replyCtrl.text =
                                                '@${c.authorId} ';
                                            _replyCtrl.selection =
                                                TextSelection.fromPosition(
                                              TextPosition(
                                                  offset:
                                                      _replyCtrl.text.length),
                                            );
                                          },
                                    child: Text(tr('post_reply')),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
              SafeArea(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    border: Border(
                        top: BorderSide(
                            color: grey.withValues(alpha: 0.3))),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _replyCtrl,
                          decoration: InputDecoration(
                            hintText: tr('post_reply_hint'),
                            border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: _sendReply,
                        icon: const Icon(Icons.send),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
