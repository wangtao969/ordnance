import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../community_store.dart';
import '../i18n.dart';
import '../widgets/app_top_bar.dart';
import '../widgets/community_theme.dart';
import 'community_post_detail_screen.dart';

/// 相册（第 12 项）：网格陈列本人历史发布过的所有照片（按帖子倒序），
/// 点照片进原帖详情。
class CommunityAlbumScreen extends StatelessWidget {
  const CommunityAlbumScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final grey = communitySecondary(dark);
    return AnimatedBuilder(
      animation: communityStore,
      builder: (_, __) {
        final me = communityStore.current;
        final photos = <({CommunityPost post, Uint8List image})>[];
        if (me != null) {
          for (final p in communityStore.posts) {
            if (p.authorId != me.id) continue;
            for (final img in p.images) {
              photos.add((post: p, image: img));
            }
          }
        }
        return Scaffold(
          appBar: SubPageAppBar(title: tr('album_title')),
          body: photos.isEmpty
              ? Center(
                  child: Text(tr('album_empty'),
                      style: TextStyle(color: grey)),
                )
              : GridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 6,
                    mainAxisSpacing: 6,
                  ),
                  itemCount: photos.length,
                  itemBuilder: (_, i) {
                    final item = photos[i];
                    return GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => CommunityPostDetailScreen(
                                post: item.post)),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.memory(
                          item.image,
                          fit: BoxFit.cover,
                        ),
                      ),
                    );
                  },
                ),
        );
      },
    );
  }
}
