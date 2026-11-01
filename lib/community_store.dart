import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 社区数据层：账号、帖子、评论、通知、私信、草稿、等级、勋章、收藏柜、
/// 靶场成绩全部保存在本机（原生 SharedPreferences，见 gunsmap/prefs 通道），
/// 不联网。接后端时把这里的方法换成接口调用，模型字段直接沿用。
/// 注意：验证码注册、密码找回、鉴权 Token、设备管理、APP 推送这些能力
/// 必须有后端和服务商才成立，本机版不做假流程。

/// 板块：帖子分类。现有 5 个打底，再按图鉴/配件/复装/名枪四个模块补 6 个。
const communityBoards = [
  '综合',
  '晒枪',
  '复装心得',
  '求助问答',
  '资讯',
  '枪械评测',
  '新手入门',
  '配件分享',
  '射击技巧',
  '历史名枪',
  '靶场日记',
];

/// 本机敏感词库：命中不拦截，自动替换为等长星号。
/// 覆盖：枪弹非法交易与制造、毒品、赌博、色情、诈骗金融、
/// 假证伪造、暴力极端、走私偷税、违禁政治类。
const sensitiveWords = [
  // 枪弹非法交易与制造（社区红线）
  '卖枪', '买枪', '出枪', '收枪', '枪支买卖', '枪支交易', '枪支走私',
  '出售枪支', '转让枪支', '出售弹药', '转让弹药', '弹药买卖', '弹药交易',
  '弹药走私', '子弹买卖', '买卖子弹', '制枪', '造枪', '自制枪', '改枪',
  '制造枪支', '制造弹药', '枪械改装', '改装枪', '散件交易', '散件买卖',
  '出散件', '收散件', '散件出售', '买卖散件',
  // 毒品
  '毒品', '吸毒', '贩毒', '制毒', '大麻', '冰毒', '海洛因', '可卡因',
  '摇头丸', '吗啡', '鸦片', 'k粉', '麻古', '毒资',
  // 赌博
  '赌博', '博彩', '赌场', '赌球', '赌资', '百家乐', '网络赌博',
  // 色情
  '色情', '卖淫', '嫖娼', '淫秽', '色情片', '援交', '包养', '色情服务',
  // 诈骗金融
  '诈骗', '洗钱', '套现', '贷款', '放贷', '高利贷', '套路贷', '裸贷',
  '信用卡套现', '刷单', '代购', '假币', '伪造货币', '盗刷',
  // 假证伪造
  '办证', '假证', '办假证', '伪造证件', '假身份证', '虚开发票',
  '买卖发票', '假发票',
  // 暴力极端
  '恐怖袭击', '制造炸弹', '炸弹制作', '爆炸物', '恐怖组织', '极端组织',
  '买凶', '雇凶',
  // 走私偷税行贿
  '走私', '偷渡', '偷税漏税', '行贿', '受贿',
  // 违禁政治类
  '台独', '港独', '藏独', '疆独', '邪教', '法轮功',
];

/// 从正文里解析话题标签：#xxx# 形式。
List<String> parseTags(String content) {
  final tags = <String>[];
  for (final m in RegExp(r'#([^#\s]+)#').allMatches(content)) {
    final t = m.group(1)!;
    if (!tags.contains(t)) tags.add(t);
  }
  return tags;
}

/// 从正文里解析 @ID 提及：@xxx（到空白处为止）。
List<String> parseMentions(String content) {
  final ids = <String>[];
  for (final m in RegExp(r'@([^\s@#]+)').allMatches(content)) {
    final id = m.group(1)!;
    if (!ids.contains(id)) ids.add(id);
  }
  return ids;
}

/// 把文本里的敏感词替换为等长星号（长词优先，避免短词先切坏长词）。
String maskSensitiveWords(String text) {
  var out = text;
  final words = communityStore.effectiveSensitiveWords
    ..sort((a, b) => b.length.compareTo(a.length));
  for (final w in words) {
    if (out.contains(w)) {
      out = out.replaceAll(w, '*' * w.length);
    }
  }
  return out;
}

class CommunityAccount {
  String nickname;
  final String id;
  final String password;
  Color avatarColor;
  Uint8List? avatarBytes;
  String bio;
  /// 角色：user 普通用户 / moderator 版主 / admin 管理员。
  /// 本机版只有本机账号，角色字段为后端预留，权限判断先按本地管理走。
  String role;

  /// 是否创始用户：ID 固定为 10000 的账号，开放软件全部权限。
  bool get isFounder => id == CommunityStore.founderId;

  /// 资料页展示的身份：创始用户 / 管理员 / 版主 / 普通用户。
  String get displayRole {
    if (isFounder) return '创始用户';
    if (role == 'admin') return '管理员';
    if (role == 'moderator') return '版主';
    return '普通用户';
  }
  /// 账号状态：active 正常 / muted 禁言（不能发帖评论）/ banned 封禁（不能发帖评论）。
  String status;
  /// 禁言到期时间：null 表示永久禁言；到期后按正常账号处理，无需手动解除。
  DateTime? mutedUntil;
  /// 注册时间：旧账号没有，显示为未记录；新注册账号写入当前时间。
  DateTime? createdAt;
  bool get muteExpired =>
      status == 'muted' &&
      mutedUntil != null &&
      DateTime.now().isAfter(mutedUntil!);
  bool get mutedEffective => status == 'muted' && !muteExpired;
  /// 头像边框：'' 无 / copper 铜圈 / gold 金圈 / rainbow 彩虹圈。
  String avatarFrame;
  /// 隐私开关：帖子旁是否显示 ID、收藏是否对外可见。
  bool showIdPublic;
  bool favoritesPublic;
  final Set<String> followingIds;

  /// 成长体系（本机版，随账号一起落盘）：
  /// 经验、每日经验、签到日期、收藏柜、靶场成绩、关注板块、兴趣品类、引导。
  int totalXp;

  /// 段位测试前备份：-1 表示未在测试态；恢复时把经验写回该值。
  int xpBeforeTest;

  /// 邀请码：注册时填的邀请人 ID；联网版按此字段给邀请人结算 +100 经验/人。
  String invitedBy;
  int dailyXp;
  String dailyXpDate;
  final List<String> checkInDates;
  final List<CollectionItem> collection;
  final List<RangeScore> rangeScores;
  final Set<String> followedBoards;
  final List<String> interests;
  bool onboarded;

  CommunityAccount({
    required this.nickname,
    required this.id,
    required this.password,
    this.avatarColor = const Color(0xFF6B5B3E),
    this.avatarBytes,
    this.bio = '',
    this.role = 'user',
    this.status = 'active',
    this.mutedUntil,
    this.createdAt,
    this.avatarFrame = '',
    this.showIdPublic = true,
    this.favoritesPublic = true,
    Set<String>? followingIds,
    this.totalXp = 0,
    this.xpBeforeTest = -1,
    this.invitedBy = '',
    this.dailyXp = 0,
    this.dailyXpDate = '',
    List<String>? checkInDates,
    List<CollectionItem>? collection,
    List<RangeScore>? rangeScores,
    Set<String>? followedBoards,
    List<String>? interests,
    this.onboarded = false,
  })  : followingIds = followingIds ?? <String>{},
        checkInDates = checkInDates ?? [],
        collection = collection ?? [],
        rangeScores = rangeScores ?? [],
        followedBoards = followedBoards ?? <String>{},
        interests = interests ?? [];

  /// 升到下一级需要的经验：15 + (级数-1)*4，按奖励比例定——
  /// 签到一次 +10 ≈ 大半级（前期），活跃一天 25–40 经验前期可升 1–2 级，
  /// 后期一级要 200+ 经验（约一周），满级累计 7729。
  static int xpForNextLevel(int level) => 15 + (level - 1) * 4;

  /// 升到 level 级所需的累计经验。
  static int xpForLevel(int level) {
    var sum = 0;
    for (var i = 1; i < level; i++) {
      sum += xpForNextLevel(i);
    }
    return sum;
  }

