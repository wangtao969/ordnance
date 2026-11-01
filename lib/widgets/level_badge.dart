import 'dart:math' as math;
import '../i18n.dart';

import 'package:flutter/material.dart';
import '../community_store.dart';
import 'community_theme.dart';
import 'glass_dialog.dart';

/// 等级铭牌：金属质感实心底 + 居中等级字 + 段位名，挂在每条帖子作者名旁。
/// 外框高度严格等于昵称字号（nicknameFontSize），不比昵称字大，
/// 保证各页视觉协调；铭牌内文字按比例缩小。
/// 实心做法：段位色做纵向金属渐变（上亮、下暗），文字按段位色亮度
/// 选深色或白色，始终居中显示，不再是空心描边。
/// 特效已简化：没有环绕旋转的光弧，只有铭牌外圈向外散发的、对应段位颜色的
/// 光晕（1.8 秒一呼一吸的呼吸动效）。光晕是半透明层、画在铭牌后面，
/// 铭牌本身用不透明底盖在最上层，且光晕只比铭牌大一小圈、不用实色扩散，
/// 不会盖住铭牌文字，也不会以实色压住周围内容。
class LevelBadge extends StatefulWidget {
  final CommunityAccount account;
  final double nicknameFontSize;
  const LevelBadge(
      {super.key, required this.account, this.nicknameFontSize = 14});

  @override
  State<LevelBadge> createState() => _LevelBadgeState();
}

class _LevelBadgeState extends State<LevelBadge>
    with SingleTickerProviderStateMixin {
  late final _ctrl = AnimationController(
      duration: const Duration(milliseconds: 1800), vsync: this)
    ..repeat();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  int get _tier {
    final lv = widget.account.level;
    if (lv <= 10) return 0;
    if (lv <= 20) return 1;
    if (lv <= 35) return 2;
    if (lv <= 48) return 3;
    if (lv <= 55) return 4;
    return 5;
  }

  /// 呼吸灯：t 在 0–1 之间正弦起伏，只驱动外层光晕的透明度与模糊半径。
  /// 光晕画在铭牌后面的独立层上，铭牌本身用不透明底，绝不被光盖住。
  /// 光色取段位色；曜石段位色本身是深 slate，沿用 v2.0.4 定下的暗紫色
  /// 当它的光色，否则深 slate 光晕在深色底上几乎看不见。
  Color get _glowColor {
    if (_tier == 5) return const Color(0xFF7B1FA2);
    return widget.account.tierColor;
  }

  double _glowAlpha(double t) {
    switch (_tier) {
      case 0:
        return 0.15 + 0.10 * t;
      case 1:
        return 0.30 + 0.25 * t;
      case 2:
        return 0.35 + 0.30 * t;
      case 3:
        return 0.45 + 0.30 * t;
      case 4:
        return 0.55 + 0.30 * t;
      default:
        return 0.60 + 0.30 * t;
    }
  }

  double _glowBlur(double t) {
    switch (_tier) {
      case 0:
        return 6 + 4 * t;
      case 1:
        return 8 + 6 * t;
      case 2:
        return 10 + 8 * t;
      case 3:
        return 12 + 8 * t;
      case 4:
        return 14 + 8 * t;
      default:
        return 16 + 8 * t;
    }
  }

  /// 金属渐变：上亮 45% 白、下暗 35% 黑，中间为段位色本体。
  Color _metalTop(Color c) => Color.lerp(c, Colors.white, 0.45)!;
  Color _metalBottom(Color c) => Color.lerp(c, Colors.black, 0.35)!;

  @override
  Widget build(BuildContext context) {
    final c = widget.account.tierColor;
    final h = widget.nicknameFontSize;
    // 铭牌本体：金属质感实心渐变底，等级字居中；亮段位（银、金、钛）
    // 用深色字，暗段位（铁灰、铜、曜石）用白色字，保证对比。
    final textColor = c.computeLuminance() > 0.3
        ? const Color(0xFF1A1A1A)
        : Colors.white;
    final badge = Container(
      height: h,
      padding: EdgeInsets.symmetric(horizontal: h * 0.32),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_metalTop(c), c, _metalBottom(c)],
          stops: const [0.0, 0.5, 1.0],
        ),
        borderRadius: BorderRadius.circular(h / 2),
        border: Border.all(color: _metalBottom(c)),
      ),
      child: Text(
        'LV${widget.account.level} · ${widget.account.tierName}',
        textAlign: TextAlign.center,
        style: TextStyle(
            color: textColor,
            fontSize: h * 0.68,
            fontWeight: FontWeight.bold,
            height: 1),
      ),
    );
    return GestureDetector(
      onTap: () => showLevelSystemDialog(context, widget.account),
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) {
          final t = (math.sin(_ctrl.value * 2 * math.pi) + 1) / 2;
          // 外散光层：只在铭牌后面、比铭牌大一小圈；spread 为 0，
          // 光只靠模糊向外晕开一小段，且全程半透明，不以实色压住周围。
          final glow = Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(h / 2 + 2),
              boxShadow: [
                BoxShadow(
                    color: _glowColor.withValues(alpha: _glowAlpha(t)),
                    blurRadius: _glowBlur(t),
                    spreadRadius: 0),
              ],
            ),
          );
          return Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                  child: Padding(
                      padding: const EdgeInsets.all(2), child: glow)),
              badge,
            ],
          );
        },
      ),
    );
  }
}

