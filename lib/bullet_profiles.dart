/// 弹头档案（本批新增）：只填厂商官方公开数据，查不到留空。
/// 数值字段全部是字符串，空串 = 未收录，界面显示“未收录”，绝不估算。
/// caliber 为弹径族（.224 / 6mm / 6.5mm / 7mm / .308 / .338），
/// 不是具体弹药口径：同弹径弹头可用于多个口径，子弹目录按弹径族陈列。
/// name 为“系列 + 弹重”（如 ELD Match 140gr）；组件库弹头名是
/// 系列 + 弹径（如 ELD Match 6.5），不含弹重，故组件匹配按系列返回
/// 全部已核实变体，不猜弹重。
/// BC 取厂商长期公布值（Hornady 经典公布值；Hornady 后续另有
/// Mach 2.25 基准新值，本表不混用两种基准）。阻力系数无厂商公开
/// 单值，全部留空。
class BulletProfile {
  final String vendor;
  final String name;
  final String caliber;
  final String diameterMm;
  final String weightGr;
  final String bcG1;
  final String bcG7;
  final String dragCoeff;
  final String lengthMm;

  const BulletProfile({
    required this.vendor,
    required this.name,
    required this.caliber,
    this.diameterMm = '',
    this.weightGr = '',
    this.bcG1 = '',
    this.bcG7 = '',
    this.dragCoeff = '',
    this.lengthMm = '',
  });
}

/// 子弹目录口径 → 弹径族。
String? _boreFamily(String caliber) {
  if (caliber.contains('6.5')) return '6.5mm';
  if (caliber.contains('6mm')) return '6mm';
  if (caliber.contains('.223') || caliber.contains('5.56')) return '.224';
  if (caliber.contains('7mm')) return '7mm';
  if (caliber.contains('.308') ||
      caliber.contains('.30-06') ||
      caliber.contains('.30-30') ||
      caliber.contains('.300 ') ||
      caliber.contains('7.62×51')) {
    return '.308';
  }
  if (caliber.contains('.338')) return '.338';
  return null;
}

/// 按口径查档案（子弹目录用）：返回该口径弹径族的全部变体。
List<BulletProfile> bulletProfilesByCaliber(String caliber) {
  final family = _boreFamily(caliber);
  if (family == null) return const [];
  return bulletProfiles.where((p) => p.caliber == family).toList();
}

/// 按自由文本查档案（复装页弹头手填文本用）：从文本中提取系列与
/// 弹径，返回全部厂商的匹配变体；提不到系列或弹径返回空表。
List<BulletProfile> bulletProfilesForText(String text) {
  const families = <String>[
    'ELD Match',
    'ELD-X',
    'Tipped MatchKing',
    'MatchKing',
    'Hybrid Target',
    'VLD Target',
    'Juggernaut Target',
  ];
  String? family;
  for (final f in families) {
    if (text.contains(f)) {
      family = f;
      break;
    }
  }
  if (family == null) return const [];
  String? bore;
  if (text.contains('.308')) {
    bore = '.308';
  } else if (text.contains('6.5')) {
    bore = '6.5mm';
  } else if (text.contains('7mm')) {
    bore = '7mm';
  } else if (text.contains('.224')) {
    bore = '.224';
  } else if (text.contains('6mm')) {
    bore = '6mm';
  } else if (text.contains('.338')) {
    bore = '.338';
  }
  if (bore == null) return const [];
  return bulletProfiles
      .where((p) => p.name.startsWith(family!) && p.caliber == bore)
      .toList();
}

/// 复装页用：弹头文本提不到弹径时，用记录口径推导弹径族。
List<BulletProfile> bulletProfilesForBulletAndCaliber(
  String bulletText,
  String? caliber,
) {
  final fromText = bulletProfilesForText(bulletText);
  if (fromText.isNotEmpty) return fromText;
  // 文本里已明确写了弹径却无匹配变体时不回落（避免把别的弹径档案
  // 误当成该弹头档案）；只有文本完全没提弹径时才用记录口径推导。
  const boreTokens = <String>['.308', '6.5', '7mm', '.224', '6mm', '.338'];
  if (boreTokens.any(bulletText.contains)) return const [];
  if (caliber == null) return const [];
  const families = <String>[
    'ELD Match',
    'ELD-X',
    'Tipped MatchKing',
    'MatchKing',
    'Hybrid Target',
    'VLD Target',
    'Juggernaut Target',
  ];
  String? family;
  for (final f in families) {
    if (bulletText.contains(f)) {
      family = f;
      break;
    }
  }
  if (family == null) return const [];
  final bore = _boreFamily(caliber);
  if (bore == null) return const [];
  return bulletProfiles
      .where((p) => p.name.startsWith(family!) && p.caliber == bore)
      .toList();
}

