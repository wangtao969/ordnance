import 'data.dart';
import 'i18n.dart';
import 'models.dart';

/// 品牌与专业术语的英文显示映射（显示层专用，绝不动 data.dart 的值）。
/// 规则：查表不到时原样返回中文，不猜、不硬翻；
/// 搜索仍用原始中文字段匹配，列表与详情主显示用这里的英文。

/// 枪名（中文）→ 英文型号名：直接从 guns 列表建表，不手翻。
final Map<String, String> gunNameEn = {
  for (final g in guns) g.name: g.nameEn ?? g.name,
};

/// 枪名中文 → 英文（适配枪械 fitGuns 显示用，查不到原样返回）。
String gunNameEnOf(String chineseName) => gunNameEn[chineseName] ?? chineseName;

/// 枪主显示名：详情与列表一律用 nameEn（738 支全有）。
String gunDisplayName(Gun g) => g.nameEn ?? g.name;

/// 8 个品类（任务定稿的单数形式）。
const Map<String, String> _categories = {
  '步枪': 'Rifle',
  '手枪': 'Pistol',
  '狙击步枪': 'Sniper Rifle',
  '精确射手步枪': 'Designated Marksman Rifle',
  '机枪': 'Machine Gun',
  '反器材步枪': 'Anti-materiel Rifle',
  '霰弹枪': 'Shotgun',
  '冲锋枪': 'Submachine Gun',
};

/// 品类显示跟随语言（第 10 项修复）：英文模式用本表的英文术语
/// （保持现有英文显示不变，如 Pistol 而非 Handgun）；繁体走
/// trCategory；简体返回中文原名。旧版无条件返回英文，导致
/// 中文模式下品类也显示英文。
String categoryDisplay(String c) {
  if (localeNotifier.value == localeEn) return _categories[c] ?? c;
  return trCategory(c);
}

/// 品类搜索匹配（第 10 项）：中英文品类名都要命中，与显示语言无关。
bool categoryMatches(String category, String query) {
  final q = query.toLowerCase();
  if (category.toLowerCase().contains(q)) return true;
  final en = _categories[category];
  if (en != null && en.toLowerCase().contains(q)) return true;
  return false;
}

/// 枪机原理：按中文全角逗号切段、每段查表、再用英文逗号拼回。
/// 142 个切段全量覆盖（脚本枚举自 738 支的 147 个不同 action 串）。
String actionDisplay(String action) =>
    action.split('，').map((s) => _actionSegments[s] ?? s).join(', ');