  /// 当前等级（1–60），只升不降。
  int get level {
    var lv = 1;
    while (lv < 60 && totalXp >= xpForLevel(lv + 1)) {
      lv++;
    }
    return lv;
  }

  /// 本级已攒 / 本级共需。
  int get xpIntoLevel => totalXp - xpForLevel(level);
  int get xpNeedLevel => xpForNextLevel(level);

  /// 段位名与配色：铁灰 1–10 / 铜 11–20 / 银 21–35 / 金 36–48 / 钛 49–55 / 曜石 56–60。
  String get tierName {
    final lv = level;
    if (lv <= 10) return '铁灰';
    if (lv <= 20) return '铜';
    if (lv <= 35) return '银';
    if (lv <= 48) return '金';
    if (lv <= 55) return '钛';
    return '曜石';
  }

  Color get tierColor {
    final lv = level;
    if (lv <= 10) return const Color(0xFF8A8D91);
    if (lv <= 20) return const Color(0xFFB08D57);
    if (lv <= 35) return const Color(0xFFB9C0C7);
    if (lv <= 48) return const Color(0xFFD4A017);
    if (lv <= 55) return const Color(0xFF7FA8BC);
    return const Color(0xFF4A4A5A);
  }

  static String dateKey(DateTime t) =>
      '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';

  /// 今日已得经验（跨天自动归零）。
  int get todayXp {
    if (dailyXpDate != dateKey(DateTime.now())) return 0;
    return dailyXp;
  }

  /// 加经验：受每日 120 封顶约束，返回实际到账数。
  int addXp(int amount) {
    final today = dateKey(DateTime.now());
    if (dailyXpDate != today) {
      dailyXpDate = today;
      dailyXp = 0;
    }
    final granted = (amount < 120 - dailyXp) ? amount : (120 - dailyXp);
    if (granted <= 0) return 0;
    dailyXp += granted;
    totalXp += granted;
    return granted;
  }

  bool get checkedInToday => checkInDates.contains(dateKey(DateTime.now()));

  /// 连续签到天数：今天已签从今天往回数，今天没签且昨天签了则从昨天往回数，否则为 0。
  int get checkInStreak {
    final dates = checkInDates.toSet();
    var cursor = DateTime.now();
    if (!dates.contains(dateKey(cursor))) {
      cursor = cursor.subtract(const Duration(days: 1));
      if (!dates.contains(dateKey(cursor))) return 0;
    }
    var streak = 0;
    while (dates.contains(dateKey(cursor))) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  Map<String, dynamic> toJson() => {
        'nickname': nickname,
        'id': id,
        'password': password,
        'avatarColor': avatarColor.toARGB32(),
        'avatarBytes':
            avatarBytes == null ? null : base64Encode(avatarBytes!),
        'bio': bio,
        'role': role,
        'status': status,
        'mutedUntil': mutedUntil?.toIso8601String(),
        'createdAt': createdAt?.toIso8601String(),
        'avatarFrame': avatarFrame,
        'showIdPublic': showIdPublic,
        'favoritesPublic': favoritesPublic,
        'followingIds': followingIds.toList(),
        'totalXp': totalXp,
        'xpBeforeTest': xpBeforeTest,
        'invitedBy': invitedBy,
        'dailyXp': dailyXp,
        'dailyXpDate': dailyXpDate,
        'checkInDates': checkInDates,
        'collection': collection.map((c) => c.toJson()).toList(),
        'rangeScores': rangeScores.map((r) => r.toJson()).toList(),
        'followedBoards': followedBoards.toList(),
        'interests': interests,
        'onboarded': onboarded,
      };

  static CommunityAccount fromJson(Map<String, dynamic> j) {
    return CommunityAccount(
      nickname: j['nickname'] as String? ?? '',
      id: j['id'] as String? ?? '',
      password: j['password'] as String? ?? '',
      avatarColor: Color(j['avatarColor'] as int? ?? 0xFF6B5B3E),
      avatarBytes: j['avatarBytes'] == null
          ? null
          : base64Decode(j['avatarBytes'] as String),
      bio: j['bio'] as String? ?? '',
      role: j['role'] as String? ?? 'user',
      status: j['status'] as String? ?? 'active',
      mutedUntil: j['mutedUntil'] == null
          ? null
          : DateTime.tryParse(j['mutedUntil'] as String),
      createdAt: j['createdAt'] == null
          ? null
          : DateTime.tryParse(j['createdAt'] as String),
      avatarFrame: j['avatarFrame'] as String? ?? '',
      showIdPublic: j['showIdPublic'] as bool? ?? true,
      favoritesPublic: j['favoritesPublic'] as bool? ?? true,
      followingIds: (j['followingIds'] as List? ?? []).cast<String>().toSet(),
      totalXp: j['totalXp'] as int? ?? 0,
      xpBeforeTest: j['xpBeforeTest'] as int? ?? -1,
      invitedBy: j['invitedBy'] as String? ?? '',
      dailyXp: j['dailyXp'] as int? ?? 0,
      dailyXpDate: j['dailyXpDate'] as String? ?? '',
      checkInDates: (j['checkInDates'] as List? ?? []).cast<String>(),
      collection: (j['collection'] as List? ?? [])
          .map((e) => CollectionItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      rangeScores: (j['rangeScores'] as List? ?? [])
          .map((e) => RangeScore.fromJson(e as Map<String, dynamic>))
          .toList(),
      followedBoards: (j['followedBoards'] as List? ?? []).cast<String>().toSet(),
      interests: (j['interests'] as List? ?? []).cast<String>(),
      onboarded: j['onboarded'] as bool? ?? false,
    );
  }
}

/// 收藏柜条目：登记拥有 / 上手过 / 想收集的枪。
class CollectionItem {
  final String gunName;
  final String vendor;
  final String caliber;
  final String category;
  /// 收藏种类：gun 枪支（旧数据默认）/ accessory 配件。
  /// 配件复用这四个字段：gunName=配件名、vendor=厂商、category=配件类型、
  /// caliber 留空；配件不记弹数、不算精通。
  final String kind;
  String status; // owned 拥有 / handled 上手过 / wanted 想收集
  int rounds; // 本机弹数记录：该枪累计打过的发数，只增不减（清零除外）
  final DateTime addedTime;

  CollectionItem({
    required this.gunName,
    required this.vendor,
    required this.caliber,
    required this.category,
    required this.status,
    this.kind = 'gun',
    this.rounds = 0,
    DateTime? addedTime,
  }) : addedTime = addedTime ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'gunName': gunName,
        'vendor': vendor,
        'caliber': caliber,
        'category': category,
        'kind': kind,
        'status': status,
        'rounds': rounds,
        'addedTime': addedTime.toIso8601String(),
      };

  static CollectionItem fromJson(Map<String, dynamic> j) => CollectionItem(
        gunName: j['gunName'] as String? ?? '',
        vendor: j['vendor'] as String? ?? '',
        caliber: j['caliber'] as String? ?? '',
        category: j['category'] as String? ?? '',
        kind: j['kind'] as String? ?? 'gun',
        status: j['status'] as String? ?? 'wanted',
        rounds: j['rounds'] as int? ?? 0,
        addedTime: DateTime.tryParse(j['addedTime'] as String? ?? '') ??
            DateTime.now(),
      );
}

/// 靶场成绩：分组（弹着散布）、距离、发数，绑定枪种。
class RangeScore {
  /// 成绩唯一标识：供靶场行程关联用；新记录创建时生成，
  /// 旧记录缺失时按枪名+日期+距离+发数+分组派生，保证重读后不变。
  final String id;
  final String gunName;
  final int distance;
  final int shots;
  final double groupSize;
  final DateTime date;
  final String note;

  /// 现实靶场记录项：口径、弹药、姿势、靶纸、环数、天气、风速风向。
  final String caliber;
  final String ammo;
  final String position;
  final String target;
  final String score;
  final String weather;
  final String wind;