/// 按组件库弹头名查档案（复装选弹头、供应商详情用）：
/// 组件名形如“ELD Match 6.5”“MatchKing .308”，返回同厂商同系列
/// 同弹径族的全部已核实变体；名不符返回空表。
List<BulletProfile> bulletProfilesForComponent(
  String vendor,
  String componentName,
) {
  const families = <String>[
    'ELD Match',
    'ELD-X',
    'Tipped MatchKing',
    'MatchKing',
    'Hybrid Target',
    'VLD Target',
    'Juggernaut Target',
  ];
  String? family;
  for (final f in families) {
    if (componentName.contains(f)) {
      family = f;
      break;
    }
  }
  if (family == null) return const [];
  String? bore;
  if (componentName.contains('.308')) {
    bore = '.308';
  } else if (componentName.contains('6.5')) {
    bore = '6.5mm';
  } else if (componentName.contains('7mm')) {
    bore = '7mm';
  } else if (componentName.contains('.224')) {
    bore = '.224';
  } else if (componentName.contains('6mm')) {
    bore = '6mm';
  } else if (componentName.contains('.338')) {
    bore = '.338';
  }
  if (bore == null) return const [];
  return bulletProfiles
      .where(
        (p) =>
            p.vendor == vendor &&
            p.name.startsWith(family!) &&
            p.caliber == bore,
      )
      .toList();
}