/// 等级制度弹窗：点铭牌弹出，列出六档段位、等级区间与所需累计经验。
void showLevelSystemDialog(BuildContext context, CommunityAccount account) {
  const tiers = [
    ('tier_iron', 'LV 1–10', 1, Color(0xFF8A8D91)),
    ('tier_copper', 'LV 11–20', 11, Color(0xFFB08D57)),
    ('tier_silver', 'LV 21–35', 21, Color(0xFFB9C0C7)),
    ('tier_gold', 'LV 36–48', 36, Color(0xFFD4A017)),
    ('tier_titanium', 'LV 49–55', 49, Color(0xFF7FA8BC)),
    ('tier_obsidian', 'LV 56–60', 56, Color(0xFF4A4A5A)),
  ];
  final lv = account.level;
  final toNext = lv >= 60
      ? tr('badge_max')
      : tr('badge_to_next_a') + 'LV${lv + 1}' + tr('badge_to_next_b') + '${CommunityAccount.xpForLevel(lv + 1) - account.totalXp}' + tr('badge_to_next_c');
  showDialog(
    context: context,
    builder: (ctx) => GlassDialog(
      title: tr('badge_level_title'),
      content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tr('badge_current_prefix') + 'LV$lv · ${account.tierName}' + tr('badge_current_total_prefix') + '${account.totalXp}' + tr('badge_current_total_suffix'),
                style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(toNext, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 12),
            for (final t in tiers)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                          color: t.$4, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 8),
                    Text(tr(t.$1),
                        style: TextStyle(
                            fontWeight: account.tierName == tr(t.$1)
                                ? FontWeight.bold
                                : FontWeight.normal)),
                    const SizedBox(width: 8),
                    Text(t.$2,
                        style: const TextStyle(
                            color: Colors.grey, fontSize: 12)),
                    const Spacer(),
                    Text(
                        t.$3 == 1
                            ? tr('badge_xp_from_zero')
                            : tr('badge_xp_needed_prefix') + '${CommunityAccount.xpForLevel(t.$3)}' + tr('badge_xp_needed_suffix'),
                        style: const TextStyle(fontSize: 12)),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            Text(tr('badge_xp_sources'),
                style: TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
      actions: [glassPrimaryButton(ctx, tr('got_it'))],
    ),
  );
}

