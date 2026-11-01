import 'package:flutter/material.dart';
import '../community_store.dart';
import '../i18n.dart';
import '../widgets/app_top_bar.dart';
import '../widgets/community_theme.dart';
import 'community_post_detail_screen.dart';

/// 收藏与点赞合一页（第 12 项）：两档切换（我的收藏 / 我的点赞），
/// 各列本人历史记录（收藏过 / 点过赞的帖子），点进详情。
class CommunitySavedScreen extends StatefulWidget {
  const CommunitySavedScreen({super.key});

  @override
  State<CommunitySavedScreen> createState() => _CommunitySavedScreenState();
}

class _CommunitySavedScreenState extends State<CommunitySavedScreen> {
  // 0 = 我的收藏，1 = 我的点赞。
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final grey = communitySecondary(dark);
    return AnimatedBuilder(
      animation: communityStore,
      builder: (_, __) {
        final me = communityStore.current;
        final favorites = me == null
            ? <CommunityPost>[]
            : communityStore.posts
                .where((p) => p.favoritedBy.contains(me.id))
                .toList();
        final likes = me == null
            ? <CommunityPost>[]
            : communityStore.posts
                .where((p) => p.likedBy.contains(me.id))
                .toList();
        final list = _tab == 0 ? favorites : likes;
        return Scaffold(
          appBar: SubPageAppBar(title: tr('saved_title')),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Row(
                  children: [
                    ChoiceChip(
                      label: Text(
                          '${tr('saved_favorites')} ${favorites.length}'),
                      selected: _tab == 0,
                      onSelected: (_) => setState(() => _tab = 0),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label:
                          Text('${tr('saved_likes')} ${likes.length}'),
                      selected: _tab == 1,
                      onSelected: (_) => setState(() => _tab = 1),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: list.isEmpty
                    ? Center(
                        child: Text(
                            _tab == 0
                                ? tr('saved_empty_favorites')
                                : tr('saved_empty_likes'),
                            style: TextStyle(color: grey)),
                      )
                    : ListView.builder(
                        padding:
                            const EdgeInsets.fromLTRB(16, 8, 16, 32),
                        itemCount: list.length,
                        itemBuilder: (_, i) {
                          final p = list[i];
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
                                  '${CommunityStore.formatTime(p.time)} · ${trBoard(p.board)} · ${p.likedBy.length}' +
                                      tr('profile_like_unit') +
                                      ' ${p.comments.length}' +
                                      tr('profile_comment_unit')),
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        CommunityPostDetailScreen(
                                            post: p)),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
