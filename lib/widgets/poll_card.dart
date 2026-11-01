import 'package:flutter/material.dart';
import '../community_store.dart';
import '../i18n.dart';
import 'app_toast.dart';

/// 投票卡（第 11 项）：每选项一行：选项文字 + 票数 + 百分比条；
/// 点选项投票（每人一票，改投移票，本地存储）；未登录点选项提示登录。
class PollCard extends StatelessWidget {
  const PollCard({super.key, required this.post});

  final CommunityPost post;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final grey = dark ? const Color(0xFF8A8578) : const Color(0xFF9A917F);
    final me = communityStore.current;
    final total = post.pollVoters.length;
    final myVote = me == null ? null : post.pollVoters[me.id];
    final counts = List<int>.filled(post.pollOptions.length, 0);
    for (final v in post.pollVoters.values) {
      if (v >= 0 && v < counts.length) counts[v]++;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.poll_outlined, size: 16),
            const SizedBox(width: 6),
            Text(tr('poll_title'),
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            const Spacer(),
            Text(
                tr('poll_votes_prefix') +
                    '$total' +
                    tr('poll_votes_suffix'),
                style: TextStyle(color: grey, fontSize: 12)),
          ],
        ),
        const SizedBox(height: 8),
        for (var i = 0; i < post.pollOptions.length; i++) ...[
          GestureDetector(
            onTap: () {
              if (me == null) {
                showAppToast(context, tr('login_required_body'));
                return;
              }
              communityStore.votePoll(post, i);
            },
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: myVote == i
                      ? const Color(0xFFE86A1C)
                      : grey.withValues(alpha: 0.4),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(post.pollOptions[i],
                            style: const TextStyle(fontSize: 14)),
                      ),
                      if (myVote == i)
                        const Icon(Icons.check_circle,
                            size: 16, color: Color(0xFFE86A1C)),
                      const SizedBox(width: 6),
                      Text(
                          total == 0
                              ? '0%'
                              : '${(counts[i] * 100 / total).round()}%',
                          style: TextStyle(color: grey, fontSize: 12)),
                      const SizedBox(width: 4),
                      Text('${counts[i]}',
                          style: TextStyle(color: grey, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: total == 0 ? 0 : counts[i] / total,
                      minHeight: 6,
                      backgroundColor: grey.withValues(alpha: 0.2),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xFFE86A1C)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}
