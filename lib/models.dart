/// 可换枪管口径的一项：caliber 为官方适配口径，barrel 为该口径的
/// 官方枪管长度（如 '660mm（26″）'）；barrel 为空表示该口径的官方
/// 枪管长度未确认，详情页标注“未确认”，绝不现编。
class CaliberOption {
  final String caliber;
  final String barrel;
  const CaliberOption(this.caliber, this.barrel);
}

/// 弹道档案（2.2.5）：只存数据、不做任何弹道计算。
/// 数值字段一律存字符串（保留用户原文），空串 = 未填；
/// Sg 只存导入或用户填写的值，App 绝不计算 Sg。
class BallisticProfile {
  String id;
  String gunName; // '' = 未绑定
  String dragModel; // 'G1' / 'G7' / ''
  String diameterIn;
  String bulletWeightGr;
  String bc;
  String customDrag;
  String bulletLengthIn;
  String muzzleVelocityFps;
  String zeroDistanceY;
  String sightHeightIn;
  String twistIn;
  String twistDirection; // 'L' / 'R' / ''
  String sg; // '' = 未填；只显示，不计算

  BallisticProfile({
    required this.id,
    this.gunName = '',
    this.dragModel = '',
    this.diameterIn = '',
    this.bulletWeightGr = '',
    this.bc = '',
    this.customDrag = '',
    this.bulletLengthIn = '',
    this.muzzleVelocityFps = '',
    this.zeroDistanceY = '',
    this.sightHeightIn = '',
    this.twistIn = '',
    this.twistDirection = '',
    this.sg = '',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'gunName': gunName,
        'dragModel': dragModel,
        'diameterIn': diameterIn,
        'bulletWeightGr': bulletWeightGr,
        'bc': bc,
        'customDrag': customDrag,
        'bulletLengthIn': bulletLengthIn,
        'muzzleVelocityFps': muzzleVelocityFps,
        'zeroDistanceY': zeroDistanceY,
        'sightHeightIn': sightHeightIn,
        'twistIn': twistIn,
        'twistDirection': twistDirection,
        'sg': sg,
      };

  factory BallisticProfile.fromJson(Map<String, dynamic> j) =>
      BallisticProfile(
        id: j['id'] as String? ?? '',
        gunName: j['gunName'] as String? ?? '',
        dragModel: j['dragModel'] as String? ?? '',
        diameterIn: j['diameterIn'] as String? ?? '',
        bulletWeightGr: j['bulletWeightGr'] as String? ?? '',
        bc: j['bc'] as String? ?? '',
        customDrag: j['customDrag'] as String? ?? '',
        bulletLengthIn: j['bulletLengthIn'] as String? ?? '',
        muzzleVelocityFps: j['muzzleVelocityFps'] as String? ?? '',
        zeroDistanceY: j['zeroDistanceY'] as String? ?? '',
        sightHeightIn: j['sightHeightIn'] as String? ?? '',
        twistIn: j['twistIn'] as String? ?? '',
        twistDirection: j['twistDirection'] as String? ?? '',
        sg: j['sg'] as String? ?? '',
      );
}

class Gun {
  final String name;
  final String vendor;
  final String category;
  final String caliber;
  final String action;
  final String barrel;
  final String length;
  final String weight;
  final String capacity;
  final String origin;
  final String year;
  final String description;
  /// 英文简介（2.2.5 全量英文）：英文界面显示它，空时回落中文简介。
  final String descriptionEn;
  final String? image;
  final List<String> ammo;
  final List<String> accessories;
  /// 英文型号名（如 Glock 19），价格调研完成后填入。
  final String? nameEn;
  /// 大约价格（美元参考价字符串），未确认或无民用市价时为相应文字。
  final String? price;
  /// 可换枪管口径（2.2.5）：仅厂商官方宣称的用户级快换枪管多口径
  /// 系统才填；空列表表示单口径枪，详情页不显示该栏。
  final List<CaliberOption> caliberOptions;

  const Gun({
    required this.name,
    required this.vendor,
    required this.category,
    required this.caliber,
    required this.action,
    required this.barrel,
    required this.length,
    required this.weight,
    required this.capacity,
    required this.origin,
    required this.year,
    required this.description,
    this.descriptionEn = '',
    this.image,
    required this.ammo,
    required this.accessories,
    this.nameEn,
    this.price,
    this.caliberOptions = const [],
  });
}

/// 一把刀具：独立于 Gun 模型，枪械的口径/枪机等字段不适用于刀具。
/// 刃长、钢材、年代查不到可靠来源时一律写“未确认”，绝不现编。
class Knife {
  final String name;
  final String nameEn;
  final String country;
  final String type;
  final String bladeLength;
  final String steel;
  final String year;
  final String description;
  /// 英文简介（2.2.5 全量英文）：英文界面显示它，空时回落中文简介。
  final String descriptionEn;