const Map<String, String> _actionSegments = {
  'AK 式机匣）': 'AK-style receiver)',
  '与老款活塞式 SIG716 区分）': 'distinguished from the older piston SIG716)',
  '中长度直接导气': 'Mid-length direct impingement',
  '倾斜枪机': 'Tilting bolt',
  '倾斜枪机闭锁': 'Tilting bolt locking',
  '倾斜闭锁': 'Tilting lock',
  '倾斜闭锁）': 'Tilting lock)',
  '偏转闭锁枪机': 'Deflecting locking bolt',
  '全自动': 'Full-automatic',
  '全自动 / 半自动': 'Full-automatic / Semi-automatic',
  '全自动/半自动可选（击针平移式）': 'Selectable full/semi-automatic (linear striker)',
  '全自动（可单发）': 'Full-automatic (single-shot capable)',
  '全自动（导气开锁、后坐驱动）': 'Full-automatic (gas-unlocked, recoil-driven)',
  '全自动（摆动闭锁片）': 'Full-automatic (swinging locking flap)',
  '全自动（旋转枪机）': 'Full-automatic (rotating bolt)',
  '全自动（闭膛待击）': 'Full-automatic (closed-bolt)',
  '前抛壳无托': 'Forward-ejection bullpup',
  '半自动': 'Semi-automatic',
  '半自动 DA/SA': 'Semi-automatic DA/SA',
  '半自动 DA/SA 或 SAO': 'Semi-automatic DA/SA or SAO',
  '半自动 DAO（模块化火控组）': 'Semi-automatic DAO (modular fire control group)',
  '半自动 SAO': 'Semi-automatic SAO',
  '半自动/全自动': 'Semi-automatic/Full-automatic',
  '半自动/全自动导气旋转枪机': 'Semi-automatic/Full-automatic gas-operated rotating bolt',
  '半自动/全自动导气旋转枪机（民用半自动版 PE 90）':
      'Semi-automatic/Full-automatic gas-operated rotating bolt (civilian semi-automatic PE 90 version)',
  '半自动/全自动导气活塞': 'Semi-automatic/Full-automatic gas piston',
  '半自动击针式': 'Semi-automatic striker-fired',
  '半自动导气': 'Semi-automatic gas-operated',
  '半自动导气旋转枪机': 'Semi-automatic gas-operated rotating bolt',
  '半自动导气旋转枪机（SG 550 结构': 'Semi-automatic gas-operated rotating bolt (SG 550 design',
  '半自动直接导气': 'Semi-automatic direct impingement',
  '半自动直接导气式 AR': 'Semi-automatic direct impingement AR',
  '半自动直接导气式（DI': 'Semi-automatic direct impingement (DI',
  '半自动短行程活塞': 'Semi-automatic short-stroke piston',
  '半自动短行程活塞（AR 平台）': 'Semi-automatic short-stroke piston (AR platform)',
  '半自动（A.R.G.O. 活塞导气）': 'Semi-automatic (A.R.G.O. piston gas system)',
  '半自动（AR-10 式）': 'Semi-automatic (AR-10 style)',
  '半自动（反冲式）': 'Semi-automatic (blowback)',
  '半自动（后坐式）': 'Semi-automatic (recoil-operated)',
  '半自动（导气式': 'Semi-automatic (gas-operated',
  '半自动（导气式）': 'Semi-automatic (gas-operated)',
  '半自动（导气活塞）': 'Semi-automatic (gas piston)',
  '半自动（旋转枪管闭锁）': 'Semi-automatic (rotating barrel lock)',
  '半自动（枪口集气）': 'Semi-automatic (muzzle gas trap)',
  '半自动（民用版）': 'Semi-automatic (civilian version)',
  '半自动（直接导气': 'Semi-automatic (direct impingement',
  '半自动（直接导气式 AR 平台）': 'Semi-automatic (direct impingement AR platform)',
  '半自动（直接导气式）': 'Semi-automatic (direct impingement)',
  '半自动（直接导气）': 'Semi-automatic (direct impingement)',
  '半自动（短行程活塞': 'Semi-automatic (short-stroke piston',
  '半自动（短行程活塞、旋转枪机': 'Semi-automatic (short-stroke piston, rotating bolt',
  '半自动（短行程活塞）': 'Semi-automatic (short-stroke piston)',
  '半自动（自由枪机式）': 'Semi-automatic (blowback)',
  '半自动（自由枪机）': 'Semi-automatic (blowback)',
  '单发折开式（Break Open）': 'Single-shot break-open (Break Open)',
  '可调三档导气活塞': 'Three-setting adjustable gas piston',
  '可调导气箍）': 'Adjustable gas block)',
  '可选射击（导气旋转枪机）': 'Select-fire (gas-operated rotating bolt)',
  '后坐式': 'Recoil-operated',
  '后坐式（带气体助推）': 'Recoil-operated (gas-assisted)',
  '后座式（短后座、肘节闭锁）': 'Recoil-operated (short recoil, toggle lock)',
  '四闭锁、50° 开锁）': 'Four lugs, 50° unlocking)',
  '导气': 'Gas-operated',
  '导气与枪管短后坐混合式': 'Gas and short barrel recoil hybrid',
  '导气倾斜闭锁枪机': 'Gas-operated tilting locking bolt',
  '导气式': 'Gas-operated',
  '导气式、开膛待击、恒定后坐': 'Gas-operated, open-bolt, constant recoil',
  '导气式、旋转枪机': 'Gas-operated, rotating bolt',
  '导气式、旋转枪机（恒定后坐）': 'Gas-operated, rotating bolt (constant recoil)',
  '导气式、短行程活塞、旋转枪机': 'Gas-operated, short-stroke piston, rotating bolt',
  '导气式、长行程活塞、旋转闭锁': 'Gas-operated, long-stroke piston, rotating lock',
  '导气式多管': 'Gas-operated multi-barrel',
  '导气式多管（燃气+电动混合驱动）': 'Gas-operated multi-barrel (gas + electric hybrid drive)',
  '导气式直接导气': 'Gas-operated direct impingement',
  '导气式短行程活塞': 'Gas-operated short-stroke piston',
  '导气式短行程活塞、旋转枪机': 'Gas-operated short-stroke piston, rotating bolt',
  '导气式短行程活塞、旋转枪机（同 G36）':
      'Gas-operated short-stroke piston, rotating bolt (same as G36)',
  '导气式长行程活塞': 'Gas-operated long-stroke piston',
  '导气式（中长导气': 'Gas-operated (mid-length gas',
  '导气式（中长导气）': 'Gas-operated (mid-length gas)',
  '导气式（卡宾导气）': 'Gas-operated (carbine gas)',
  '导气式（手枪长导气）': 'Gas-operated (pistol-length gas)',
  '导气式（步枪长导气）': 'Gas-operated (rifle-length gas)',
  '导气旋转枪机': 'Gas-operated rotating bolt',
  '导气活塞': 'Gas piston',
  '平衡式自动机（平衡后坐）': 'Balanced action (balanced recoil)',
  '开膛待击': 'Open-bolt',
  '开膛待击（自动原理未确认）': 'Open-bolt (action unconfirmed)',
  '手摇多管': 'Hand-cranked multi-barrel',
  '折开': 'Break-open',
  '摆动闭锁片': 'Swinging locking flap',
  '旋转枪机': 'Rotating bolt',
  '无托': 'Bullpup',
  '无托结构）': 'Bullpup design)',
  '杠杆': 'Lever-action',
  '杠杆延迟闭锁': 'Lever-delayed locking',
  '杠杆式': 'Lever-action',
  '杠杆式（1860 年式）': 'Lever-action (1860 pattern)',
  '杠杆式（齿轮传动、旋转闭锁枪机、可拆弹匣）':
      'Lever-action (gear-driven, rotating locking bolt, detachable magazine)',
  '杠杆（转拴式枪机+可拆弹仓）': 'Lever-action (turn-bolt action + detachable magazine)',
  '栓动': 'Bolt-action',
  '栓动（GAP Gladius 机匣）': 'Bolt-action (GAP Gladius receiver)',
  '栓动（R7 机匣': 'Bolt-action (R7 receiver',
  '栓动（Templar 短枪机）': 'Bolt-action (Templar short action)',
  '栓动（三闭锁、60° 开锁）': 'Bolt-action (three lugs, 60° unlocking)',
  '栓动（三闭锁突笋）': 'Bolt-action (three locking lugs)',
  '栓动（前控供弹）': 'Bolt-action (controlled round feed)',
  '栓动（单发装填）': 'Bolt-action (single-shot loading)',
  '栓动（单发）': 'Bolt-action (single-shot)',
  '栓动（弹仓供弹）': 'Bolt-action (magazine feed)',
  '栓动（微型毛瑟式）': 'Bolt-action (mini Mauser style)',
  '栓动（控制供弹）': 'Bolt-action (controlled feed)',
  '栓动（旋转后拉枪机）': 'Bolt-action (turn-bolt)',
  '栓动（无托）': 'Bolt-action (bullpup)',
  '栓动（毛瑟 98 式控制供弹）': 'Bolt-action (Mauser 98 controlled feed)',
  '栓动（长枪机）': 'Bolt-action (long action)',
  '气动式': 'Gas-operated',
  '泵动': 'Pump-action',
  '滚柱延迟半自由枪机': 'Roller-delayed semi-free bolt',
  '滚柱延迟后坐': 'Roller-delayed blowback',
  '滚柱延迟闭锁': 'Roller-delayed locking',
  '滚柱闭锁': 'Roller locking',
  '电动多管': 'Electrically-driven rotary',
  '直拉式枪机': 'Straight-pull bolt',
  '直拉栓动': 'Straight-pull bolt-action',
  '直接导气': 'Direct impingement',
  '直接导气（.22 LR 专用）': 'Direct impingement (.22 LR only)',
  '直接导气（步枪长度导气）': 'Direct impingement (rifle-length gas)',
  '直接导气）': 'Direct impingement)',
  '短后坐式': 'Short recoil',
  '短行程活塞': 'Short-stroke piston',
  '短行程活塞（HK433/437 平台）': 'Short-stroke piston (HK433/437 platform)',
  '短行程活塞（推杆式）': 'Short-stroke piston (push-rod)',
  '美式伸缩托 + STANAG 弹匣座）': 'US-style telescoping stock + STANAG magazine well)',
  '跌落式单发（杠杆操作）': 'Falling-block single-shot (lever-operated)',
  '转拴枪机': 'Turn-bolt',
  '转轮': 'Revolver',
  '选择射击': 'Select-fire',
  '铰接片闭锁': 'Hinged flap locking',
  '长行程活塞': 'Long-stroke piston',
  '长行程活塞（SG 550 系）': 'Long-stroke piston (SG 550 family)',
  '闭膛待击': 'Closed-bolt',
};

