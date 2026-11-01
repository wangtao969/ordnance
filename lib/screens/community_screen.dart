import 'dart:ui';
import '../widgets/app_toast.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../community_store.dart';
import '../i18n.dart';
import '../widgets/app_top_bar.dart';
import '../widgets/community_theme.dart';
import '../widgets/level_badge.dart';
import 'community_account_dialogs.dart';
import 'community_board_screen.dart';
import 'community_compose_screen.dart';
import 'community_dm_screen.dart';
import 'community_post_detail_screen.dart';
import 'community_profile_screen.dart';

/// 社区页（2.2.5 融合重构）：
/// 动态流是唯一主场；私信挂在右上角（信封 + 未读角标）；
/// 经验榜是动态流顶部一条可折叠横条（默认前三，点开展开完整榜），
/// 不再单独设排行榜 Tab；作者主页挂动态、成就墙、经验名次与私信。
/// 已删：社区 home 视图（平台活动、签到、任务区、板块 grid）、
/// 通知中心、任务屏、排行榜屏、入驻引导、管理后台。
/// 看板页与靶场成绩页保留（动态浏览维度与工具数据页）。
/// 数据保存在本机（见 community_store.dart），调试提示只在 debug 构建显示。
class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  String _feedTab = 'latest'; // latest 最新 / hot 推荐 / following 关注
  bool _showSearch = false;
  bool _rankExpanded = false;
  late final TextEditingController _searchCtrl;

  @override
  void initState() {
    super.initState();
    _searchCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _openComposer() async {
    if (communityStore.current == null) {
      askLoginDialog(context);
      return;
    }
    final published = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const CommunityComposeScreen()),
    );
    if (published == true && mounted) {
      showAppToast(context, tr('feed_post_success'));
    }
  }

  void _search(String q) {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) =>
              CommunityBoardScreen(board: '全部', initialQuery: q.trim())),
    );
  }

  List<CommunityPost> _feedPosts(CommunityAccount? me) {
    final all = communityStore.posts;
    switch (_feedTab) {
      case 'hot':
        final list = all.toList();
        list.sort((a, b) {
          final ea = a.essence ? 1 : 0;
          final eb = b.essence ? 1 : 0;
          if (eb != ea) return eb - ea;
          return b.hotScore.compareTo(a.hotScore);
        });
        return list;
      case 'following':
        if (me == null) return [];
        final list = all
            .where((p) =>
                me.followedBoards.contains(p.board) ||
                me.followingIds.contains(p.authorId))
            .toList();
        list.sort((a, b) => b.time.compareTo(a.time));
        return list;
      default:
        final list = all.toList();
        list.sort((a, b) => b.time.compareTo(a.time));
        return list;
    }
  }

  void _openBoard(String board) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CommunityBoardScreen(board: board)),
    );
  }

  void _openProfile(CommunityAccount account) {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => CommunityProfileScreen(account: account)),
    );
  }

  Widget _segTab(String label, bool selected, VoidCallback onTap) {
    const bronze = Color(0xFF6B5B3E);
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected ? bronze : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: selected
                    ? bronze
                    : Colors.grey.withValues(alpha: 0.4)),
          ),
          child: Center(
            child: Text(label,
                style: TextStyle(
                    color: selected ? Colors.white : null,
                    fontWeight:
                        selected ? FontWeight.bold : FontWeight.normal)),
          ),
        ),
      ),
    );
  }

  Widget _rankNumber(int rank) {
    final color = rank == 1
        ? const Color(0xFFD4AF37)
        : rank == 2
            ? const Color(0xFF9AA0A6)
            : rank == 3
                ? const Color(0xFFCD7F32)
                : Colors.grey;
    return Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      child: Text('$rank',
          style: const TextStyle(
              color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
    );
  }

  /// 经验榜横条：默认只显示前三，点标题行展开完整榜；
  /// 登录后标题行右侧显示本人的名次。
  Widget _rankStrip(CommunityAccount? current, Color grey) {
    final accounts = communityStore.accounts.toList();
    accounts.sort((a, b) => b.totalXp.compareTo(a.totalXp));
    int? myRank;
    if (current != null) {
      final i = accounts.indexWhere((a) => a.id == current.id);
      if (i >= 0) myRank = i + 1;
    }
    final shown = _rankExpanded ? accounts : accounts.take(3).toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: () => setState(() => _rankExpanded = !_rankExpanded),
              borderRadius: BorderRadius.circular(8),
              child: Row(
                children: [
                  const Icon(Icons.emoji_events_outlined, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(tr('rank_strip_title'),
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15)),
                  ),
                  if (current != null && myRank != null)
                    Text(
                        tr('rank_my_prefix') +
                            '$myRank' +
                            tr('rank_my_suffix'),
                        style: TextStyle(color: grey, fontSize: 12)),
                  const SizedBox(width: 4),
                  Text(
                      _rankExpanded
                          ? tr('rank_collapse')
                          : tr('rank_expand'),
                      style: TextStyle(color: grey, fontSize: 12)),
                  Icon(
                      _rankExpanded
                          ? Icons.expand_less
                          : Icons.expand_more,
                      size: 18,
                      color: grey),
                ],
              ),
            ),
            const SizedBox(height: 8),
            if (accounts.isEmpty)
              Text(tr('rank_no_users'),
                  style: TextStyle(color: grey, fontSize: 13))
            else
              for (var i = 0; i < shown.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: InkWell(
                    onTap: () => _openProfile(shown[i]),
                    borderRadius: BorderRadius.circular(8),
                    child: Row(
                      children: [
                        _rankNumber(i + 1),
                        const SizedBox(width: 10),
                        communityAvatar(
                          bytes: shown[i].avatarBytes,
                          color: shown[i].avatarColor,
                          nickname: shown[i].nickname,
                          radius: 14,
                          frame: shown[i].avatarFrame,
                          verified: isSpecialAccount(shown[i]),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(shown[i].nickname,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontWeight:
                                      current != null && shown[i].id == current.id
                                          ? FontWeight.bold
                                          : FontWeight.normal)),
                        ),
                        Text(
                            tr('rank_xp_prefix') + '${shown[i].totalXp}',
                            style: TextStyle(color: grey, fontSize: 12)),
                      ],
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }

  Widget _postCard(CommunityPost p, Color grey) {
    final authorAccount = communityStore.findAccount(p.authorId);
    final metaStyle = TextStyle(color: grey, fontSize: 12);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: grey.withValues(alpha: 0.3)),
      ),
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => CommunityPostDetailScreen(post: p)),
        ),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () {
                  if (authorAccount != null) _openProfile(authorAccount);
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
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: const Color(0xFFD4A017)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.emoji_events_outlined,
                                    size: 12, color: Color(0xFFD4A017)),
                                const SizedBox(width: 2),
                                Text(tr('achievement_badge'),
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFFD4A017),
                                        fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(p.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15)),
                    if (p.content.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(p.content,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: grey, fontSize: 13)),
                    ],
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(
                            '${CommunityStore.formatTime(p.time)} · ',
                            style: metaStyle),
                        Flexible(
                          child: GestureDetector(
                            onTap: () => _openBoard(p.board),
                            child: Text(trBoard(p.board),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    color: communityAccent,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold)),
                          ),
                        ),
                        Text(
                            tr('feed_replies_prefix') +
                                '${p.comments.length}' +
                                tr('feed_replies_suffix') +
                                tr('feed_likes_prefix') +
                                '${p.likedBy.length}' +
                                tr('feed_likes_suffix'),
                            style: metaStyle),
                      ],
                    ),
                  ],
                ),
              ),
              if (p.images.isNotEmpty) ...[
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

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final grey = communitySecondary(dark);
    return ValueListenableBuilder<String>(
      valueListenable: localeNotifier,
      builder: (_, __, ___) => AnimatedBuilder(
        animation: communityStore,
        builder: (_, __) {
          final current = communityStore.current;
          final unreadDm = current == null
              ? 0
              : communityStore
                  .notificationsFor(current.id)
                  .where((n) => n.kind == 'dm' && !n.read)
                  .length;
          final feed = _feedPosts(current);
          return Scaffold(
            // 内层 Scaffold 不跟键盘走：键盘弹起时 body 不收缩，
            // 右下角发帖钮（Positioned bottom: 100）不再跟着上移。
            resizeToAvoidBottomInset: false,
            extendBodyBehindAppBar: true,
            appBar: const OrdnanceAppBar(),
            body: Padding(
              padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top + kToolbarHeight),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Row(
                      children: [
                        Text(tr('community_title'),
                            style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold)),
                        const Spacer(),
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            IconButton(
                              tooltip: tr('my_dms'),
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        const CommunityDmScreen()),
                              ),
                              icon: const Icon(Icons.mail_outlined),
                            ),
                            if (unreadDm > 0)
                              Positioned(
                                right: 6,
                                top: 6,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 5, vertical: 1),
                                  decoration: const BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Text(
                                      unreadDm > 99 ? '99+' : '$unreadDm',
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold)),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Stack(
                      children: [
                        ListView(
                          padding:
                              const EdgeInsets.fromLTRB(16, 8, 16, 110),
                          children: [
                            if (!kReleaseMode) ...[
                              Text(tr('community_note'),
                                  style:
                                      TextStyle(color: grey, fontSize: 12)),
                              const SizedBox(height: 10),
                            ],
                            // 搜索：上面这一个药丸框就是输入框，点开后直接在里面输入，
                            // 不再在下面另起一个搜索框；收起用框内叉号。
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                    color: Colors.grey.withValues(alpha: 0.4)),
                              ),
                              child: _showSearch
                                  ? Row(
                                      children: [
                                        const Icon(Icons.search, size: 18),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: TextField(
                                            controller: _searchCtrl,
                                            autofocus: true,
                                            onSubmitted: _search,
                                            // TextField 本身任何状态都不画框，只剩外层药丸容器一个框：
                                            // focusedBorder 不写会回落全局主题的橙色聚焦边，聚焦时
                                            // 药丸里会再冒出一个橙色框。
                                            decoration: InputDecoration(
                                              hintText: tr('feed_search_hint'),
                                              border: InputBorder.none,
                                              enabledBorder: InputBorder.none,
                                              focusedBorder: InputBorder.none,
                                              disabledBorder: InputBorder.none,
                                              errorBorder: InputBorder.none,
                                              isDense: true,
                                              contentPadding: EdgeInsets.zero,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        GestureDetector(
                                          onTap: () {
                                            _searchCtrl.clear();
                                            setState(
                                                () => _showSearch = false);
                                          },
                                          child: const Icon(Icons.close,
                                              size: 18),
                                        ),
                                      ],
                                    )
                                  : InkWell(
                                      onTap: () => setState(
                                          () => _showSearch = true),
                                      borderRadius: BorderRadius.circular(20),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.search, size: 18),
                                          const SizedBox(width: 8),
                                          Text(tr('feed_search_hint'),
                                              style: TextStyle(
                                                  color: grey,
                                                  fontSize: 13)),
                                        ],
                                      ),
                                    ),
                            ),
                            const SizedBox(height: 16),
                            // 内容流三档：最新 / 推荐 / 关注。
                            Row(
                              children: [
                                _segTab(tr('feed_latest'),
                                    _feedTab == 'latest',
                                    () => setState(
                                        () => _feedTab = 'latest')),
                                const SizedBox(width: 8),
                                _segTab(tr('feed_hot'), _feedTab == 'hot',
                                    () => setState(() => _feedTab = 'hot')),
                                const SizedBox(width: 8),
                                _segTab(tr('feed_following'),
                                    _feedTab == 'following',
                                    () => setState(
                                        () => _feedTab = 'following')),
                              ],
                            ),
                            const SizedBox(height: 12),
                            _rankStrip(current, grey),
                            const SizedBox(height: 12),
                            if (feed.isEmpty)
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 24),
                                child: Center(
                                  child: Column(
                                    children: [
                                      Icon(Icons.forum_outlined,
                                          size: 48, color: grey),
                                      const SizedBox(height: 12),
                                      Text(
                                        _feedTab == 'following'
                                            ? tr('feed_empty_following')
                                            : tr('feed_empty'),
                                        textAlign: TextAlign.center,
                                        style: TextStyle(color: grey),
                                      ),
                                      const SizedBox(height: 12),
                                      OutlinedButton(
                                        onPressed: _openComposer,
                                        child: Text(tr('feed_post_first')),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            else
                              ...feed.map((p) => _postCard(p, grey)),
                            const SizedBox(height: 8),
                          ],
                        ),
                        // 动态页右下角发帖钮：大号圆形液态玻璃（草稿箱已去掉，
                        // 草稿仍在发帖器里自动带出，不用单独入口）。
                        Positioned(
                          right: 16,
                          bottom: 100,
                          child: GestureDetector(
                            onTap: _openComposer,
                            child: ClipOval(
                              child: BackdropFilter(
                                filter: ImageFilter.blur(
                                    sigmaX: 25, sigmaY: 25),
                                child: Container(
                                  width: 64,
                                  height: 64,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: dark
                                          ? [
                                              const Color(0xFFC9A86A)
                                                  .withValues(alpha: 0.85),
                                              const Color(0xFF6B5B3E)
                                                  .withValues(alpha: 0.60),
                                            ]
                                          : [
                                              const Color(0xFF6B5B3E)
                                                  .withValues(alpha: 0.85),
                                              const Color(0xFF6B5B3E)
                                                  .withValues(alpha: 0.60),
                                            ],
                                    ),
                                    border: Border.all(
                                      color: Colors.white
                                          .withValues(alpha: 0.45),
                                      width: 1.2,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black
                                            .withValues(alpha: 0.18),
                                        blurRadius: 16,
                                        offset: const Offset(0, 6),
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    Icons.edit_outlined,
                                    size: 28,
                                    color: dark
                                        ? const Color(0xFF000000)
                                        : Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