  /// 关联的复装批次号（空=未关联）：配方卡靠它找实测成绩。
  final String batchNo;

  RangeScore({
    String? id,
    required this.gunName,
    required this.distance,
    required this.shots,
    required this.groupSize,
    DateTime? date,
    this.note = '',
    this.caliber = '',
    this.ammo = '',
    this.position = '',
    this.target = '',
    this.score = '',
    this.weather = '',
    this.wind = '',
    this.batchNo = '',
  })  : id = id ?? DateTime.now().microsecondsSinceEpoch.toString(),
        date = date ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'gunName': gunName,
        'distance': distance,
        'shots': shots,
        'groupSize': groupSize,
        'date': date.toIso8601String(),
        'note': note,
        'caliber': caliber,
        'ammo': ammo,
        'position': position,
        'target': target,
        'score': score,
        'weather': weather,
        'wind': wind,
        'batchNo': batchNo,
      };

  /// 旧记录没有 id 时的稳定派生：同一条成绩重读后 id 不变，
  /// 已关联它的行程不会断链；两条完全相同的旧成绩会共用一个 id，
  /// 行程关联时按第一条计，不影响成绩本身的计数与勋章。
  static String _legacyScoreId(Map<String, dynamic> j) {
    final raw =
        '${j['gunName']}|${j['date']}|${j['distance']}|${j['shots']}|${j['groupSize']}';
    var hash = 0;
    for (var i = 0; i < raw.length; i++) {
      hash = (hash * 31 + raw.codeUnitAt(i)) & 0x7fffffff;
    }
    return 'legacy_$hash';
  }

  static RangeScore fromJson(Map<String, dynamic> j) => RangeScore(
        id: j['id'] as String? ?? _legacyScoreId(j),
        gunName: j['gunName'] as String? ?? '',
        distance: j['distance'] as int? ?? 100,
        shots: j['shots'] as int? ?? 5,
        groupSize: (j['groupSize'] as num? ?? 0).toDouble(),
        date:
            DateTime.tryParse(j['date'] as String? ?? '') ?? DateTime.now(),
        note: j['note'] as String? ?? '',
        caliber: j['caliber'] as String? ?? '',
        ammo: j['ammo'] as String? ?? '',
        position: j['position'] as String? ?? '',
        target: j['target'] as String? ?? '',
        score: j['score'] as String? ?? '',
        weather: j['weather'] as String? ?? '',
        wind: j['wind'] as String? ?? '',
        batchNo: j['batchNo'] as String? ?? '',
      );
}

class CommunityComment {
  final String id;
  final String authorId;
  final String authorNickname;
  final Color authorColor;
  final Uint8List? authorAvatar;
  final String authorFrame;
  final String content;
  final DateTime time;
  final Set<String> likedBy;

  CommunityComment({
    required this.id,
    required this.authorId,
    required this.authorNickname,
    required this.authorColor,
    this.authorAvatar,
    this.authorFrame = '',
    required this.content,
    required this.time,
    Set<String>? likedBy,
  }) : likedBy = likedBy ?? <String>{};

  Map<String, dynamic> toJson() => {
        'id': id,
        'authorId': authorId,
        'authorNickname': authorNickname,
        'authorColor': authorColor.toARGB32(),
        'authorAvatar':
            authorAvatar == null ? null : base64Encode(authorAvatar!),
        'authorFrame': authorFrame,
        'content': content,
        'time': time.toIso8601String(),
        'likedBy': likedBy.toList(),
      };

  static CommunityComment fromJson(Map<String, dynamic> j) =>
      CommunityComment(
        id: j['id'] as String? ?? '',
        authorId: j['authorId'] as String? ?? '',
        authorNickname: j['authorNickname'] as String? ?? '',
        authorColor: Color(j['authorColor'] as int? ?? 0xFF6B5B3E),
        authorAvatar: j['authorAvatar'] == null
            ? null
            : base64Decode(j['authorAvatar'] as String),
        authorFrame: j['authorFrame'] as String? ?? '',
        content: j['content'] as String? ?? '',
        time: DateTime.tryParse(j['time'] as String? ?? '') ?? DateTime.now(),
        likedBy: (j['likedBy'] as List? ?? []).cast<String>().toSet(),
      );
}

class CommunityPost {
  final String id;
  String title;
  String content;
  String board;
  final String authorId;
  final String authorNickname;
  final Color authorColor;
  final Uint8List? authorAvatar;
  final String authorFrame;
  final DateTime time;
  final List<Uint8List> images;
  final Set<String> likedBy;
  final Set<String> favoritedBy;
  final List<CommunityComment> comments;
  bool pinned;
  bool essence;
  bool reported;
  int reportCount;
  final List<String> reportReasons;

  CommunityPost({
    required this.id,
    required this.title,
    required this.content,
    required this.board,
    required this.authorId,
    required this.authorNickname,
    required this.authorColor,
    this.authorAvatar,
    this.authorFrame = '',
    required this.time,
    List<Uint8List>? images,
    Set<String>? likedBy,
    Set<String>? favoritedBy,
    List<CommunityComment>? comments,
    this.pinned = false,
    this.essence = false,
    this.reported = false,
    this.reportCount = 0,
    List<String>? reportReasons,
  })  : images = images ?? [],
        likedBy = likedBy ?? <String>{},
        favoritedBy = favoritedBy ?? <String>{},
        comments = comments ?? [],
        reportReasons = reportReasons ?? [];

  List<String> get tags => parseTags(content);

  /// 热度：点赞 1 分，评论 2 分，收藏 1 分。
  int get hotScore => likedBy.length + comments.length * 2 + favoritedBy.length;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'content': content,
        'board': board,
        'authorId': authorId,
        'authorNickname': authorNickname,
        'authorColor': authorColor.toARGB32(),
        'authorAvatar':
            authorAvatar == null ? null : base64Encode(authorAvatar!),
        'authorFrame': authorFrame,
        'time': time.toIso8601String(),
        'images': images.map((b) => base64Encode(b)).toList(),
        'likedBy': likedBy.toList(),
        'favoritedBy': favoritedBy.toList(),
        'comments': comments.map((c) => c.toJson()).toList(),
        'pinned': pinned,
        'essence': essence,
        'reported': reported,
        'reportCount': reportCount,
        'reportReasons': reportReasons,
      };

  static CommunityPost fromJson(Map<String, dynamic> j) => CommunityPost(
        id: j['id'] as String? ?? '',
        title: j['title'] as String? ?? '',
        content: j['content'] as String? ?? '',
        board: j['board'] as String? ?? '综合',
        authorId: j['authorId'] as String? ?? '',
        authorNickname: j['authorNickname'] as String? ?? '',
        authorColor: Color(j['authorColor'] as int? ?? 0xFF6B5B3E),
        authorAvatar: j['authorAvatar'] == null
            ? null
            : base64Decode(j['authorAvatar'] as String),
        authorFrame: j['authorFrame'] as String? ?? '',
        time: DateTime.tryParse(j['time'] as String? ?? '') ?? DateTime.now(),
        images: (j['images'] as List? ?? [])
            .map((e) => base64Decode(e as String))
            .toList(),
        likedBy: (j['likedBy'] as List? ?? []).cast<String>().toSet(),
        favoritedBy: (j['favoritedBy'] as List? ?? []).cast<String>().toSet(),
        comments: (j['comments'] as List? ?? [])
            .map((e) => CommunityComment.fromJson(e as Map<String, dynamic>))
            .toList(),
        pinned: j['pinned'] as bool? ?? false,
        essence: j['essence'] as bool? ?? false,
        reported: j['reported'] as bool? ?? false,
        reportCount: (j['reportCount'] as num?)?.toInt() ??
            (j['reported'] == true ? 1 : 0),
        reportReasons: (j['reportReasons'] as List? ?? []).cast<String>(),
      );
}

class CommunityNotification {
  final String id;
  final String targetAccountId;
  final String kind; // system / interaction / dm
  final String title;
  final String body;
  final DateTime time;
  final String? postId;
  bool read;