/// 产地 / 国家：全量字符串映射（738 支的全部 63 个 origin 值 + 刀具 10 国均在内）。
const Map<String, String> _origins = {
  '中国': 'China',
  '中国台湾': 'Taiwan',
  '以色列': 'Israel',
  '以色列 / 美国 IWI US': 'Israel / USA IWI US',
  '以色列 / 美国组装': 'Israel / Assembled in USA',
  '伊朗': 'Iran',
  '俄罗斯': 'Russia',
  '俄罗斯帝国': 'Russian Empire',
  '克罗地亚': 'Croatia',
  '加拿大': 'Canada',
  '南斯拉夫': 'Yugoslavia',
  '南斯拉夫/塞尔维亚': 'Yugoslavia/Serbia',
  '印尼': 'Indonesia',
  '印度': 'India',
  '土耳其': 'Turkey',
  '土耳其（Istanbul Silah 制造）': 'Turkey (Made by Istanbul Silah)',
  '埃及': 'Egypt',
  '塞尔维亚': 'Serbia',
  '奥地利': 'Austria',
  '巴西/美国': 'Brazil/USA',
  '德国': 'Germany',
  '德国 / 瑞典（STR 为斯堪的纳维亚靶枪规格）':
      'Germany / Sweden (STR is a Scandinavian target rifle specification)',
  '德国/瑞士': 'Germany/Switzerland',
  '德国/瑞士/美国': 'Germany/Switzerland/USA',
  '德国/瑞士（美版美国产）': 'Germany/Switzerland (US version, made in USA)',
  '德国/美国': 'Germany/USA',
  '德国设计 / 美国 HK USA 民用版': 'German design / USA HK USA civilian version',
  '德国设计 / 美国组装民用版': 'German design / Assembled in USA, civilian version',
  '德国（布尔诺生产）': 'Germany (Made in Brno)',
  '意大利': 'Italy',
  '捷克': 'Czech Republic',
  '捷克斯洛伐克': 'Czechoslovakia',
  '捷克斯洛伐克（为伊朗生产）': 'Czechoslovakia (Made for Iran)',
  '新加坡': 'Singapore',
  '日本': 'Japan',
  '日本（现行 Miroku 复刻版）': 'Japan (Current Miroku reproduction)',
  '未确认': 'Unconfirmed',
  '比利时': 'Belgium',
  '比利时 / 美国': 'Belgium / USA',
  '比利时/美国': 'Belgium/USA',
  '比利时设计 / 美国 FN America': 'Belgian design / USA FN America',
  '法国': 'France',
  '法国（德国设计，法军制式）': 'France (German design, French military standard)',
  '波兰': 'Poland',
  '瑞典': 'Sweden',
  '瑞士': 'Switzerland',
  '瑞士（原版）/ 美国（美版）/ 德国（Legend）':
      'Switzerland (Original) / USA (US version) / Germany (Legend)',
  '美国': 'USA',
  '美国 / 比利时': 'USA / Belgium',
  '美国/德国': 'USA/Germany',
  '美国密苏里州北堪萨斯城': 'North Kansas City, Missouri, USA',
  '美国新罕布什尔州多佛': 'Dover, New Hampshire, USA',
  '美国爱达荷州刘易斯顿': 'Lewiston, Idaho, USA',
  '美国犹他州冈尼森': 'Gunnison, Utah, USA',
  '美国（IWI US）': 'USA (IWI US)',
  '美国（克罗地亚 HS Produkt VHS-2 的美国版）':
      'USA (US version of Croatian HS Produkt VHS-2)',
  '芬兰': 'Finland',
  '苏联': 'Soviet Union',
  '英国': 'UK',
  '葡萄牙': 'Portugal',
  '西德': 'West Germany',
  '西班牙': 'Spain',
  '韩国': 'South Korea',
};