  const Knife({
    required this.name,
    required this.nameEn,
    required this.country,
    required this.type,
    required this.bladeLength,
    required this.steel,
    required this.year,
    required this.description,
    this.descriptionEn = '',
  });
}

/// 一支已停售名枪：用于“停售名枪鉴赏”栏目，讲历史与关联事件。
class DiscontinuedLegend {
  final String name;
  final String nameEn;
  final String vendor;
  final String caliber;
  final String years;
  final String story;
  /// 静态图片（网上找的真实照片，存 assets/images/），无图时为 null。
  final String? image;

  const DiscontinuedLegend({
    required this.name,
    required this.nameEn,
    required this.vendor,
    required this.caliber,
    required this.years,
    required this.story,
    this.image,
  });
}

class AccessoryItem {
  final String name;
  final String vendor;
  final String type;
  final String description;
  final List<String> fitGuns;
  /// 零售参考价：目前均未核实到可靠零售价，留空；
  /// 详情页显示“暂未收录”，有可靠报价时再补，绝不现编。
  final String? price;

  const AccessoryItem({
    required this.name,
    required this.vendor,
    required this.type,
    required this.description,
    required this.fitGuns,
    this.price,
  });
}

class CaliberInfo {
  final String caliber;
  final String bulletDiameter;
  final String bulletWeightRange;
  /// 弹壳长度（SAAMI/CIP 标准值）。
  final String caseLength;
  /// 最大全弹长 OAL（SAAMI/CIP 标准值）。
  final String maxOal;
  final String use;
  final List<String> fitGuns;
  /// 常见弹头：重量 + 类型/型号/军用代号，如穿甲、曳光、燃烧等功能弹。
  final List<String> bullets;
  /// 工厂弹售价参考（如“约 $18–30 / 20发”），未核实则为空。
  final String? factoryPrice;

  const CaliberInfo({
    required this.caliber,
    required this.bulletDiameter,
    required this.bulletWeightRange,
    required this.caseLength,
    required this.maxOal,
    required this.use,
    required this.fitGuns,
    required this.bullets,
    this.factoryPrice,
  });
}

class ReloadCaliber {
  final String caliber;
  final List<String> bullets;
  final List<String> cases;
  final List<String> powders;
  final List<String> primers;

  const ReloadCaliber({
    required this.caliber,
    required this.bullets,
    required this.cases,
    required this.powders,
    required this.primers,
  });
}

/// 一条复装组件商品：弹头 / 弹壳 / 火药 / 底火。
/// price 为 2026 年 10 月查到的美国零售参考价字符串，未查到的写“未确认”，
/// 绝非固定售价；feature 为特性一句话；spec 为口径/重量/类型等规格。
class ReloadComponent {
  final String kind;
  final String vendor;
  final String name;
  final String spec;
  final String feature;
  final String price;

  const ReloadComponent({
    required this.kind,
    required this.vendor,
    required this.name,
    required this.spec,
    required this.feature,
    required this.price,
  });
}

/// 一条复装工具：压机 / 模具 / 量粉 / 量具 / 修整 / 底火 / 清洁等。
/// price 为 2026 年 10 月查到的美国零售参考价字符串，未查到的写“未确认”，
/// 绝非固定售价；function 为具体功能一句话；essential 为新手必备。
class ReloadTool {
  final String category;
  final String vendor;
  final String name;
  final String function;
  final String price;
  final bool essential;

  const ReloadTool({
    required this.category,
    required this.vendor,
    required this.name,
    required this.function,
    required this.price,
    required this.essential,
  });
}

/// 一条装药数据。所有数值字段均须有 Hornady 手册原文出处；
/// 未经核实的字段以“详见手册原文”标示，初速/膛压未引述时为空。
class ReloadLoad {
  final String caliber;
  final String bullet;
  final String powder;
  final String startCharge;
  final String maxCharge;
  final String col;
  final String primer;
  final String brass;
  final String? velocity;
  final String? pressure;
  final String source;
  // 手册名与版本：单独字段，复装页直接显示；
  // 查不到版本的不现编，写“版本未确认”或“在线数据”。
  final String manual;

  const ReloadLoad({
    required this.caliber,
    required this.bullet,
    required this.powder,
    required this.startCharge,
    required this.maxCharge,
    required this.col,
    required this.primer,
    required this.brass,
    this.velocity,
    this.pressure,
    required this.source,
    this.manual = '',
  });
}