  CommunityNotification({
    required this.id,
    required this.targetAccountId,
    required this.kind,
    required this.title,
    required this.body,
    required this.time,
    this.postId,
    this.read = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'targetAccountId': targetAccountId,
        'kind': kind,
        'title': title,
        'body': body,
        'time': time.toIso8601String(),
        'postId': postId,
        'read': read,
      };

  static CommunityNotification fromJson(Map<String, dynamic> j) =>
      CommunityNotification(
        id: j['id'] as String? ?? '',
        targetAccountId: j['targetAccountId'] as String? ?? '',
        kind: j['kind'] as String? ?? 'system',
        title: j['title'] as String? ?? '',
        body: j['body'] as String? ?? '',
        time: DateTime.tryParse(j['time'] as String? ?? '') ?? DateTime.now(),
        postId: j['postId'] as String?,
        read: j['read'] as bool? ?? false,
      );
}

class DirectMessage {
  final String id;
  final String fromId;
  final String toId;
  final String content;
  final DateTime time;

  DirectMessage({
    required this.id,
    required this.fromId,
    required this.toId,
    required this.content,
    required this.time,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'fromId': fromId,
        'toId': toId,
        'content': content,
        'time': time.toIso8601String(),
      };

  static DirectMessage fromJson(Map<String, dynamic> j) => DirectMessage(
        id: j['id'] as String? ?? '',
        fromId: j['fromId'] as String? ?? '',
        toId: j['toId'] as String? ?? '',
        content: j['content'] as String? ?? '',
        time: DateTime.tryParse(j['time'] as String? ?? '') ?? DateTime.now(),
      );
}

class PostDraft {
  String title;
  String content;
  String board;
  PostDraft({this.title = '', this.content = '', this.board = '综合'});

  Map<String, dynamic> toJson() =>
      {'title': title, 'content': content, 'board': board};

  static PostDraft fromJson(Map<String, dynamic> j) => PostDraft(
        title: j['title'] as String? ?? '',
        content: j['content'] as String? ?? '',
        board: j['board'] as String? ?? '综合',
      );
}

/// 单枪精通等级：0 未登记 / 1 了解 / 2 熟悉 / 3 上手 / 4 精通 / 5 权威（本机版不开放）。
const masteryNames = ['', '了解', '熟悉', '上手', '精通', '权威'];

/// 勋章定义：条件用函数算，界面直接拿已获得集合渲染勋章墙。
class MedalDef {
  final String id;
  final String name;
  final String desc;
  final String group;
  final String rarity; // N / R / SR / SSR
  final bool Function(CommunityStore store, CommunityAccount account) test;
  const MedalDef({
    required this.id,
    required this.name,
    required this.desc,
    required this.group,
    required this.rarity,
    required this.test,
  });
}

int _likesReceived(CommunityStore s, CommunityAccount a) {
  var n = 0;
  for (final p in s.posts.where((p) => p.authorId == a.id)) {
    n += p.likedBy.where((id) => id != a.id).length;
  }
  return n;
}

int _postsToday(CommunityStore s, CommunityAccount a) {
  final today = CommunityAccount.dateKey(DateTime.now());
  return s.posts
      .where((p) =>
          p.authorId == a.id &&
          CommunityAccount.dateKey(p.time) == today)
      .length;
}

int _commentsToday(CommunityStore s, CommunityAccount a) {
  final today = CommunityAccount.dateKey(DateTime.now());
  var n = 0;
  for (final p in s.posts) {
    n += p.comments
        .where((c) =>
            c.authorId == a.id &&
            CommunityAccount.dateKey(c.time) == today)
        .length;
  }
  return n;
}

/// 勋章目录（共 28 枚）：签到 4、收藏 4、发帖 3、获赞 3、靶场 3、品类 8、挑战 1、彩蛋 2。赛季已拿掉，挑战不过期。
final medalCatalog = <MedalDef>[
  MedalDef(
      id: 'checkin_1',
      name: '初来乍到',
      desc: '完成第一次每日签到',
      group: '签到',
      rarity: 'N',
      test: (s, a) => a.checkInDates.isNotEmpty),
  MedalDef(
      id: 'checkin_3',
      name: '持之以恒',
      desc: '连续签到 3 天',
      group: '签到',
      rarity: 'R',
      test: (s, a) => a.checkInStreak >= 3),
  MedalDef(
      id: 'checkin_7',
      name: '一周不辍',
      desc: '连续签到 7 天',
      group: '签到',
      rarity: 'SR',
      test: (s, a) => a.checkInStreak >= 7),
  MedalDef(
      id: 'checkin_30',
      name: '月度全勤',
      desc: '连续签到 30 天',
      group: '签到',
      rarity: 'SSR',
      test: (s, a) => a.checkInStreak >= 30),
  MedalDef(
      id: 'collect_1',
      name: '第一把',
      desc: '收藏柜登记第 1 把枪',
      group: '收藏',
      rarity: 'N',
      test: (s, a) => a.collection.length >= 1),
  MedalDef(
      id: 'collect_5',
      name: '小有规模',
      desc: '收藏柜登记 5 把枪',
      group: '收藏',
      rarity: 'R',
      test: (s, a) => a.collection.length >= 5),
  MedalDef(
      id: 'collect_20',
      name: '初具枪柜',
      desc: '收藏柜登记 20 把枪',
      group: '收藏',
      rarity: 'SR',
      test: (s, a) => a.collection.length >= 20),
  MedalDef(
      id: 'collect_50',
      name: '收藏家',
      desc: '收藏柜登记 50 把枪',
      group: '收藏',
      rarity: 'SSR',
      test: (s, a) => a.collection.length >= 50),
  MedalDef(
      id: 'post_1',
      name: '首帖',
      desc: '发表第 1 条动态',
      group: '发帖',
      rarity: 'N',
      test: (s, a) => s.posts.any((p) => p.authorId == a.id)),
  MedalDef(
      id: 'post_10',
      name: '话痨',
      desc: '发表 10 条动态',
      group: '发帖',
      rarity: 'R',
      test: (s, a) =>
          s.posts.where((p) => p.authorId == a.id).length >= 10),
  MedalDef(
      id: 'post_50',
      name: '笔耕不辍',
      desc: '发表 50 条动态',
      group: '发帖',
      rarity: 'SR',
      test: (s, a) =>
          s.posts.where((p) => p.authorId == a.id).length >= 50),
  MedalDef(
      id: 'like_10',
      name: '初受认可',
      desc: '累计获赞 10 次',
      group: '获赞',
      rarity: 'N',
      test: (s, a) => _likesReceived(s, a) >= 10),
  MedalDef(
      id: 'like_50',
      name: '广受欢迎',
      desc: '累计获赞 50 次',
      group: '获赞',
      rarity: 'R',
      test: (s, a) => _likesReceived(s, a) >= 50),
  MedalDef(
      id: 'like_200',
      name: '社区明星',
      desc: '累计获赞 200 次',
      group: '获赞',
      rarity: 'SR',
      test: (s, a) => _likesReceived(s, a) >= 200),
  MedalDef(
      id: 'range_1',
      name: '首发命中',
      desc: '记录第 1 条靶场成绩',
      group: '靶场',
      rarity: 'N',
      test: (s, a) => a.rangeScores.isNotEmpty),
  MedalDef(
      id: 'range_10',
      name: '靶场常客',
      desc: '记录 10 条靶场成绩',
      group: '靶场',
      rarity: 'R',
      test: (s, a) => a.rangeScores.length >= 10),
  MedalDef(
      id: 'range_50',
      name: '神射手',
      desc: '记录 50 条靶场成绩',
      group: '靶场',
      rarity: 'SR',
      test: (s, a) => a.rangeScores.length >= 50),
  for (final c in [
    '步枪',
    '手枪',
    '狙击步枪',
    '精确射手步枪',
    '反器材步枪',
    '霰弹枪',
    '冲锋枪',
    '机枪'
  ])
    MedalDef(
        id: 'cat_$c',
        name: '$c收藏家',
        desc: '收藏柜登记任意 1 把$c',
        group: '品类',
        rarity: 'R',
        test: (s, a) => a.collection.any((i) => i.category == c)),
  MedalDef(
      id: 'challenge_1',
      name: '挑战新手',
      desc: '完成 1 项本期挑战',
      group: '挑战',
      rarity: 'SR',
      test: (s, a) => s.challengeDone(a) >= 1),
  MedalDef(
      id: 'egg_night',
      name: '夜猫子',
      desc: '在 0 点到 5 点之间发过动态（隐藏勋章）',
      group: '彩蛋',
      rarity: 'SSR',
      test: (s, a) => s.posts
          .any((p) => p.authorId == a.id && p.time.hour < 5)),
  MedalDef(
      id: 'egg_photo',
      name: '有图有真相',
      desc: '发表过带图片的动态（隐藏勋章）',
      group: '彩蛋',
      rarity: 'SSR',
      test: (s, a) => s.posts
          .any((p) => p.authorId == a.id && p.images.isNotEmpty)),
];

/// 本期挑战（不过期、不清零）：全部由已有数据现算，错过也不丢进度。
/// 这是拿掉赛季后的活动线：挑战完成一项算一项，奖励永久保留。
class ChallengeDef {
  final String id;
  final String title;
  final String desc;
  final bool Function(CommunityStore s, CommunityAccount a) test;
  const ChallengeDef(
      {required this.id,
      required this.title,
      required this.desc,
      required this.test});
}

final challengeCatalog = <ChallengeDef>[
  ChallengeDef(
      id: 'challenge_collect_1',
      title: '登记第一把藏枪',
      desc: '在收藏柜登记 1 把枪',
      test: (s, a) => a.collection.isNotEmpty),
  ChallengeDef(
      id: 'challenge_range_1',
      title: '第一次打靶记录',
      desc: '记录 1 条靶场成绩',
      test: (s, a) => a.rangeScores.isNotEmpty),
  ChallengeDef(
      id: 'challenge_post_1',
      title: '发表第一条动态',
      desc: '发表 1 条动态',
      test: (s, a) => s.posts.any((p) => p.authorId == a.id)),
  ChallengeDef(
      id: 'challenge_streak_3',
      title: '连签 3 天',
      desc: '连续签到 3 天',
      test: (s, a) => a.checkInStreak >= 3),
  ChallengeDef(
      id: 'challenge_categories_3',
      title: '横跨 3 个品类',
      desc: '收藏柜覆盖 3 个不同品类',
      test: (s, a) =>
          a.collection.map((c) => c.category).toSet().length >= 3),
  ChallengeDef(
      id: 'challenge_collect_10',
      title: '收藏 10 把',
      desc: '收藏柜登记 10 把枪',
      test: (s, a) => a.collection.length >= 10),
];

/// 操作日志条目：操作人、动作、对象、时间（ISO 字符串）。
class AdminLogEntry {
  final String time;
  final String actor;
  final String action;
  final String target;
  AdminLogEntry(
      {required this.time,
      required this.actor,
      required this.action,
      required this.target});
  Map<String, dynamic> toJson() => {
        'time': time,
        'actor': actor,
        'action': action,
        'target': target,
      };
  factory AdminLogEntry.fromJson(Map<String, dynamic> j) => AdminLogEntry(
        time: j['time'] as String? ?? '',
        actor: j['actor'] as String? ?? '',
        action: j['action'] as String? ?? '',
        target: j['target'] as String? ?? '',
      );
}

/// 社区全局状态（单例）。界面用 AnimatedBuilder 监听它。
class CommunityStore extends ChangeNotifier {
  static const _prefsChannel = MethodChannel('gunsmap/prefs');
  static const _prefsKey = 'community_store_v1';