String originDisplay(String o) => _origins[o] ?? o;

/// 刀具国家与枪械产地共用同一张表。
String countryDisplay(String c) => _origins[c] ?? c;

/// 厂商：21 个中文厂商值（59 支枪），标准译名；查不到原样返回。
const Map<String, String> _vendors = {
  '卡拉什尼科夫': 'Kalashnikov',
  '伊热夫斯克': 'Izhevsk',
  '黑克勒-科赫': 'Heckler & Koch',
  '中国北方工业': 'Norinco',
  '捷格加廖夫工厂': 'Degtyarev Plant',
  'KBP 仪器设计局': 'KBP Instrument Design Bureau',
  '维亚茨基耶波利亚纳机械制造厂': 'Vyatskiye Polyany Machine-Building Plant',
  '以色列武器工业': 'Israel Weapon Industries (IWI)',
  '图拉兵工厂': 'Tula Arms Plant',
  '科夫罗夫兵工厂': 'Kovrov Arms Plant',
  '重庆建设工业集团': 'Chongqing Jianshe Industry Group',
  'Gatling（首批由 Greenwood 代工）': 'Gatling (first batch by Greenwood)',
  '捷格加廖夫': 'Degtyarev',
  '萨科防务': 'Saco Defense',
  '美国军械公司': 'U.S. Ordnance',
  '新加坡科技动力': 'ST Kinetics',
  '奈特军械公司': "Knight's Armament Company",
  '塔尔努夫机械厂': 'Tarnów Mechanical Works',
  '通用动力': 'General Dynamics',
  '西哈萨克斯坦机械制造公司': 'West Kazakhstan Machine-Building Company',
  '维克斯公司': 'Vickers',
};

