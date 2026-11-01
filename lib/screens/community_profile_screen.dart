import 'package:flutter/material.dart';
import '../community_store.dart';
import '../i18n.dart';
import '../widgets/community_theme.dart';
import '../widgets/level_badge.dart';
import 'community_account_dialogs.dart';
import 'community_dm_screen.dart';
import 'community_post_detail_screen.dart';

/// 用户主页：头像 + LV + 铭牌 + 统计 + 经验名次，下分 帖子 / 收藏的动态 / 勋章墙 / 历史 四栏。
/// 自己的主页全可见；别人的主页：收藏的动态按对方的“收藏对外可见”开关决定是否展示。
class CommunityProfileScreen extends StatefulWidget {
  final CommunityAccount account;

  /// 打开时默认选中的栏：0 帖子 / 1 收藏 / 2 勋章墙 / 3 历史。
  final int initialTab;
  const CommunityProfileScreen(
      {super.key, required this.account, this.initialTab = 0});

  @override
  State<CommunityProfileScreen> createState() =>
      _CommunityProfileScreenState();
}

class _CommunityProfileScreenState extends State<CommunityProfileScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(
        length: 4, vsync: this, initialIndex: widget.initialTab);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  void _openPost(CommunityPost p) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CommunityPostDetailScreen(post: p)),
    );
  }

  void _showAccountList(String title, List<CommunityAccount> list) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: double.maxFinite,
          child: list.isEmpty
              ? const Text('还没有')
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: list.length,
                  itemBuilder: (_, i) {
                    final a = list[i];
                    return ListTile(
                      leading: communityAvatar(
                        bytes: a.avatarBytes,
                        color: a.avatarColor,
                        nickname: a.nickname,
                        radius: 16,
                        frame: a.avatarFrame,
                        verified: isSpecialAccount(a),
                      ),
                      title: Text(a.nickname),
                      subtitle:
                          Text('${tr('id_field')}：${a.id}'),
                      onTap: () {
                        Navigator.of(dialogContext).pop();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  CommunityProfileScreen(account: a)),
                        );
                      },
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(tr('close')),
          ),
        ],
      ),
    );
  }

  Widget _medalWall(CommunityAccount account, Color grey) {
    final earned = communityStore.earnedMedals(account);
    final earnedIds = earned.map((m) => m.id).toSet();
    const groups = ['签到', '收藏', '发帖', '获赞', '靶场', '品类', '挑战', '彩蛋'];
    const groupKeys = {'签到': 'medal_group_checkin', '收藏': 'medal_group_collect', '发帖': 'medal_group_post', '获赞': 'medal_group_like', '靶场': 'medal_group_range', '品类': 'medal_group_category', '挑战': 'medal_group_challenge', '彩蛋': 'medal_group_egg'};
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                const Icon(Icons.emoji_events_outlined,
                    color: communityAccent),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    tr('profile_earned_prefix') + '${earned.length} / ${medalCatalog.length}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        for (final g in groups) ...[
          Builder(builder: (_) {
            final medals =
                medalCatalog.where((m) => m.group == g).toList();
            final got =
                medals.where((m) => earnedIds.contains(m.id)).length;
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: Theme(
                data: Theme.of(context)
                    .copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                collapsedShape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                childrenPadding: const EdgeInsets.only(bottom: 8),
                title: Text(tr(groupKeys[g]!) + tr('medal_group_count_prefix') + '$got/${medals.length}' + tr('medal_group_count_suffix'),
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                children: medals.map((m) {
                  final has = earnedIds.contains(m.id);
                  return ListTile(
                    leading: MedalRingBadge(
                        medal: m, earned: has, size: 40),
                    title: Text(m.category == null ? tr(m.nameKey) : trCategory(m.category!) + tr('medal_cat_name_suffix'),
                        style: TextStyle(
                            color: has ? null : Colors.grey)),
                    subtitle: Text(m.category == null ? tr(m.descKey) : tr('medal_cat_desc_prefix') + trCategory(m.category!),
                        style: TextStyle(
                            color: has ? grey : Colors.grey,
                            fontSize: 12)),
                    trailing: Text(m.rarity,
                        style: TextStyle(
                            color: rarityColor(m.rarity),
                            fontWeight: FontWeight.bold,
                            fontSize: 12)),
                  );
                }).toList(),
              ),
              ),
            );
          }),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final grey = communitySecondary(dark);
    return AnimatedBuilder(
      animation: communityStore,
      builder: (_, __) {
        final account = widget.account;
        final me = communityStore.current;
        final isMine = me != null && me.id == account.id;
        final myPosts = communityStore.posts
            .where((p) => p.authorId == account.id)
            .toList();
        final myFavorites = communityStore.posts
            .where((p) => p.favoritedBy.contains(account.id))
            .toList();
        final followers = communityStore.accounts
            .where((a) => a.followingIds.contains(account.id))
            .toList();
        final following = communityStore.accounts
            .where((a) => account.followingIds.contains(a.id))
            .toList();
        final myComments = <({CommunityPost post, CommunityComment comment})>[];
        for (final p in communityStore.posts) {
          for (final c in p.comments) {
            if (c.authorId == account.id) {
              myComments.add((post: p, comment: c));
            }
          }
        }
        myComments.sort((a, b) => b.comment.time.compareTo(a.comment.time));
        final canSeeFavorites = isMine || account.favoritesPublic;
        // 经验名次：本机账号按 totalXp 排序的位置（排行榜已并入动态流横条，
        // 主页只留这一行名次 + XP，不再单独做等级页）。
        final rankedAccounts = communityStore.accounts.toList();
        rankedAccounts.sort((a, b) => b.totalXp.compareTo(a.totalXp));
        final rankIndex =
            rankedAccounts.indexWhere((a) => a.id == account.id);
        final rank = rankIndex >= 0 ? rankIndex + 1 : 0;
        // 个人资料页不显示应用栏（应用名）和返回箭头：返回走系统返回，
        // 标题只留“我的主页 / 昵称”，不再跟主页面重复。
        return Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(isMine ? tr('my_home') : account.nickname,
                            style: const TextStyle(
                                fontSize: 20, fontWeight: FontWeight.bold)),
                      ),
                      if (isMine)
                        TextButton(
                          onPressed: () => showEditProfileDialog(context),
                          child: Text(tr('edit_profile')),
                        ),
                    ],
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      children: [
                        communityAvatar(
                          bytes: account.avatarBytes,
                          color: account.avatarColor,
                          nickname: account.nickname,
                          radius: 32,
                          frame: account.avatarFrame,
                          verified: isSpecialAccount(account),
                        ),
                        const SizedBox(height: 8),
                        LevelBadge(account: account, nicknameFontSize: 14),
                        if (account.isFounder ||
                            account.role == 'admin' ||
                            account.role == 'moderator') ...[
                          const SizedBox(height: 4),
                          IdentityBadge(
                              account: account, nicknameFontSize: 14),
                        ],
                      ],
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(account.nickname,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold)),
                          Text('${tr('id_field')}：${account.id}',
                              style:
                                  TextStyle(color: grey, fontSize: 12)),
                          InkWell(
                            onTap: () => showRoleSystemDialog(context),
                            borderRadius: BorderRadius.circular(4),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(tr('profile_role_prefix') + account.displayRole,
                                    style: TextStyle(
                                        color: account.isFounder
                                            ? const Color(0xFFD4A017)
                                            : grey,
                                        fontSize: 12,
                                        fontWeight: account.isFounder
                                            ? FontWeight.bold
                                            : FontWeight.normal)),
                                const SizedBox(width: 4),
                                Icon(Icons.info_outline,
                                    size: 13, color: grey),
                              ],
                            ),
                          ),
                          if (account.bio.isNotEmpty || isMine) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    account.bio.isNotEmpty
                                        ? account.bio
                                        : tr('profile_no_bio'),
                                    style: TextStyle(
                                        color: account.bio.isNotEmpty
                                            ? null
                                            : grey,
                                        fontSize: 13),
                                  ),
                                ),
                                if (isMine)
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined,
                                        size: 18),
                                    tooltip: tr('profile_edit_bio_tooltip'),
                                    onPressed: () =>
                                        showEditProfileDialog(context),
                                  ),
                              ],
                            ),
                          ],
                          XpProgressRow(account: account),
                          if (rank > 0) ...[
                            const SizedBox(height: 4),
                            Text(
                                tr('rank_my_prefix') +
                                    '$rank' +
                                    tr('rank_my_suffix') +
                                    tr('profile_rank_xp_mid') +
                                    '${account.totalXp}' +
                                    tr('profile_rank_xp_suffix'),
                                style: TextStyle(
                                    color: communityAccent,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold)),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _Stat(tr('profile_stat_posts'), '${myPosts.length}', null),
                  _Stat(tr('profile_stat_following'), '${following.length}',
                      () => _showAccountList(tr('profile_stat_following'), following)),
                  _Stat(tr('profile_stat_followers'), '${followers.length}',
                      () => _showAccountList(tr('profile_stat_followers'), followers)),
                  _Stat(tr('profile_stat_favorites'),
                      canSeeFavorites ? '${myFavorites.length}' : '—', null),
                ],
              ),
              if (!isMine && me != null) ...[
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () =>
                              communityStore.toggleFollow(account.id),
                          child: Text(me.followingIds.contains(account.id)
                              ? tr('profile_followed')
                              : tr('profile_follow')),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => CommunityDmScreen(
                                    peerId: account.id)),
                          ),
                          child: Text(tr('author_dm')),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),
              // 资料页四栏改成文字 Tab：大字 + 选中下划线，贴近截图样式；
              // 下划线用 App 主色铜橙，不用截图的红，保持品牌一致；
              // 不加锁图标：各栏可见规则没变（收藏按对方开关），不凭空暗示私密。
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: AnimatedBuilder(
                  animation: _tabs,
                  builder: (_, __) {
                    final labels = [tr('profile_posts_tab'), tr('profile_tab_favorites'), tr('profile_tab_medals'), tr('profile_tab_history')];
                    return Column(
                      children: [
                        Row(
                          children: [
                            for (var i = 0; i < labels.length; i++)
                              Expanded(
                                child: InkWell(
                                  onTap: () => _tabs.animateTo(i),
                                  child: Column(
                                    children: [
                                      Text(labels[i],
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                              fontSize: 17,
                                              fontWeight:
                                                  _tabs.index == i
                                                      ? FontWeight.bold
                                                      : FontWeight.normal,
                                              color: _tabs.index == i
                                                  ? null
                                                  : grey)),
                                      const SizedBox(height: 6),
                                      Container(
                                        width: 26,
                                        height: 3,
                                        decoration: BoxDecoration(
                                          color: _tabs.index == i
                                              ? communityAccent
                                              : Colors.transparent,
                                          borderRadius:
                                              BorderRadius.circular(2),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Container(
                          height: 0.5,
                          color: grey.withValues(alpha: 0.25),
                        ),
                      ],
                    );
                  },
                ),
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabs,
                  children: [
                    // 帖子
                    RepaintBoundary(
                      child: myPosts.isEmpty
                        ? Center(
                            child: Text(tr('profile_no_posts'),
                                style: TextStyle(color: grey)))
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                            itemCount: myPosts.length,
                            itemBuilder: (_, i) {
                              final p = myPosts[i];
                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: grey.withValues(alpha: 0.25)),
                                ),
                                child: ListTile(
                                leading: p.images.isEmpty
                                    ? null
                                    : ClipRRect(
                                        borderRadius:
                                            BorderRadius.circular(8),
                                        child: Image.memory(
                                          p.images.first,
                                          width: 56,
                                          height: 56,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                title: Text(p.title),
                                subtitle: Text(
                                    '${CommunityStore.formatTime(p.time)} · ${trBoard(p.board)} · ${p.likedBy.length}' + tr('profile_like_unit') + ' ${p.comments.length}' + tr('profile_comment_unit')),
                                onTap: () => _openPost(p),
                              ),
                              );
                            },
                          )),
                    // 收藏的动态（不是收藏柜枪支登记）
                    RepaintBoundary(
                      child: !canSeeFavorites
                        ? Center(
                            child: Text(tr('profile_favorites_hidden'),
                                style: TextStyle(color: grey)))
                        : myFavorites.isEmpty
                            ? Center(
                                child: Text(tr('profile_no_favorites'),
                                    style: TextStyle(color: grey)))
                            : ListView.builder(
                                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                                itemCount: myFavorites.length,
                                itemBuilder: (_, i) {
                                  final p = myFavorites[i];
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    decoration: BoxDecoration(
                                      borderRadius:
                                          BorderRadius.circular(12),
                                      border: Border.all(
                                          color:
                                              grey.withValues(alpha: 0.25)),
                                    ),
                                    child: ListTile(
                                    leading: p.images.isEmpty
                                        ? null
                                        : ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            child: Image.memory(
                                              p.images.first,
                                              width: 56,
                                              height: 56,
                                              fit: BoxFit.cover,
                                            ),
                                          ),
                                    title: Text(p.title),
                                    subtitle: Text(
                                        '${CommunityStore.formatTime(p.time)} · ${p.authorNickname} · ${trBoard(p.board)}'),
                                    onTap: () => _openPost(p),
                                  ),
                                  );
                                },
                              )),
                    // 勋章墙
                    RepaintBoundary(child: _medalWall(account, grey)),
                    // 历史：我的评论记录
                    RepaintBoundary(
                      child: myComments.isEmpty
                        ? Center(
                            child: Text(tr('profile_no_comments'),
                                style: TextStyle(color: grey)))
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                            itemCount: myComments.length,
                            itemBuilder: (_, i) {
                              final entry = myComments[i];
                              return ListTile(
                                title: Text(entry.comment.content),
                                subtitle: Text(
                                    tr('profile_reply_prefix') + entry.post.title + tr('profile_reply_mid') + CommunityStore.formatTime(entry.comment.time)),
                                onTap: () => _openPost(entry.post),
                              );
                            },
                          )),
                  ],
                ),
              ),
            ],
          ),
          ),
        );
      },
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback? onTap;
  const _Stat(this.label, this.value, this.onTap);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Column(
          children: [
            Text(value,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 16)),
            Text(label,
                style: const TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