  final List<CommunityAccount> accounts = [];
  CommunityAccount? current;
  final List<CommunityPost> posts = [];
  final List<CommunityNotification> notifications = [];
  final List<DirectMessage> dms = [];
  PostDraft? draft;

  /// 通知开关：系统 / 互动 / 私信三类可独立开关。
  bool notifySystem = true;
  bool notifyInteraction = true;
  bool notifyDm = true;

  /// 被管理员关闭的板块：关闭后不再出现在板块入口与发帖板块选择里。
  final Set<String> disabledBoards = {};

  /// 管理员追加的敏感词与从内置词库里移除的词（后台敏感词管理页维护）。
  final List<String> addedSensitiveWords = [];
  final List<String> removedSensitiveWords = [];

  /// 操作日志：管理操作留痕（操作人、动作、对象、时间），最新在前，最多 200 条。
  final List<AdminLogEntry> adminLog = [];

  /// 每日经验封顶 120 固定不变。赛季系统已在 v2.1.0 拿掉：
  /// 不再有赛季起点、赛季长度、赛季声望与赛季倒计时。

  bool _loaded = false;
  int _seq = 0;
  String _nextId() => 'c${DateTime.now().millisecondsSinceEpoch}_${_seq++}';

  CommunityStore() {
    notifications.add(CommunityNotification(
      id: _nextId(),
      targetAccountId: '',
      kind: 'system',
      title: '欢迎来到 Gun’s Map 社区',
      body: '在这里晒装备、聊复装、记靶场成绩、攒勋章；账号、帖子、收藏都保存在本机。',
      time: DateTime.now(),
    ));
  }

  /// 启动时从本机读回数据（main 里 await 调用，带超时兜底）。
  Future<void> init() async {
    try {
      final raw = await _prefsChannel
          .invokeMethod<String>('getString', {'key': _prefsKey}).timeout(
              const Duration(seconds: 2),
              onTimeout: () => null);
      if (raw != null && raw.isNotEmpty) {
        final j = jsonDecode(raw) as Map<String, dynamic>;
        accounts.clear();
        accounts.addAll((j['accounts'] as List? ?? []).map(
            (e) => CommunityAccount.fromJson(e as Map<String, dynamic>)));
        posts.clear();
        posts.addAll((j['posts'] as List? ?? []).map(
            (e) => CommunityPost.fromJson(e as Map<String, dynamic>)));
        notifications.clear();
        notifications.addAll((j['notifications'] as List? ?? []).map((e) =>
            CommunityNotification.fromJson(e as Map<String, dynamic>)));
        dms.clear();
        dms.addAll((j['dms'] as List? ?? []).map(
            (e) => DirectMessage.fromJson(e as Map<String, dynamic>)));
        draft = j['draft'] == null
            ? null
            : PostDraft.fromJson(j['draft'] as Map<String, dynamic>);
        notifySystem = j['notifySystem'] as bool? ?? true;
        notifyInteraction = j['notifyInteraction'] as bool? ?? true;
        notifyDm = j['notifyDm'] as bool? ?? true;
        disabledBoards.clear();
        disabledBoards.addAll(
            (j['disabledBoards'] as List? ?? []).map((e) => e.toString()));
        addedSensitiveWords.clear();
        addedSensitiveWords.addAll(
            (j['addedSensitiveWords'] as List? ?? []).cast<String>());
        removedSensitiveWords.clear();
        removedSensitiveWords.addAll(
            (j['removedSensitiveWords'] as List? ?? []).cast<String>());
        adminLog.clear();
        adminLog.addAll((j['adminLog'] as List? ?? []).map(
            (e) => AdminLogEntry.fromJson(e as Map<String, dynamic>)));
        final currentId = j['currentId'] as String?;
        current = currentId == null ? null : findAccount(currentId);
      }
    } catch (_) {
      // 读不到就用默认状态（首条欢迎通知），不阻塞启动。
    }
    _loaded = true;
    notifyListeners();
  }