String vendorDisplay(String v) => _vendors[v] ?? v;

/// 配件品类（22 个 type 全量）。
const Map<String, String> _accessoryTypes = {
  '两脚架': 'Bipod',
  '制退器': 'Muzzle Brake',
  '增倍镜': 'Magnifier',
  '导轨附件': 'Rail Accessory',
  '弹匣': 'Magazine',
  '弹道计算器': 'Ballistic Calculator',
  '战术灯': 'Weapon Light',
  '扳机': 'Trigger',
  '护木': 'Handguard',
  '拉机柄': 'Charging Handle',
  '握把': 'Grip',
  '机械瞄具': 'Iron Sights',
  '枪带': 'Sling',
  '枪托': 'Stock',
  '消焰器': 'Flash Hider',
  '消音器': 'Suppressor',
  '激光': 'Laser',
  '热成像': 'Thermal Imaging',
  '瞄具': 'Optic',
  '瞄具底座': 'Optic Mount',
  '脚架': 'Bipod',
  '转换枪管': 'Conversion Barrel',
};

String accessoryTypeDisplay(String t) => _accessoryTypes[t] ?? t;

/// 配件名：英文型号 + 中文通用词 → 把通用词换成英文（长词优先，避免短词先切坏长词）。
String accessoryDisplay(String name) {
  var s = name;
  for (final e in _accessoryWords) {
    s = s.replaceAll(e.$1, e.$2);
  }
  return s;
}

const List<(String, String)> _accessoryWords = [
  ('钛壳红点瞄具', 'Titanium Housing Red Dot Sight'),
  ('封闭式红点瞄具', 'Enclosed Red Dot Sight'),
  ('微型棱镜瞄准镜', 'Micro Prism Scope'),
  ('红点增倍镜组合', 'Red Dot Magnifier Combo'),
  ('热成像瞄准镜', 'Thermal Scope'),
  ('热成像瞄具', 'Thermal Sight'),
  ('战术瞄准镜', 'Tactical Scope'),
  ('定倍瞄准镜', 'Fixed Power Scope'),
  ('棱镜瞄准镜', 'Prism Scope'),
  ('绿激光瞄具', 'Green Laser Sight'),
  ('单段平板扳机', 'Single-Stage Flat Trigger'),
  ('快拆瞄具座', 'Quick Detach Mount'),
  ('战术灯座', 'Weapon Light Mount'),
  ('弹道计算器', 'Ballistic Calculator'),
  ('转换枪管', 'Conversion Barrel'),
  ('红点瞄具', 'Red Dot Sight'),
  ('全息瞄具', 'Holographic Sight'),
  ('激光瞄具', 'Laser Sight'),
  ('前握把', 'Foregrip'),
  ('手枪支架', 'Pistol Brace'),
  ('消音器', 'Suppressor'),
  ('瞄准镜', 'Scope'),
  ('增倍镜', 'Magnifier'),
  ('制退器', 'Muzzle Brake'),
  ('战术灯', 'Weapon Light'),
  ('两脚架', 'Bipod'),
  ('枪带', 'Sling'),
  ('弹匣', 'Magazine'),
  ('弹鼓', 'Drum Magazine'),
  ('护木', 'Handguard'),
  ('枪托', 'Stock'),
  ('消焰器', 'Flash Hider'),
  ('扳机', 'Trigger'),
  ('脚架', 'Bipod'),
  ('增高座', 'Riser Mount'),
  ('机械瞄具', 'Iron Sights'),
  ('拉机柄', 'Charging Handle'),
  ('握把', 'Grip'),
];

