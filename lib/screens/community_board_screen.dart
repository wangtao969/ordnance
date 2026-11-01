import 'package:flutter/material.dart';
import '../community_store.dart';
import '../i18n.dart';
import '../widgets/app_top_bar.dart';
import '../widgets/community_theme.dart';
import '../widgets/level_badge.dart';
import 'community_account_dialogs.dart';
import 'community_post_detail_screen.dart';
import 'community_profile_screen.dart';

/// 板块论坛页：点板块大卡片进来后的帖子列表，像论坛主题帖一样排。
/// board 为 '全部' 时显示全部帖子；支持站内搜索、最新/最热排序、话题筛选。
class CommunityBoardScreen extends StatefulWidget {
  final String board;
  final String initialQuery;
  final String? initialTag;
  const CommunityBoardScreen({
    super.key,
    required this.board,
    this.initialQuery = '',
    this.initialTag,
  });

  @override
  State<CommunityBoardScreen> createState() => _CommunityBoardScreenState();
}

class _CommunityBoardScreenState extends State<CommunityBoardScreen> {
  late String _query;
  String _sort = 'time'; // time 最新 / hot 最热
  String? _tag;
  bool _showSearch = false;
  final _expandedReported = <String>{};
  late final TextEditingController _searchCtrl;

  @override
  void initState() {
    super.initState();
    _query = widget.initialQuery;
    _tag = widget.initialTag;
    _searchCtrl = TextEditingController(text: widget.initialQuery);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<CommunityPost> _visiblePosts() {
    var list = communityStore.posts.where((p) {
      if (widget.board != '全部' && p.board != widget.board) return false;
      if (_tag != null && !p.tags.contains(_tag)) return false;
      if (_query.isNotEmpty) {
        final q = _query.toLowerCase();
        if (!p.title.toLowerCase().contains(q) &&
            !p.content.toLowerCase().contains(q) &&
            !p.tags.any((t) => t.toLowerCase().contains(q))) {
          return false;
        }
      }
      return true;
    }).toList();
    final pinned = list.where((p) => p.pinned).toList();
    final rest = list.where((p) => !p.pinned).toList();
    if (_sort == 'hot') {
      rest.sort((a, b) => b.hotScore.compareTo(a.hotScore));
    } else {
      rest.sort((a, b) => b.time.compareTo(a.time));
    }
    return [...pinned, ...rest];
  }

  Widget _threadRow(CommunityPost p, Color grey) {
    return _ThreadRow(
      post: p,
      grey: grey,
      showBoard: widget.board == '全部',
      reportedExpanded: _expandedReported.contains(p.id),
      onExpandReported: () => setState(() => _expandedReported.add(p.id)),
      onOpen: () => Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => CommunityPostDetailScreen(post: p)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final grey = communitySecondary(dark);
    return AnimatedBuilder(
      animation: communityStore,
      builder: (_, __) {
        final visible = _visiblePosts();
        final me = communityStore.current;
        final boardPosts = widget.board == '全部'
            ? communityStore.posts
            : communityStore.posts
                .where((p) => p.board == widget.board)
                .toList();
        final heat = boardPosts.fold<int>(
            0, (sum, p) => sum + p.likedBy.length + p.comments.length);
        final latestWithImage = boardPosts
            .where((p) => p.images.isNotEmpty)
            .toList();
        final followed = me != null &&
            widget.board != '全部' &&
            me.followedBoards.contains(widget.board);
        return Scaffold(
          appBar: SubPageAppBar(title: widget.board == '全部' ? tr('board_all_posts') : trBoard(widget.board)),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // 发布入口已移到第 11 项的底部导航中间＋号，板块页不再放发布按钮。
              Row(
                children: [
                  const Spacer(),
                  IconButton(
                    onPressed: () =>
                        setState(() => _showSearch = !_showSearch),
                    icon: const Icon(Icons.search),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // 板块头：封面图 + 图标圆环 + 简介 + 帖子数 + 热度 + 关注。
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    children: [
                      SizedBox(
                        height: 72,
                        width: double.infinity,
                        child: latestWithImage.isNotEmpty
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.memory(
                                  latestWithImage.first.images.first,
                                  fit: BoxFit.cover,
                                ),
                              )
                            : Image.asset(
                                boardCover(widget.board),
                                fit: BoxFit.contain,
                              ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: const Color(0xFF8C6A2F),
                                  width: 1.5),
                            ),
                            child: Icon(boardIcon(widget.board),
                                size: 22,
                                color: const Color(0xFF8C6A2F)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.board == '全部' ? tr('board_all_posts') : trBoard(widget.board),
                                  style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _boardDescription(widget.board),
                                  style: TextStyle(
                                      color: grey, fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('${boardPosts.length}' + tr('board_posts_suffix'),
                                  style: TextStyle(
                                      color: grey, fontSize: 12)),
                              Text(tr('board_heat_prefix') + '$heat',
                                  style: TextStyle(
                                      color: grey, fontSize: 12)),
                            ],
                          ),
                        ],
                      ),
                      if (widget.board != '全部') ...[
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: () {
                              if (me == null) {
                                askLoginDialog(context);
                                return;
                              }
                              communityStore
                                  .toggleBoardFollow(widget.board);
                            },
                            child: Text(followed ? tr('board_followed') : tr('board_follow')),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (_showSearch) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchCtrl,
                        autofocus: true,
                        onChanged: (v) =>
                            setState(() => _query = v.trim()),
                        // 聚焦边与未聚焦同一支（圆角 20 灰边）：只写 border 时
                        // 聚焦会回落全局橙色圆角 12 边，框里再冒一个框。
                        decoration: InputDecoration(
                          hintText: tr('board_search_hint'),
                          prefixIcon: const Icon(Icons.search),
                          border: const OutlineInputBorder(
                            borderRadius:
                                BorderRadius.all(Radius.circular(20)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: const BorderRadius.all(
                                Radius.circular(20)),
                            borderSide: BorderSide(
                                color:
                                    Colors.grey.withValues(alpha: 0.35)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: const BorderRadius.all(
                                Radius.circular(20)),
                            borderSide: BorderSide(
                                color:
                                    Colors.grey.withValues(alpha: 0.35)),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() {
                          _query = '';
                          _showSearch = false;
                        });
                      },
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  ChoiceChip(
                    label: Text(tr('board_latest')),
                    selected: _sort == 'time',
                    selectedColor: const Color(0xFF6B5B3E),
                    labelStyle: TextStyle(
                        color: _sort == 'time' ? Colors.white : null),
                    side: _sort == 'time'
                        ? const BorderSide(color: Color(0xFF6B5B3E))
                        : null,
                    onSelected: (_) => setState(() => _sort = 'time'),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: Text(tr('board_hottest')),
                    selected: _sort == 'hot',
                    selectedColor: const Color(0xFF6B5B3E),
                    labelStyle: TextStyle(
                        color: _sort == 'hot' ? Colors.white : null),
                    side: _sort == 'hot'
                        ? const BorderSide(color: Color(0xFF6B5B3E))
                        : null,
                    onSelected: (_) => setState(() => _sort = 'hot'),
                  ),
                  if (_tag != null) ...[
                    const SizedBox(width: 8),
                    InputChip(
                      label: Text('#$_tag#'),
                      onDeleted: () => setState(() => _tag = null),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 16),
              if (visible.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 32),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.forum_outlined, size: 48, color: grey),
                        const SizedBox(height: 12),
                        Text(
                            boardPosts.isEmpty &&
                                    _query.isEmpty &&
                                    _tag == null
                                ? tr('board_empty')
                                : tr('no_posts'),
                            style: TextStyle(color: grey)),
                        const SizedBox(height: 4),
                        Text(
                            boardPosts.isEmpty &&
                                    _query.isEmpty &&
                                    _tag == null
                                ? tr('board_empty_show')
                                : tr('no_posts_sub'),
                            style: TextStyle(color: grey, fontSize: 12)),
                        // 空板块不再放“发第一条”按钮，发布走底部导航＋号。
                      ],
                    ),
                  ),
                ),
              // 置顶帖单独成区（贴吧/虎扑式），其余是全部主题。
              if (visible.any((p) => p.pinned)) ...[
                _SectionLabel(tr('board_section_pinned')),
                ...visible
                    .where((p) => p.pinned)
                    .map((p) => _threadRow(p, grey)),
                _SectionLabel(tr('board_section_all')),
                ...visible
                    .where((p) => !p.pinned)
                    .map((p) => _threadRow(p, grey)),
              ] else
                ...visible.map((p) => _threadRow(p, grey)),
            ],
          ),
        );
      },
    );
  }
}