  Map<String, dynamic> toJson() => {
        'accounts': accounts.map((a) => a.toJson()).toList(),
        'currentId': current?.id,
        'posts': posts.map((p) => p.toJson()).toList(),
        'notifications': notifications.map((n) => n.toJson()).toList(),
        'dms': dms.map((d) => d.toJson()).toList(),
        'draft': draft?.toJson(),
        'notifySystem': notifySystem,
        'notifyInteraction': notifyInteraction,
        'notifyDm': notifyDm,
        'disabledBoards': disabledBoards.toList(),
        'addedSensitiveWords': addedSensitiveWords,
        'removedSensitiveWords': removedSensitiveWords,
        'adminLog': adminLog.map((e) => e.toJson()).toList(),
      };

  void _save() {
    if (!_loaded) return;
    try {
      unawaited(_prefsChannel.invokeMethod(
          'setString', {'key': _prefsKey, 'value': jsonEncode(toJson())}));
    } catch (_) {}
  }

  /// 对外显式落盘（草稿编辑退出等不经过 notify 的路径用）。
  void persist() => _save();

  @override
  void notifyListeners() {
    super.notifyListeners();
    _save();
  }

  /// 本期挑战已完成数（现算，不过期）。
  int challengeDone(CommunityAccount a) =>
      challengeCatalog.where((c) => c.test(this, a)).length;

  /// 某账号已获得的勋章。
  List<MedalDef> earnedMedals(CommunityAccount a) =>
      medalCatalog.where((m) => m.test(this, a)).toList();

  /// 单枪精通等级（0–4，本机版不开放 5 级权威）。
  int masteryForGun(CommunityAccount a, String gunName) {
    CollectionItem? item;
    for (final c in a.collection) {
      if (c.gunName == gunName) item = c;
    }
    if (item == null) return 0;
    var lv = 1;
    if (item.status == 'handled') lv = 2;
    if (item.status == 'owned') lv = 3;
    if (item.status == 'owned' &&
        (a.rangeScores.any((r) => r.gunName == gunName) ||
            posts.any((p) =>
                p.authorId == a.id &&
                (p.title.contains(gunName) ||
                    p.content.contains(gunName))))) {
      lv = 4;
    }
    return lv;
  }

  /// 每日签到：已签返回 -1，否则 +10 经验并返回到账数。
  int checkIn() {
    final me = current;
    if (me == null || me.checkedInToday) return -1;
    me.checkInDates.add(CommunityAccount.dateKey(DateTime.now()));
    final granted = me.addXp(10);
    notifyListeners();
    return granted;
  }

  void addCollectionItem(CollectionItem item) {
    final me = current;
    if (me == null) return;
    // 同名不同种不互顶：枪与配件可以同名并存。
    me.collection
        .removeWhere((c) => c.gunName == item.gunName && c.kind == item.kind);
    me.collection.insert(0, item);
    me.addXp(3);
    notifyListeners();
  }

  void removeCollectionItem(String gunName) {
    final me = current;
    if (me == null) return;
    me.collection.removeWhere((c) => c.gunName == gunName);
    notifyListeners();
  }

  void setCollectionStatus(String gunName, String status) {
    final me = current;
    if (me == null) return;
    for (final c in me.collection) {
      if (c.gunName == gunName) c.status = status;
    }
    notifyListeners();
  }

  void addCollectionRounds(String gunName, int n) {
    final me = current;
    if (me == null) return;
    for (final c in me.collection) {
      if (c.gunName == gunName) c.rounds += n;
    }
    notifyListeners();
  }

  void clearCollectionRounds(String gunName) {
    final me = current;
    if (me == null) return;
    for (final c in me.collection) {
      if (c.gunName == gunName) c.rounds = 0;
    }
    notifyListeners();
  }

  void addRangeScore(RangeScore score) {
    final me = current;
    if (me == null) return;
    me.rangeScores.insert(0, score);
    me.addXp(5);
    notifyListeners();
  }

  void removeRangeScore(RangeScore score) {
    final me = current;
    if (me == null) return;
    me.rangeScores.remove(score);
    notifyListeners();
  }

  void toggleBoardFollow(String board) {
    final me = current;
    if (me == null) return;
    if (me.followedBoards.contains(board)) {
      me.followedBoards.remove(board);
    } else {
      me.followedBoards.add(board);
    }
    notifyListeners();
  }

  void completeOnboarding(List<String> interests, List<String> boards) {
    final me = current;
    if (me == null) return;
    me.interests
      ..clear()
      ..addAll(interests);
    me.followedBoards
      ..clear()
      ..addAll(boards);
    me.onboarded = true;
    notifyListeners();
  }

  void skipOnboarding() {
    final me = current;
    if (me == null) return;
    me.onboarded = true;
    notifyListeners();
  }

  CommunityAccount? findAccount(String id) {
    for (final a in accounts) {
      if (a.id == id) return a;
    }
    return null;
  }

  CommunityPost? findPost(String id) {
    for (final p in posts) {
      if (p.id == id) return p;
    }
    return null;
  }

  /// 初始管理员账号 ID：10000（第一位注册用户即为管理员账号）。
  /// 旧版已注册的 wangtao969 账号仍可进后台，做兼容保留。
  static const adminBootstrapId = '10000';

  /// 创始用户账号 ID：固定为 10000，开放软件全部权限。
  static const founderId = '10000';

  /// 当前登录账号是否为创始用户。
  bool get isFounder => current != null && current!.id == founderId;
  static const legacyAdminId = 'wangtao969';

  /// 是否管理员：初始管理员账号，或 role 为 admin 的账号。
  bool get isAdmin =>
      current != null &&
      (current!.id == adminBootstrapId ||
          current!.id == legacyAdminId ||
          current!.role == 'admin');

  /// 下一个系统分配 ID：从 10000 起，按已有数字 ID 顺序递增。
  /// ID 分配从 10001 开始：10000 只留给创始用户，新设备首个注册不再是创始。
  String get nextUserId {
    var maxId = 10000;
    for (final a in accounts) {
      final n = int.tryParse(a.id);
      if (n != null && n > maxId) maxId = n;
    }
    return '${maxId + 1}';
  }

  /// 是否版主（含管理员）：可审核帖子，不能管人员与配置。
  bool get isModerator =>
      current != null && (current!.role == 'moderator' || isAdmin);

  /// 注册：昵称、密码；ID 由系统从 10000 起顺序分配，不可自选。
  /// 注册成功自动登录。返回 null 表示成功，否则返回错误文案。
  String? register({
    required String nickname,
    required String password,
    Uint8List? avatarBytes,
    String invitedBy = '',
  }) {
    if (nickname.isEmpty || password.isEmpty) {
      return '昵称和密码都不能为空';
    }
    final id = nextUserId;
    final account = CommunityAccount(
      nickname: maskSensitiveWords(nickname),
      id: id,
      createdAt: DateTime.now(),
      password: password,
      avatarBytes: avatarBytes,
      invitedBy: invitedBy,
    );
    accounts.add(account);
    // 本机可核验的邀请奖励：邀请人账号就在本机时，直接 +100 经验（不占每日封顶）。
    if (invitedBy.isNotEmpty) {
      final inviter = findAccount(invitedBy);
      if (inviter != null && inviter.id != id) {
        inviter.totalXp += 100;
      }
    }
    current = account;
    notifyListeners();
    return null;
  }

  /// 登录：ID + 密码对上本机账号才能进。
  String? login({required String id, required String password}) {
    final account = findAccount(id);
    if (account == null || account.password != password) {
      return 'ID 或密码不对';
    }
    current = account;
    notifyListeners();
    return null;
  }

  void logout() {
    current = null;
    notifyListeners();
  }