/// 身份制度弹窗：点身份弹出，列出软件内设定的全部用户身份与权限。
void showRoleSystemDialog(BuildContext context) {
  const roles = [
    ('community_role_founder', 'role_founder_desc', 'role_founder_perms'),
    ('community_role_admin', 'role_admin_desc', 'role_admin_perms'),
    ('community_role_moderator', 'role_mod_desc', 'role_mod_perms'),
    ('community_role_user', 'role_user_desc', 'role_user_perms'),
  ];
  showDialog(
    context: context,
    builder: (ctx) => GlassDialog(
      title: tr('badge_role_title'),
      content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final r in roles) ...[
              Text(tr(r.$1), style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(tr(r.$2), style: const TextStyle(color: Colors.grey, fontSize: 12)),
              Text(tr(r.$3), style: const TextStyle(fontSize: 13)),
              const SizedBox(height: 10),
            ],
          ],
        ),
      actions: [glassPrimaryButton(ctx, tr('got_it'))],
    ),
  );
}

/// 特殊身份铭牌：与等级铭牌同高（等于昵称字号）。
/// 创始用户金、管理员橙、版主钛蓝；普通用户不挂。
class IdentityBadge extends StatelessWidget {
  final CommunityAccount account;
  final double nicknameFontSize;
  const IdentityBadge(
      {super.key, required this.account, this.nicknameFontSize = 14});

  Color get _color {
    if (account.isFounder) return const Color(0xFFD4A017);
    if (account.role == 'admin') return const Color(0xFFE86A1C);
    return const Color(0xFF7FA8BC);
  }

  String get _label {
    if (account.isFounder) return tr('community_role_founder');
    if (account.role == 'admin') return tr('community_role_admin');
    return tr('community_role_moderator');
  }

  @override
  Widget build(BuildContext context) {
    final c = _color;
    final h = nicknameFontSize;
    return GestureDetector(
      onTap: () => showRoleSystemDialog(context),
      child: Container(
        height: h,
        padding: EdgeInsets.symmetric(horizontal: h * 0.32),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(h / 2),
          border: Border.all(color: c),
        ),
        child: Text(
          _label,
          style: TextStyle(
              color: c,
              fontSize: h * 0.68,
              fontWeight: FontWeight.bold,
              height: 1),
        ),
      ),
    );
  }
}

/// 勋章圆环徽记：圆环边用稀有度色，未获得时灰化 + 锁形。
class MedalRingBadge extends StatelessWidget {
  final MedalDef medal;
  final bool earned;
  final double size;
  const MedalRingBadge(
      {super.key, required this.medal, required this.earned, this.size = 44});

  @override
  Widget build(BuildContext context) {
    final c = earned ? rarityColor(medal.rarity) : Colors.grey;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: c.withValues(alpha: earned ? 0.16 : 0.08),
        border: Border.all(color: c, width: 2),
      ),
      child: Center(
        child: earned
            ? Text(
                (medal.category == null ? tr(medal.nameKey) : trCategory(medal.category!) + tr('medal_cat_name_suffix')).characters.first,
                style: TextStyle(
                    color: c,
                    fontSize: size * 0.36,
                    fontWeight: FontWeight.bold),
              )
            : Icon(Icons.lock_outline, size: size * 0.4, color: c),
      ),
    );
  }
}

/// 今日经验条：今日 X/120 + 进度，点击进任务页。
/// 默认橙色；社区签到区传入暗红。
class XpProgressRow extends StatelessWidget {
  final CommunityAccount account;
  final VoidCallback? onTap;
  final Color accent;
  const XpProgressRow(
      {super.key, required this.account, this.onTap, this.accent = communityAccent});

  @override
  Widget build(BuildContext context) {
    final today = account.todayXp;
    const cap = 120;
    final progress = (today / cap).clamp(0.0, 1.0);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Icon(Icons.bolt, size: 18, color: accent),
            const SizedBox(width: 6),
            Text(tr('badge_today_prefix') + '$today/$cap',
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(width: 10),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  backgroundColor: Colors.grey.withValues(alpha: 0.25),
                  valueColor: AlwaysStoppedAnimation<Color>(accent),
                ),
              ),
            ),
            if (onTap != null) ...[
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right, size: 18),
            ],
          ],
        ),
      ),
    );
  }
}