/// 档案表：厂商官方公开数据（Hornady / Sierra / Berger 官网或官方手册）。
/// 28 条已核实变体；其余组件弹头（Nosler / Barnes / Lapua / Speer 等）
/// 本轮未核实到厂商公开 BC，暂不建档（留空，不凑数）。
const bulletProfiles = <BulletProfile>[
  // Hornady ELD Match（经典公布值）
  BulletProfile(
    vendor: 'Hornady',
    name: 'ELD Match 140gr',
    caliber: '6.5mm',
    diameterMm: '6.71',
    weightGr: '140',
    bcG1: '.646',
    bcG7: '.326',
  ),
  BulletProfile(
    vendor: 'Hornady',
    name: 'ELD Match 120gr',
    caliber: '6.5mm',
    diameterMm: '6.71',
    weightGr: '120',
    bcG1: '.486',
    bcG7: '.245',
  ),
  BulletProfile(
    vendor: 'Hornady',
    name: 'ELD Match 123gr',
    caliber: '6.5mm',
    diameterMm: '6.71',
    weightGr: '123',
    bcG1: '.506',
    bcG7: '.255',
  ),
  BulletProfile(
    vendor: 'Hornady',
    name: 'ELD Match 130gr',
    caliber: '6.5mm',
    diameterMm: '6.71',
    weightGr: '130',
    bcG1: '.554',
    bcG7: '.279',
  ),
  BulletProfile(
    vendor: 'Hornady',
    name: 'ELD Match 100gr',
    caliber: '6.5mm',
    diameterMm: '6.71',
    weightGr: '100',
    bcG1: '.385',
    bcG7: '.194',
  ),
  BulletProfile(
    vendor: 'Hornady',
    name: 'ELD Match 73gr',
    caliber: '.224',
    diameterMm: '5.69',
    weightGr: '73',
    bcG1: '.398',
    bcG7: '.200',
  ),
  BulletProfile(
    vendor: 'Hornady',
    name: 'ELD Match 75gr',
    caliber: '.224',
    diameterMm: '5.69',
    weightGr: '75',
    bcG1: '.467',
    bcG7: '.235',
  ),
  BulletProfile(
    vendor: 'Hornady',
    name: 'ELD Match 80gr',
    caliber: '.224',
    diameterMm: '5.69',
    weightGr: '80',
    bcG1: '.485',
    bcG7: '.244',
  ),
  BulletProfile(
    vendor: 'Hornady',
    name: 'ELD Match 108gr',
    caliber: '6mm',
    diameterMm: '6.17',
    weightGr: '108',
    bcG1: '.536',
    bcG7: '.270',
  ),
  BulletProfile(
    vendor: 'Hornady',
    name: 'ELD Match 178gr',
    caliber: '.308',
    diameterMm: '7.82',
    weightGr: '178',
    bcG1: '.547',
    bcG7: '.275',
  ),
  // Hornady ELD-X
  BulletProfile(
    vendor: 'Hornady',
    name: 'ELD-X 143gr',
    caliber: '6.5mm',
    diameterMm: '6.71',
    weightGr: '143',
    bcG1: '.623',
    bcG7: '.314',
  ),
  BulletProfile(
    vendor: 'Hornady',
    name: 'ELD-X 178gr',
    caliber: '.308',
    diameterMm: '7.82',
    weightGr: '178',
    bcG1: '.552',
    bcG7: '.278',
  ),
  BulletProfile(
    vendor: 'Hornady',
    name: 'ELD-X 200gr',
    caliber: '.308',
    diameterMm: '7.82',
    weightGr: '200',
    bcG1: '.597',
  ),
  BulletProfile(
    vendor: 'Hornady',
    name: 'ELD-X 212gr',
    caliber: '.308',
    diameterMm: '7.82',
    weightGr: '212',
    bcG1: '.663',
  ),
  BulletProfile(
    vendor: 'Hornady',
    name: 'ELD-X 220gr',
    caliber: '.308',
    diameterMm: '7.82',
    weightGr: '220',
    bcG1: '.654',
  ),
  BulletProfile(
    vendor: 'Hornady',
    name: 'ELD-X 230gr',
    caliber: '.338',
    diameterMm: '8.59',
    weightGr: '230',
    bcG1: '.616',
  ),
  BulletProfile(
    vendor: 'Hornady',
    name: 'ELD-X 270gr',
    caliber: '.338',
    diameterMm: '8.59',
    weightGr: '270',
    bcG1: '.757',
  ),
  // Sierra MatchKing / Tipped MatchKing
  BulletProfile(
    vendor: 'Sierra',
    name: 'MatchKing 168gr',
    caliber: '.308',
    diameterMm: '7.82',
    weightGr: '168',
    bcG1: '.462',
  ),
  BulletProfile(
    vendor: 'Sierra',
    name: 'MatchKing 175gr',
    caliber: '.308',
    diameterMm: '7.82',
    weightGr: '175',
    bcG1: '.505',
    bcG7: '.250',
    lengthMm: '34.5',
  ),
  BulletProfile(
    vendor: 'Sierra',
    name: 'MatchKing 77gr',
    caliber: '.224',
    diameterMm: '5.69',
    weightGr: '77',
    bcG1: '.372',
    bcG7: '.188',
    lengthMm: '24.9',
  ),
  BulletProfile(
    vendor: 'Sierra',
    name: 'Tipped MatchKing 168gr',
    caliber: '.308',
    diameterMm: '7.82',
    weightGr: '168',
    bcG1: '.535',
  ),
  // Berger
  BulletProfile(
    vendor: 'Berger',
    name: 'Hybrid Target 105gr',
    caliber: '6mm',
    diameterMm: '6.17',
    weightGr: '105',
    bcG1: '.536',
    bcG7: '.275',
  ),
  BulletProfile(
    vendor: 'Berger',
    name: 'Hybrid Target 155gr',
    caliber: '.308',
    diameterMm: '7.82',
    weightGr: '155',
    bcG1: '.478',
    bcG7: '.245',
  ),
  BulletProfile(
    vendor: 'Berger',
    name: 'Hybrid Target 185gr',
    caliber: '.308',
    diameterMm: '7.82',
    weightGr: '185',
    bcG1: '.576',
    bcG7: '.295',
  ),
  BulletProfile(
    vendor: 'Berger',
    name: 'Hybrid Target 215gr',
    caliber: '.308',
    diameterMm: '7.82',
    weightGr: '215',
    bcG1: '.691',
    bcG7: '.354',
  ),
  BulletProfile(
    vendor: 'Berger',
    name: 'Hybrid Target 180gr',
    caliber: '7mm',
    diameterMm: '7.21',
    weightGr: '180',
    bcG1: '.680',
    bcG7: '.349',
  ),
  BulletProfile(
    vendor: 'Berger',
    name: 'VLD Target 168gr',
    caliber: '.308',
    diameterMm: '7.82',
    weightGr: '168',
    bcG1: '.473',
    bcG7: '.260',
  ),
  BulletProfile(
    vendor: 'Berger',
    name: 'Juggernaut Target 185gr',
    caliber: '.308',
    diameterMm: '7.82',
    weightGr: '185',
    bcG1: '.555',
    bcG7: '.284',
    lengthMm: '34.4',
  ),
];