/// 论坛主题行：头像 + 标题 + 摘要 + 作者时间 + 回复点赞数，右侧有图时配缩略图。
class _ThreadRow extends StatelessWidget {
  final CommunityPost post;
  final Color grey;
  final bool showBoard;
  final bool reportedExpanded;
  final VoidCallback onExpandReported;
  final VoidCallback onOpen;
  const _ThreadRow({
    required this.post,
    required this.grey,
    required this.showBoard,
    required this.reportedExpanded,
    required this.onExpandReported,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final p = post;
    final reportedHidden = p.reported && !reportedExpanded;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: grey.withValues(alpha: 0.3)),
      ),
      child: InkWell(
        onTap: reportedHidden ? onExpandReported : onOpen,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () {
                  final account = communityStore.findAccount(p.authorId);
                  if (account != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              CommunityProfileScreen(account: account)),
                    );
                  }
                },
                child: communityAvatar(
                  bytes: p.authorAvatar,
                  color: p.authorColor,
                  nickname: p.authorNickname,
                  radius: 18,
                  frame: p.authorFrame,
                  verified: isVerifiedAuthorId(p.authorId),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (reportedHidden)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: grey.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(tr('board_reported_hidden')),
                      )
                    else ...[
                      Row(
                        children: [
                          Expanded(
                            child: Text(p.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15)),
                          ),
                          if (p.pinned) ...[
                            const SizedBox(width: 6),
                            _Badge(tr('board_badge_pinned'), Colors.red),
                          ],
                          if (p.essence) ...[
                            const SizedBox(width: 6),
                            _Badge(tr('board_badge_essence'), Colors.amber),
                          ],
                          if (p.reported) ...[
                            const SizedBox(width: 6),
                            _Badge(tr('board_badge_reported'), Colors.orange),
                          ],
                        ],
                      ),
                      if (p.content.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          p.content,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: grey, fontSize: 13),
                        ),
                      ],
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              p.authorNickname,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style:
                                  TextStyle(color: grey, fontSize: 12),
                            ),
                          ),
                          Builder(builder: (context) {
                            final account =
                                communityStore.findAccount(p.authorId);
                            if (account == null) {
                              return const SizedBox.shrink();
                            }
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6),
                              child: LevelBadge(account: account, nicknameFontSize: 12),
                            );
                          }),
                          Expanded(
                            child: Text(
                              '${CommunityStore.formatTime(p.time)}${showBoard ? ' · ${p.board}' : ''}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style:
                                  TextStyle(color: grey, fontSize: 12),
                            ),
                          ),
                          Text(
                            tr('board_replies_label') + ' ${p.comments.length} · ' + tr('board_likes_label') + ' ${p.likedBy.length}',
                            style: TextStyle(color: grey, fontSize: 12),
                          ),
                        ],
                      ),
                      // 论坛式最后回复行：最后一条评论的作者和时间。
                      if (p.comments.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          tr('board_last_reply_prefix') + '${p.comments.last.authorNickname} · ${CommunityStore.formatTime(p.comments.last.time)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: grey, fontSize: 12),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
              if (!reportedHidden && p.images.isNotEmpty) ...[
                const SizedBox(width: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.memory(
                    p.images.first,
                    width: 56,
                    height: 56,
                    fit: BoxFit.cover,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 分区小标题：置顶 / 全部主题。
class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      child: Text(text,
          style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Color(0xFF8C6A2F))),
    );
  }
}

/// 板块简介（板块头用）。
String _boardDescription(String board) {
  switch (board) {
    case '全部':
      return tr('board_desc_all');
    case '晒枪':
      return tr('board_desc_show');
    case '复装心得':
      return tr('board_desc_reload');
    case '求助问答':
      return tr('board_desc_qa');
    case '资讯':
      return tr('board_desc_news');
    case '枪械评测':
      return tr('board_desc_review');
    case '新手入门':
      return tr('board_desc_beginner');
    case '配件分享':
      return tr('board_desc_accessory');
    case '射击技巧':
      return tr('board_desc_skill');
    case '历史名枪':
      return tr('board_desc_history');
    case '靶场日记':
      return tr('board_desc_diary');
    default:
      return tr('board_desc_default');
  }
}

class _Badge extends StatelessWidget {
  final String text;
  final Color color;
  const _Badge(this.text, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text,
          style: const TextStyle(color: Colors.white, fontSize: 10)),
    );
  }
}
