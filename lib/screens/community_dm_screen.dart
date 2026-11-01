import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import '../community_store.dart';
import '../i18n.dart';
import '../widgets/app_top_bar.dart';
import '../widgets/glass_dialog.dart';
import 'community_profile_screen.dart';

/// 私信：会话列表 + 对话页，只在本机账号之间流转（本机版）。
/// 列表按 X 风格：顶部搜索框、头像 + 名字 + ID + 时间 + 一行摘要，行间细线。
class CommunityDmScreen extends StatefulWidget {
  /// 直接打开和某人的对话时传对方 ID；不传则显示会话列表。
  final String? peerId;
  const CommunityDmScreen({super.key, this.peerId});

  @override
  State<CommunityDmScreen> createState() => _CommunityDmScreenState();
}

class _CommunityDmScreenState extends State<CommunityDmScreen> {
  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();
  String _query = '';

  /// 搜索框展开状态：聚焦后变长，失焦且无内容时缩回小药丸。
  bool _searchExpanded = false;

  @override
  void initState() {
    super.initState();
    // 打开私信列表即清 dm 未读角标（通知中心已删，角标只走这一条路）。
    communityStore.markDmNotificationsRead();
    _searchFocus.addListener(() {
      if (_searchFocus.hasFocus && !_searchExpanded) {
        setState(() => _searchExpanded = true);
      } else if (!_searchFocus.hasFocus &&
          _searchExpanded &&
          _query.isEmpty) {
        setState(() => _searchExpanded = false);
      }
    });
  }