  /// 发帖：命中敏感词直接返回词本身，调用方弹提示；成功返回 null。
  String? createPost({
    required String title,
    required String content,
    required String board,
    required List<Uint8List> images,
  }) {
    final author = current;
    if (author == null) return '请先登录';
    if (!author.isFounder && author.status == 'banned') {
      return '账号已被封禁';
    }
    if (!author.isFounder && author.mutedEffective) {
      return '账号已被禁言';
    }
    if (disabledBoards.contains(board)) return '该板块已关闭';
    final maskedTitle = maskSensitiveWords(title);
    final maskedContent = maskSensitiveWords(content);
    final post = CommunityPost(
      id: _nextId(),
      title: maskedTitle.trim().isEmpty ? '无标题' : maskedTitle.trim(),
      content: maskedContent.trim(),
      board: board,
      authorId: author.id,
      authorNickname: author.nickname,
      authorColor: author.avatarColor,
      authorAvatar: author.avatarBytes,
      authorFrame: author.avatarFrame,
      time: DateTime.now(),
      images: images,
    );
    posts.insert(0, post);
    draft = null;
    // 经验：内容满 20 字才算（水贴不计）；当日首条 +5，之后 +2。
    if (maskedContent.trim().length >= 20) {
      final firstToday = _postsToday(this, author) <= 1;
      author.addXp(firstToday ? 5 : 2);
    }
    // @ 到的本机账号收到互动通知。
    for (final mentionedId in parseMentions(maskedContent)) {
      if (mentionedId != author.id && findAccount(mentionedId) != null) {
        _notify(
          targetAccountId: mentionedId,
          kind: 'interaction',
          title: '@了你',
          body: '${author.nickname} 在帖子《${post.title}》里 @了你',
          postId: post.id,
        );
      }
    }
    notifyListeners();
    return null;
  }

  void toggleLike(CommunityPost post) {
    final me = current;
    if (me == null) return;
    if (post.likedBy.contains(me.id)) {
      post.likedBy.remove(me.id);
    } else {
      post.likedBy.add(me.id);
      // 获赞给作者 +1（精华不直接给经验，防自授）。
      if (post.authorId != me.id) {
        findAccount(post.authorId)?.addXp(1);
      }
      if (post.authorId != me.id) {
        _notify(
          targetAccountId: post.authorId,
          kind: 'interaction',
          title: '有人点赞了你的帖子',
          body: '${me.nickname} 点赞了《${post.title}》',
          postId: post.id,
        );
      }
    }
    notifyListeners();
  }

  void toggleFavorite(CommunityPost post) {
    final me = current;
    if (me == null) return;
    if (post.favoritedBy.contains(me.id)) {
      post.favoritedBy.remove(me.id);
    } else {
      post.favoritedBy.add(me.id);
    }
    notifyListeners();
  }

  /// 评论：返回敏感词或 null。
  String? addComment(CommunityPost post, String content) {
    final me = current;
    if (me == null) return '请先登录';
    if (!me.isFounder && me.status == 'banned') return '账号已被封禁';
    if (!me.isFounder && me.mutedEffective) return '账号已被禁言';
    final masked = maskSensitiveWords(content);
    post.comments.add(CommunityComment(
      id: _nextId(),
      authorId: me.id,
      authorNickname: me.nickname,
      authorColor: me.avatarColor,
      authorAvatar: me.avatarBytes,
      authorFrame: me.avatarFrame,
      content: masked.trim(),
      time: DateTime.now(),
    ));
    // 经验：当日头 3 条评论 +2，之后 +1。
    me.addXp(_commentsToday(this, me) <= 3 ? 2 : 1);
    if (post.authorId != me.id) {
      _notify(
        targetAccountId: post.authorId,
        kind: 'interaction',
        title: '你的帖子有新回复',
        body: '${me.nickname} 回复了《${post.title}》',
        postId: post.id,
      );
    }
    for (final mentionedId in parseMentions(masked)) {
      if (mentionedId != me.id &&
          mentionedId != post.authorId &&
          findAccount(mentionedId) != null) {
        _notify(
          targetAccountId: mentionedId,
          kind: 'interaction',
          title: '@了你',
          body: '${me.nickname} 在评论里 @了你',
          postId: post.id,
        );
      }
    }
    notifyListeners();
    return null;
  }

  void toggleCommentLike(CommunityPost post, CommunityComment comment) {
    final me = current;
    if (me == null) return;
    if (comment.likedBy.contains(me.id)) {
      comment.likedBy.remove(me.id);
    } else {
      comment.likedBy.add(me.id);
    }
    notifyListeners();
  }

  void reportPost(CommunityPost post, String reason) {
    post.reported = true;
    post.reportCount += 1;
    if (reason.isNotEmpty && !post.reportReasons.contains(reason)) {
      post.reportReasons.add(reason);
    }
    notifyListeners();
  }

  void setPinned(CommunityPost post, bool pinned) {
    post.pinned = pinned;
    _logAdmin(pinned ? '置顶帖子' : '取消置顶', post.title);
    notifyListeners();
  }

  void setEssence(CommunityPost post, bool essence) {
    post.essence = essence;
    _logAdmin(essence ? '加精帖子' : '取消精华', post.title);
    notifyListeners();
  }

  void deletePost(CommunityPost post) {
    posts.remove(post);
    _logAdmin('删除帖子', post.title);
    notifyListeners();
  }

  void _logAdmin(String action, String target) {
    final me = current;
    adminLog.insert(
      0,
      AdminLogEntry(
        time: DateTime.now().toIso8601String(),
        actor: me == null ? '系统' : '${me.nickname}（ID ${me.id}）',
        action: action,
        target: target,
      ),
    );
    if (adminLog.length > 200) {
      adminLog.removeRange(200, adminLog.length);
    }
  }

  /// 敏感词管理（仅管理员）：新增词立即生效；删除内置词后该词不再替换。
  List<String> get effectiveSensitiveWords => [...sensitiveWords, ...addedSensitiveWords]
      .where((w) => !removedSensitiveWords.contains(w))
      .toList();

  String? addSensitiveWord(String word) {
    if (!isAdmin) return '只有管理员可以管理敏感词';
    final w = word.trim();
    if (w.isEmpty) return '词不能为空';
    if (effectiveSensitiveWords.contains(w)) return '该词已在词库里';
    addedSensitiveWords.add(w);
    _logAdmin('新增敏感词', w);
    notifyListeners();
    return null;
  }

  String? removeSensitiveWord(String word) {
    if (!isAdmin) return '只有管理员可以管理敏感词';
    if (addedSensitiveWords.remove(word)) {
      _logAdmin('删除敏感词', word);
    } else if (sensitiveWords.contains(word) &&
        !removedSensitiveWords.contains(word)) {
      removedSensitiveWords.add(word);
      _logAdmin('删除敏感词', word);
    } else {
      return '词库里没有这个词';
    }
    notifyListeners();
    return null;
  }

  /// 人员管理（仅管理员）：改角色 / 改状态；不能改自己，不能改初始管理员。
  /// 返回 null 表示成功，否则返回原因。
  String? setUserRole(CommunityAccount target, String role) {
    if (!isAdmin) return '只有管理员可以管理权限';
    if (target.id == current?.id) return '不能修改自己的权限';
    if (!isFounder &&
        (target.id == adminBootstrapId || target.id == legacyAdminId)) {
      return '不能修改初始管理员';
    }
    target.role = role;
    _logAdmin(
        '设为${role == 'admin' ? '管理员' : role == 'moderator' ? '版主' : '普通用户'}',
        '${target.nickname}（ID ${target.id}）');
    notifyListeners();
    return null;
  }

  String? setUserStatus(CommunityAccount target, String status,
      {DateTime? mutedUntil}) {
    if (!isAdmin) return '只有管理员可以管理权限';
    if (target.id == current?.id) return '不能修改自己的权限';
    if (!isFounder &&
        (target.id == adminBootstrapId || target.id == legacyAdminId)) {
      return '不能修改初始管理员';
    }
    target.status = status;
    target.mutedUntil = status == 'muted' ? mutedUntil : null;
    if (status == 'muted') {
      _logAdmin(
          mutedUntil == null
              ? '禁言（永久）'
              : '禁言至 ${mutedUntil.toString().substring(0, 10)}',
          '${target.nickname}（ID ${target.id}）');
    } else if (status == 'banned') {
      _logAdmin('封禁', '${target.nickname}（ID ${target.id}）');
    } else {
      _logAdmin('恢复正常', '${target.nickname}（ID ${target.id}）');
    }
    notifyListeners();
    return null;
  }

