import 'package:flutter/material.dart';
import '../community_store.dart';
import '../i18n.dart';
import '../widgets/app_top_bar.dart';
import '../widgets/level_badge.dart';
import '../widgets/app_toast.dart';
import 'community_account_dialogs.dart';
import 'community_dm_screen.dart';
import 'community_profile_screen.dart';
import 'community_range_screen.dart';

/// 我的 Tab：个人中心入口。登录后显示头像、等级铭牌与统计，
/// 下分我的主页、私信、靶场成绩、设置；未登录时显示登录/注册。
class MyScreen extends StatelessWidget {
  const MyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: communityStore,
      builder: (_, __) {
        final me = communityStore.current;
        return Scaffold(
          extendBodyBehindAppBar: true,
          appBar: const OrdnanceAppBar(),
          body: ListView(
            padding: EdgeInsets.fromLTRB(
                16,
                MediaQuery.of(context).padding.top + kToolbarHeight + 16,
                16,
                110),
            children: [
              Text(tr('tab_mine'),
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              if (me == null)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        vertical: 28, horizontal: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(tr('not_logged'),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 4),
                        Text(tr('not_logged_sub'),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: Colors.grey, fontSize: 12)),
                        const SizedBox(height: 18),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                shape: const StadiumBorder(),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 30, vertical: 12),
                              ),
                              onPressed: () => showLoginDialog(context),
                              child: Text(tr('login')),
                            ),
                            const SizedBox(width: 12),
                            OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                shape: const StadiumBorder(),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 30, vertical: 12),
                              ),
                              onPressed: () => showRegisterDialog(context),
                              child: Text(tr('register')),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                )
              else ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      children: [
                        communityAvatar(
                          bytes: me.avatarBytes,
                          color: me.avatarColor,
                          nickname: me.nickname,
                          radius: 32,
                          frame: me.avatarFrame,
                          verified: isSpecialAccount(me),
                        ),
                        const SizedBox(height: 8),
                        LevelBadge(account: me, nicknameFontSize: 14),
                        if (me.isFounder ||
                            me.role == 'admin' ||
                            me.role == 'moderator') ...[
                          const SizedBox(height: 4),
                          IdentityBadge(
                              account: me, nicknameFontSize: 14),
                        ],
                      ],
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(me.nickname,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold)),
                          Text('${tr('id_field')}：${me.id}',
                              style: const TextStyle(
                                  color: Colors.grey, fontSize: 12)),
                          if (me.bio.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(me.bio),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Builder(builder: (_) {
                  final myPosts = communityStore.posts
                      .where((p) => p.authorId == me.id)
                      .length;
                  final myFavorites = communityStore.posts
                      .where((p) => p.favoritedBy.contains(me.id))
                      .length;
                  final earned =
                      communityStore.earnedMedals(me).length;
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _Stat(tr('admin_row_posts'), '$myPosts'),
                      _Stat(tr('admin_row_collection'), '$myFavorites'),
                      _Stat(tr('my_medals'), '$earned/${medalCatalog.length}'),
                      _Stat(tr('my_guns'), '${me.collection.length}'),
                    ],
                  );
                }),
                const SizedBox(height: 16),
                _MenuTile(
                  icon: Icons.person_outlined,
                  title: tr('my_home'),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) =>
                            CommunityProfileScreen(account: me)),
                  ),
                ),
                Builder(builder: (_) {
                  final unreadDm = communityStore
                      .notificationsFor(me.id)
                      .where((n) => n.kind == 'dm' && !n.read)
                      .length;
                  return _MenuTile(
                    icon: Icons.mail_outlined,
                    title: tr('my_dms'),
                    badge: unreadDm,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const CommunityDmScreen()),
                    ),
                  );
                }),
                _MenuTile(
                  icon: Icons.gps_fixed,
                  title: tr('admin_row_scores'),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const CommunityRangeScreen()),
                  ),
                ),
                                                  _MenuTile(
                  icon: Icons.logout_outlined,
                  title: tr('my_logout'),
                  titleColor: Colors.red,
                  onTap: () {
                    communityStore.logout();
                    showAppToast(context, tr('my_logged_out'));
                  },
                ),
                              ],
            ],
          ),
        );
      },
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  const _Stat(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
      ],
    );
  }
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final int badge;
  final Color? titleColor;
  const _MenuTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.badge = 0,
    this.titleColor,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: 54,
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF0D0D0D) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: dark
                ? Colors.white.withValues(alpha: 0.10)
                : Colors.black.withValues(alpha: 0.08)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Icon(icon, color: const Color(0xFF8C6A2F)),
              const SizedBox(width: 14),
              Expanded(
                child: Text(title,
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: titleColor)),
              ),
              if (badge > 0) ...[
                Badge(
                  label: Text('$badge'),
                  backgroundColor: const Color(0xFFE86A1C),
                ),
                const SizedBox(width: 8),
              ],
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