  @override
  void dispose() {
    _searchFocus.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _showNewChatDialog(
      BuildContext context, List<CommunityAccount> others) {
    showDialog(
      context: context,
      builder: (dialogContext) => GlassDialog(
        title: tr('dm_new'),
        content: others.isEmpty
            ? Text(tr('dm_no_accounts'))
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: others
                    .map((a) => InkWell(
                          onTap: () {
                            Navigator.of(dialogContext).pop();
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                      CommunityDmThreadScreen(
                                          peerId: a.id)),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                vertical: 8),
                            child: Row(
                              children: [
                                communityAvatar(
                                  bytes: a.avatarBytes,
                                  color: a.avatarColor,
                                  nickname: a.nickname,
                                  radius: 20,
                                  frame: a.avatarFrame,
                                  verified: isSpecialAccount(a),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(a.nickname,
                                      style: const TextStyle(
                                          fontWeight:
                                              FontWeight.bold)),
                                ),
                                Text('ID：${a.id}',
                                    style: const TextStyle(
                                        color: Colors.grey,
                                        fontSize: 12)),
                              ],
                            ),
                          ),
                        ))
                    .toList(),
              ),
        actions: [glassPrimaryButton(dialogContext, tr('close'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final me = communityStore.current;
    if (widget.peerId != null) {
      return CommunityDmThreadScreen(peerId: widget.peerId!);
    }
    return AnimatedBuilder(
      animation: communityStore,
      builder: (_, __) {
        if (me == null) {
          return Scaffold(
            appBar: SubPageAppBar(title: tr('author_dm')),
            body: Center(child: Text(tr('login_required_body'))),
          );
        }
        final dark = Theme.of(context).brightness == Brightness.dark;
        final grey = dark ? const Color(0xFF8A8578) : const Color(0xFF9A917F);
        final peerIds = <String>{};
        for (final m in communityStore.dms) {
          if (m.fromId == me.id) peerIds.add(m.toId);
          if (m.toId == me.id) peerIds.add(m.fromId);
        }
        final q = _query.trim().toLowerCase();
        bool matches(CommunityAccount a) =>
            q.isEmpty ||
            a.nickname.toLowerCase().contains(q) ||
            a.id.toLowerCase().contains(q);
        final sessions = peerIds
            .map(communityStore.findAccount)
            .whereType<CommunityAccount>()
            .where(matches)
            .toList();
        final others = communityStore.accounts
            .where((a) => a.id != me.id && matches(a))
            .toList();
        return Scaffold(
          appBar: SubPageAppBar(title: tr('author_dm')),
          floatingActionButton: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ClipOval(
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  color: Colors.black.withValues(alpha: 0.55),
                  child: IconButton(
                    icon: const Icon(Icons.add_comment_outlined,
                        color: Colors.white),
                    onPressed: () => _showNewChatDialog(context, others),
                  ),
                ),
              ),
            ),
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                CommunityProfileScreen(account: me)),
                      ),
                      child: communityAvatar(
                        bytes: me.avatarBytes,
                        color: me.avatarColor,
                        nickname: me.nickname,
                        radius: 20,
                        frame: me.avatarFrame,
                        verified: isSpecialAccount(me),
                      ),
                    ),
                    const SizedBox(width: 10),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOutCubic,
                      // 展开后：页面左右各 16 + 头像 40 + 间距 10，剩下全给搜索框；
                      // 收起时只留一个放大镜按钮（48 宽），不带框与底色。
                      width: _searchExpanded
                          ? MediaQuery.sizeOf(context).width - 82
                          : 48,
                      child: _searchExpanded
                          ? TextField(
                              controller: _searchCtrl,
                              focusNode: _searchFocus,
                              autofocus: true,
                              onChanged: (v) => setState(() => _query = v),
                              decoration: InputDecoration(
                                hintText: tr('dm_search_hint'),
                                prefixIcon:
                                    const Icon(Icons.search, size: 20),
                                suffixIcon: _query.isEmpty
                                    ? null
                                    : IconButton(
                                        icon: const Icon(Icons.close,
                                            size: 18),
                                        onPressed: () => setState(() {
                                          _searchCtrl.clear();
                                          _query = '';
                                        }),
                                      ),
                                filled: true,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(24),
                                  borderSide: BorderSide.none,
                                ),
                                // 聚焦前后外观一致：与未聚焦同一支无边药丸，
                                // 不再出现灰边框，也不再走全局橙色聚焦边。
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(24),
                                  borderSide: BorderSide.none,
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(24),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                    vertical: 10),
                              ),
                            )
                          : IconButton(
                              icon: const Icon(Icons.search, size: 20),
                              onPressed: () =>
                                  setState(() => _searchExpanded = true),
                            ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.separated(
                  itemCount: sessions.length +
                      (sessions.isEmpty ? 1 : 0) +
                      1 +
                      others.length,
                  // 行间不再用默认 Divider（深色硬线显黑）：换成与个人主页
                  // 同款的 0.5 细线、灰色 0.25 透明度，并缩进到文字起点。
                  separatorBuilder: (_, __) => Container(
                        height: 0.5,
                        margin: const EdgeInsets.only(left: 76),
                        color: grey.withValues(alpha: 0.25),
                      ),
                  itemBuilder: (_, index) {
                    if (sessions.isEmpty && index == 0) {
                      return Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(tr('dm_empty')),
                      );
                    }
                    final i = sessions.isEmpty ? index - 1 : index;
                    if (i < sessions.length) {
                      final peer = sessions[i];
                      final last = communityStore.dms
                          .where((m) =>
                              (m.fromId == me.id && m.toId == peer.id) ||
                              (m.fromId == peer.id && m.toId == me.id))
                          .last;
                      return InkWell(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  CommunityDmThreadScreen(peerId: peer.id)),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              communityAvatar(
                                bytes: peer.avatarBytes,
                                color: peer.avatarColor,
                                nickname: peer.nickname,
                                radius: 24,
                                verified: isSpecialAccount(peer),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(peer.nickname,
                                              maxLines: 1,
                                              overflow:
                                                  TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                  fontWeight:
                                                      FontWeight.bold)),
                                        ),
                                        const SizedBox(width: 6),
                                        Text('ID：${peer.id}',
                                            style: const TextStyle(
                                                color: Colors.grey,
                                                fontSize: 12)),
                                        const Spacer(),
                                        Text(
                                            CommunityStore.formatTime(
                                                last.time),
                                            style: const TextStyle(
                                                color: Colors.grey,
                                                fontSize: 11)),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(last.content,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            color: Colors.grey,
                                            fontSize: 13)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    if (i == sessions.length) {
                      return Padding(
                        padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Text(tr('dm_start_new'),
                            style: TextStyle(fontWeight: FontWeight.bold)),
                      );
                    }
                    final a = others[i - sessions.length - 1];
                    return ListTile(
                      leading: communityAvatar(
                        bytes: a.avatarBytes,
                        color: a.avatarColor,
                        nickname: a.nickname,
                        radius: 20,
                      ),
                      title: Text(a.nickname),
                      subtitle: Text('${tr('id_field')}：${a.id}'),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                CommunityDmThreadScreen(peerId: a.id)),
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

class CommunityDmThreadScreen extends StatefulWidget {
  final String peerId;
  const CommunityDmThreadScreen({super.key, required this.peerId});

  @override
  State<CommunityDmThreadScreen> createState() => _CommunityDmThreadScreenState();
}

class _CommunityDmThreadScreenState extends State<CommunityDmThreadScreen> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final grey = dark ? const Color(0xFF8A8578) : const Color(0xFF9A917F);
    final me = communityStore.current;
    final peer = communityStore.findAccount(widget.peerId);
    return AnimatedBuilder(
      animation: communityStore,
      builder: (_, __) {
        if (me == null || peer == null) {
          return Scaffold(
            appBar: SubPageAppBar(title: tr('author_dm')),
            body: Center(child: Text(tr('dm_peer_gone'))),
          );
        }
        final thread = communityStore.dms
            .where((m) =>
                (m.fromId == me.id && m.toId == peer.id) ||
                (m.fromId == peer.id && m.toId == me.id))
            .toList();
        return Scaffold(
          appBar: SubPageAppBar(title: tr('author_dm')),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 16, 16, 0),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                CommunityProfileScreen(account: peer)),
                      ),
                      child: communityAvatar(
                        bytes: peer.avatarBytes,
                        color: peer.avatarColor,
                        nickname: peer.nickname,
                        radius: 18,
                        verified: isSpecialAccount(peer),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(peer.nickname,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: thread.isEmpty
                    ? Center(
                        child: Text(tr('dm_no_messages'),
                            style: TextStyle(color: grey)))
                    : ListView(
                        padding: const EdgeInsets.all(16),
                        children: thread.map((m) {
                          final mine = m.fromId == me.id;
                          return Align(
                            alignment: mine
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: mine
                                    ? const Color(0xFFE86A1C)
                                    : grey.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.only(
                                  topLeft: const Radius.circular(18),
                                  topRight: const Radius.circular(18),
                                  bottomLeft: Radius.circular(mine ? 18 : 4),
                                  bottomRight: Radius.circular(mine ? 4 : 18),
                                ),
                              ),
                              child: Text(
                                m.content,
                                style: TextStyle(
                                    color: mine
                                        ? Colors.white
                                        : null),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
              ),
              // 输入区顶部的硬线去掉：输入框本身已是药丸形，不再用一条
              // 横线把消息区和输入区割开。
              SafeArea(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _ctrl,
                          decoration: InputDecoration(
                            hintText: tr('dm_input_hint'),
                            filled: true,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide.none,
                            ),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 10),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        decoration: const BoxDecoration(
                          color: Color(0xFFE86A1C),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          onPressed: () {
                            final text = _ctrl.text.trim();
                            if (text.isEmpty) return;
                            communityStore.sendDm(peer.id, text);
                            _ctrl.clear();
                          },
                          icon: const Icon(Icons.send,
                              size: 20, color: Colors.white),
                        ),
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