  /// 取消举报（管理员/版主）。
  void clearReport(CommunityPost post) {
    post.reported = false;
    post.reportCount = 0;
    post.reportReasons.clear();
    _logAdmin('取消举报', post.title);
    notifyListeners();
  }

  /// 板块开关（仅管理员）。
  void setBoardDisabled(String board, bool disabled) {
    if (disabled) {
      disabledBoards.add(board);
    } else {
      disabledBoards.remove(board);
    }
    _logAdmin(disabled ? '关闭板块' : '开启板块', board);
    notifyListeners();
  }

  /// 发布公告（仅管理员）：全站系统通知。
  void publishAnnouncement(String title, String body) {
    notifications.insert(
      0,
      CommunityNotification(
        id: _nextId(),
        targetAccountId: '',
        kind: 'system',
        title: title,
        body: body,
        time: DateTime.now(),
      ),
    );
    _logAdmin('发布公告', title);
    notifyListeners();
  }

  /// 删除公告（仅管理员）。
  void deleteAnnouncement(CommunityNotification n) {
    notifications.remove(n);
    _logAdmin('删除公告', n.title);
    notifyListeners();
  }

  void toggleFollow(String targetId) {
    final me = current;
    if (me == null || targetId == me.id) return;
    if (me.followingIds.contains(targetId)) {
      me.followingIds.remove(targetId);
    } else {
      me.followingIds.add(targetId);
      _notify(
        targetAccountId: targetId,
        kind: 'interaction',
        title: '有人关注了你',
        body: '${me.nickname} 关注了你',
      );
    }
    notifyListeners();
  }

  void sendDm(String toId, String content) {
    final me = current;
    if (me == null) return;
    final masked = maskSensitiveWords(content);
    dms.add(DirectMessage(
      id: _nextId(),
      fromId: me.id,
      toId: toId,
      content: masked.trim(),
      time: DateTime.now(),
    ));
    _notify(
      targetAccountId: toId,
      kind: 'dm',
      title: '新私信',
      body: '${me.nickname}：${masked.trim()}',
    );
    notifyListeners();
  }

  void _notify({
    required String targetAccountId,
    required String kind,
    required String title,
    required String body,
    String? postId,
  }) {
    if (kind == 'system' && !notifySystem) return;
    if (kind == 'interaction' && !notifyInteraction) return;
    if (kind == 'dm' && !notifyDm) return;
    notifications.insert(
      0,
      CommunityNotification(
        id: _nextId(),
        targetAccountId: targetAccountId,
        kind: kind,
        title: title,
        body: body,
        time: DateTime.now(),
        postId: postId,
      ),
    );
  }

  void markNotificationRead(CommunityNotification n) {
    n.read = true;
    notifyListeners();
  }

  void markAllNotificationsRead(String accountId) {
    for (final n in notifications) {
      if (n.targetAccountId == accountId || n.targetAccountId.isEmpty) {
        n.read = true;
      }
    }
    notifyListeners();
  }

  List<CommunityNotification> notificationsFor(String accountId) {
    return notifications
        .where((n) => n.targetAccountId.isEmpty || n.targetAccountId == accountId)
        .toList();
  }

  int unreadCount(String accountId) {
    return notificationsFor(accountId).where((n) => !n.read).length;
  }

  /// 板块热度（纯计算，不改状态）：帖数 × 10 + 各帖热度分之和。
  /// 社区页热聊/排行榜与排行榜页共用。
  int boardHeat(String board) {
    var heat = 0;
    for (final p in posts.where((p) => p.board == board)) {
      heat += 10 + p.hotScore;
    }
    return heat;
  }

  void saveDraft({required String title, required String content, required String board}) {
    if (title.trim().isEmpty && content.trim().isEmpty) {
      draft = null;
    } else {
      draft = PostDraft(title: title, content: content, board: board);
    }
  }

  void clearDraft() {
    draft = null;
    notifyListeners();
  }

  /// 供界面在直接改了账号字段后触发刷新（如编辑资料、通知开关）。
  /// 段位测试（仅创始用户入口调用）：先备份当前经验，再把段位拉到曜石 LV56。
  void setTestObsidian() {
    final me = current;
    if (me == null) return;
    if (me.xpBeforeTest < 0) me.xpBeforeTest = me.totalXp;
    me.totalXp = CommunityAccount.xpForLevel(56);
    refresh();
  }

  /// 恢复测试前段位：把经验写回备份值并清除备份。
  void restoreTestTier() {
    final me = current;
    if (me == null || me.xpBeforeTest < 0) return;
    me.totalXp = me.xpBeforeTest;
    me.xpBeforeTest = -1;
    refresh();
  }

  void refresh() {
    notifyListeners();
  }

  static String formatTime(DateTime t) {
    return '${t.month}月${t.day}日 ${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }
}

/// 头像显示：有上传头像用图片，没有则用颜色圆 + 昵称首字。
/// 社区头像：有照片用照片；无照片统一用灰底人形描边默认头像（微信式），
/// 不再用颜色 + 首字头像。frame 为头像边框（'' / copper / gold / rainbow）。
/// 特殊权限用户（创始 / 管理员 / 版主）的头像右下角挂红色 V 标（X 式认证标，改红色）。
bool isSpecialAccount(CommunityAccount a) =>
    a.isFounder || a.role == 'admin' || a.role == 'moderator';

/// 按作者 ID 判断是否为特殊权限用户：查本机账号表，找不到时创始 ID 与旧管理员 ID 仍算特殊。
bool isVerifiedAuthorId(String authorId) {
  if (authorId == CommunityStore.founderId ||
      authorId == CommunityStore.legacyAdminId) return true;
  for (final a in communityStore.accounts) {
    if (a.id == authorId) return isSpecialAccount(a);
  }
  return false;
}

Widget communityAvatar({
  required Uint8List? bytes,
  required Color color,
  required String nickname,
  required double radius,
  String frame = '',
  bool verified = false,
}) {
  final Widget core;
  if (bytes != null) {
    core = CircleAvatar(
      backgroundImage: MemoryImage(bytes),
      radius: radius,
    );
  } else {
    core = CircleAvatar(
      backgroundColor: const Color(0xFFB8B8B8),
      radius: radius,
      child: Icon(Icons.person_outline,
          size: radius * 1.15, color: Colors.white),
    );
  }
  if (frame.isEmpty) return _withVerified(core, radius, verified);
  final colors = switch (frame) {
    'copper' => [const Color(0xFFD9B57A), const Color(0xFF8C6A2F)],
    'gold' => [const Color(0xFFF0C75E), const Color(0xFFB8860B)],
    'rainbow' => [
        Colors.red,
        Colors.orange,
        Colors.yellow,
        Colors.green,
        Colors.blue,
        Colors.purple,
      ],
    _ => null,
  };
  if (colors == null) return _withVerified(core, radius, verified);
  return _withVerified(
    Container(
      padding: const EdgeInsets.all(2.5),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(colors: colors),
      ),
      child: core,
    ),
    radius,
    verified,
  );
}

/// 头像右下角 V 标：橙色实心圆 + 白色 V 字（“已点亮橙 V”样式），
/// 橙色取自用户发的图样（#FD7304），外圈白边与头像分隔；不挂时原样返回。
Widget _withVerified(Widget avatar, double radius, bool verified) {
  if (!verified) return avatar;
  final d = (radius * 0.62).clamp(14.0, 26.0);
  return Stack(
    clipBehavior: Clip.none,
    children: [
      avatar,
      Positioned(
        right: -1,
        bottom: -1,
        child: Container(
          width: d,
          height: d,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFFFD7304),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 1.5),
          ),
          child: Text(
            'V',
            style: TextStyle(
                color: Colors.white,
                fontSize: d * 0.58,
                fontWeight: FontWeight.bold,
                height: 1),
          ),
        ),
      ),
    ],
  );
}

/// 全局单例：本机版状态，App 内各社区页共用。
final communityStore = CommunityStore();