/// 刀具分类（5 个 type 全量）。
const Map<String, String> _knifeTypes = {
  '传统刀具': 'Traditional Knife',
  '军用刺刀': 'Military Bayonet',
  '军用格斗刀': 'Military Combat Knife',
  '实用折刀': 'Utility Folding Knife',
  '实用直刀': 'Utility Fixed Blade',
};

String knifeTypeDisplay(String t) => _knifeTypes[t] ?? t;

/// 复装组件 kind（4 个全量）。
const Map<String, String> _componentKinds = {
  '弹头': 'Bullet',
  '弹壳': 'Case',
  '火药': 'Powder',
  '底火': 'Primer',
};

String componentKindDisplay(String k) => _componentKinds[k] ?? k;

/// 复装工具 category（10 个全量）。
const Map<String, String> _toolCategories = {
  '压床': 'Press',
  '底火安装': 'Primer Seating',
  '底火窝与传火孔': 'Primer Pocket & Flash Hole',
  '弹壳修整': 'Case Trimming',
  '弹壳清洁': 'Case Cleaning',
  '拔弹与故障处理': 'Bullet Pulling & Troubleshooting',
  '模具与壳座': 'Dies & Shell Holders',
  '测量与规具': 'Measuring & Gauges',
  '润滑与辅助': 'Lubrication & Accessories',
  '称量与量粉': 'Weighing & Powder Measuring',
};

String toolCategoryDisplay(String c) => _toolCategories[c] ?? c;

/// 口径目录分组（4 个全量）。
const Map<String, String> _caliberGroups = {
  '手枪弹': 'Pistol',
  '步枪弹': 'Rifle',
  '马格南': 'Magnum',
  '霰弹': 'Shotshell',
};

String caliberGroupDisplay(String g) => _caliberGroups[g] ?? g;

/// 口径 bullets 里的中文弹种词（长词优先；已有英文代号时中文词直接去掉，避免 AP AP 重复）。
String bulletDisplay(String b) {
  var s = b.replaceAll('（', '(').replaceAll('）', ')');
  // 去重型：字符串里已有独立英文代号时，中文词直接去掉。
  final hasWord = (String w) =>
      RegExp('(^|[^A-Za-z0-9])$w([^A-Za-z0-9]|\$)').hasMatch(s);
  if (s.contains('穿甲燃烧曳光弹')) {
    s = hasWord('APIT')
        ? s.replaceAll('穿甲燃烧曳光弹', '')
        : s.replaceAll('穿甲燃烧曳光弹', 'APIT');
  }
  if (s.contains('穿甲燃烧弹头')) {
    s = hasWord('API')
        ? s.replaceAll('穿甲燃烧弹头', '')
        : s.replaceAll('穿甲燃烧弹头', 'API Bullet');
  }
  if (s.contains('穿甲燃烧弹')) {
    s = hasWord('API')
        ? s.replaceAll('穿甲燃烧弹', '')
        : s.replaceAll('穿甲燃烧弹', 'API');
  }
  if (s.contains('狙击穿甲弹')) {
    s = hasWord('AP')
        ? s.replaceAll('狙击穿甲弹', '')
        : s.replaceAll('狙击穿甲弹', 'Sniper AP');
  }
  if (s.contains('穿甲弹头')) {
    s = hasWord('AP')
        ? s.replaceAll('穿甲弹头', '')
        : s.replaceAll('穿甲弹头', 'AP Bullet');
  }
  if (s.contains('穿甲弹')) {
    s = hasWord('AP')
        ? s.replaceAll('穿甲弹', '')
        : s.replaceAll('穿甲弹', 'AP');
  }
  if (s.contains('独头弹')) {
    s = s.contains('Slug')
        ? s.replaceAll('独头弹', '')
        : s.replaceAll('独头弹', 'Slug');
  }
  if (s.contains('破门弹')) {
    s = s.contains('Breaching')
        ? s.replaceAll('破门弹', '')
        : s.replaceAll('破门弹', 'Breaching');
  }
  if (s.contains('鹿弹')) {
    s = s.contains('Buck')
        ? s.replaceAll('鹿弹', '')
        : s.replaceAll('鹿弹', 'Buckshot');
  }
  if (s.contains('防卫弹')) {
    s = s.contains('Buck')
        ? s.replaceAll('防卫弹', '')
        : s.replaceAll('防卫弹', 'Defense Load');
  }
  for (final e in _bulletWords) {
    s = s.replaceAll(e.$1, e.$2);
  }
  return s.replaceAll(RegExp(r'\s+'), ' ').trim();
}

const List<(String, String)> _bulletWords = [
  ('狙击穿甲弹', 'Sniper AP'),
  ('钢芯弹', 'Steel-Core Bullet'),
  ('军用弹', 'Military Load'),
  ('狙击弹', 'Sniper'),
  ('曳光弹', 'Tracer'),
  ('普通弹', 'Ball'),
  ('实心弹', 'Solid'),
  ('成品弹', 'Factory Load'),
  ('猎用弹', 'Hunting'),
  ('超音速', 'Supersonic'),
  ('亚音速', 'Subsonic'),
  ('圆头', 'Round Nose'),
  ('钢芯', 'Steel Core'),
  ('钨芯', 'Tungsten Core'),
  ('轻弹', 'Light Ball'),
  ('曳光', 'Tracer'),
  ('军用', 'Military'),
  ('民用', 'Civilian'),
  ('苏制', 'Soviet'),
  ('鸟弹', 'Birdshot'),
  ('低后坐', 'Low Recoil'),
  ('粒', 'pellets'),
];

/// 复装工作台组件串：底火通用词（长词优先）、弹壳、霰弹弹丸。
String primerDisplay(String s) {
  var r = s;
  for (final e in _primerWords) {
    r = r.replaceAll(e.$1, e.$2);
  }
  return r;
}

const List<(String, String)> _primerWords = [
  ('小型步枪军用规格底火', 'Small Rifle Military Primer'),
  ('大型步枪军用规格底火', 'Large Rifle Military Primer'),
  ('小型步枪比赛级底火', 'Small Rifle Match Primer'),
  ('小型步枪马格努姆底火', 'Small Rifle Magnum Primer'),
  ('大号步枪 Magnum 底火', 'Large Rifle Magnum Primer'),
  ('大型步枪 Magnum 底火', 'Large Rifle Magnum Primer'),
  ('小号步枪底火', 'Small Rifle Primer'),
  ('小型步枪底火', 'Small Rifle Primer'),
  ('大号步枪底火', 'Large Rifle Primer'),
  ('大型步枪底火', 'Large Rifle Primer'),
  ('小号手枪底火', 'Small Pistol Primer'),
  ('小型手枪底火', 'Small Pistol Primer'),
  ('大号手枪底火', 'Large Pistol Primer'),
  ('大型手枪底火', 'Large Pistol Primer'),
  ('霰弹底火', 'Shotshell Primer'),
  ('专用底火', 'Dedicated Primer'),
  ('底火', 'Primer'),
];

String caseDisplay(String s) => s.replaceAll('弹壳', 'Case');

/// 工作台霰弹弹丸串（仅 3 条，Slug 已有时去重）。
String shotPelletDisplay(String s) {
  var r = s;
  r = r.replaceAll('鹿弹弹丸', 'Buckshot').replaceAll('鸟弹弹丸', 'Birdshot');
  r = r.contains('Slug')
      ? r.replaceAll('独头弹弹丸', '')
      : r.replaceAll('独头弹弹丸', 'Slug');
  return r.replaceAll(RegExp(r'\s+'), ' ').trim();
}
