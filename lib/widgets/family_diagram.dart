import 'package:flutter/material.dart';
import '../models.dart';

/// 族系识别图：按枪族画的标志性特征线图（实心填充、枪口朝右），
/// 不是某支枪的精确外形，而是“认出这个族系靠哪几个特征”。
/// 目前只画规模前 5 的族系；其余族系仍走参数化轮廓兜底。
///
/// 族系名 -> （展示名，识别要点）。要点只写该族系公认的标志性特征，
/// 不写需要查证的细节数据。

const Map<String, (String, List<String>)> familyDiagramInfo = {
  'ar': (
    'AR系',
    ['导轨式机匣顶盖，可装各类瞄具', '弹匣较直、仅轻微弧度', '伸缩枪托是常见标志', '拉机柄位于机匣尾部上方'],
  ),
  'glock': (
    '格洛克系',
    ['方正套筒，棱角分明', '无外露击锤', '扳机护圈呈方形', '握把倾角大'],
  ),
  'aw': (
    '精密国际 AW 系',
    ['大口径物镜瞄准镜', '重型枪管配制退器', '拇指孔式可调枪托', '可拆弹匣与两脚架'],
  ),
  'mauser98': (
    '毛瑟 98 系',
    ['旋转后拉枪机，拉机柄向下弯', '木质护木长至近枪口', '弹仓内置，机匣顶部有桥夹导槽', '刀片式准星'],
  ),
  'mossberg': (
    '莫斯伯格系',
    ['机匣顶部后方的顶置保险', '泵动护木', '管状弹仓位于枪管下方', '珠状准星'],
  ),
  'm14': (
    'M14系',
    ['木质枪托与护木', '20 发可拆弹匣', '导气式半自动结构', '觇孔照门位于机匣后部'],
  ),
  'cheytac': (
    '切塔克系',
    ['超长重枪管配大型制退器', '大口径物镜瞄准镜', '可调贴腮与两脚架', '旋转后拉枪机'],
  ),
  'sigclassic': (
    'SIG 经典 P 系',
    ['外露击锤与待击解脱杆', '合金底把', '套筒顶部较平', '双动/单动扳机'],
  ),
  'sig': (
    'SIG系',
    ['SIG 手枪家族的套筒与握把轮廓', '多为紧凑型手枪', '底把前有附件导轨（部分型号）', '以 P250、P238 为代表'],
  ),
  'sigbolt': (
    'SIG 栓动步枪系',
    ['大物镜瞄准镜', '旋转后拉枪机', '可调贴腮枪托', '可拆弹匣'],
  ),
  'savage': (
    '萨维奇系',
    ['浮动枪管与 AccuTrigger', '可拆弹匣', '合成枪托', '旋转后拉枪机'],
  ),
  'tac': (
    '麦克米兰 TAC 系',
    ['超长重枪管与大型制退器', '麦克米兰可调枪托', '大物镜瞄准镜与两脚架', '旋转后拉枪机'],
  ),
  'tikka': (
    'Tikka系',
    ['细长枪管与瞄准镜', '可拆弹匣', '旋转后拉枪机', '简洁的合成枪托'],
  ),
  'sako': (
    '萨科系',
    ['TRG 式可调枪托', '制退器与大物镜瞄准镜', '旋转后拉枪机', '可拆弹匣'],
  ),
  'sauer': (
    '绍尔系',
    ['经典猎枪式枪托', '瞄准镜', '内置弹仓', '旋转后拉枪机'],
  ),
  'bergara': (
    '贝加拉系',
    ['HMR 式可调贴腮枪托', '竖直握把', '瞄准镜与可拆弹匣', '重型枪管'],
  ),
  'rem700': (
    '雷明顿 700 系',
    ['圆柱形机匣', '瞄准镜', '经典运动步枪枪托', '旋转后拉枪机'],
  ),
  'galil': (
    '加利尔系',
    ['AK 式弯弹匣', '折叠枪托', '护木上方的提把', '前置准星与照门'],
  ),
  'ak12': (
    'AK-12系',
    ['机匣顶部全长导轨', '现代聚合物护木', 'AK 式弯弹匣', '折叠枪托与制退器'],
  ),
  'p320': (
    'SIG P320系',
    ['无外露击锤（击针式）', '模块化握把', '套筒前端防滑纹', '底把前附件导轨'],
  ),
  'rem': (
    '雷明顿系',
    ['合成枪托栓动步枪', '瞄准镜', '可拆弹匣（部分型号）', '旋转后拉枪机'],
  ),
};

/// 族系识别图英文版（2.2.5 全量英文）：与 familyDiagramInfo 同 key，
/// 中文原文不动；英文界面显示本表。
const Map<String, (String, List<String>)> familyDiagramInfoEn = {
  'ar': (
    'AR family',
    ['Railed receiver top for mounting optics', 'Fairly straight magazine with only a slight curve', 'Collapsible stock is a common marker', 'Charging handle above the rear of the receiver'],
  ),
  'glock': (
    'Glock family',
    ['Square-edged, angular slide', 'No exposed hammer', 'Square trigger guard', 'Large grip angle'],
  ),
  'aw': (
    'Accuracy International AW family',
    ['Large-objective scope', 'Heavy barrel with muzzle brake', 'Thumbhole adjustable stock', 'Detachable magazine and bipod'],
  ),
  'mauser98': (
    'Mauser 98 family',
    ['Turn-bolt action with downward-bent bolt handle', 'Wooden handguard running almost to the muzzle', 'Internal magazine, bridge-clip guide on the receiver top', 'Blade front sight'],
  ),
  'mossberg': (
    'Mossberg family',
    ['Top-mounted safety at the rear of the receiver', 'Pump-action forend', 'Tubular magazine under the barrel', 'Bead front sight'],
  ),
  'm14': (
    'M14 family',
    ['Wooden stock and handguard', '20-round detachable magazine', 'Gas-operated semi-auto action', 'Peep rear sight at the rear of the receiver'],
  ),
  'cheytac': (
    'CheyTac family',
    ['Extra-long heavy barrel with large muzzle brake', 'Large-objective scope', 'Adjustable cheek riser and bipod', 'Turn-bolt action'],
  ),
  'sigclassic': (
    'SIG classic P family',
    ['Exposed hammer and decocking lever', 'Alloy frame', 'Fairly flat slide top', 'Double/single-action trigger'],
  ),
  'sig': (
    'SIG family',
    ['Slide and grip profile of the SIG pistol family', 'Mostly compact pistols', 'Accessory rail ahead of the trigger guard (some models)', 'Represented by the P250 and P238'],
  ),
  'sigbolt': (
    'SIG bolt-action rifle family',
    ['Large-objective scope', 'Turn-bolt action', 'Adjustable cheek-riser stock', 'Detachable magazine'],
  ),
  'savage': (
    'Savage family',
    ['Free-floated barrel and AccuTrigger', 'Detachable magazine', 'Synthetic stock', 'Turn-bolt action'],
  ),
  'tac': (
    'McMillan TAC family',
    ['Extra-long heavy barrel and large muzzle brake', 'McMillan adjustable stock', 'Large-objective scope and bipod', 'Turn-bolt action'],
  ),
  'tikka': (
    'Tikka family',
    ['Slim barrel and scope', 'Detachable magazine', 'Turn-bolt action', 'Plain synthetic stock'],
  ),
  'sako': (
    'Sako family',
    ['TRG-style adjustable stock', 'Muzzle brake and large-objective scope', 'Turn-bolt action', 'Detachable magazine'],
  ),
  'sauer': (
    'Sauer family',
    ['Classic hunting-rifle stock', 'Scope', 'Internal magazine', 'Turn-bolt action'],
  ),
  'bergara': (
    'Bergara family',
    ['HMR-style adjustable cheek-riser stock', 'Vertical grip', 'Scope and detachable magazine', 'Heavy barrel'],
  ),
  'rem700': (
    'Remington 700 family',
    ['Cylindrical receiver', 'Scope', 'Classic sporter stock', 'Turn-bolt action'],
  ),
  'galil': (
    'Galil family',
    ['Curved AK-style magazine', 'Folding stock', 'Carry handle above the handguard', 'Front post and rear sight'],
  ),
  'ak12': (
    'AK-12 family',
    ['Full-length top rail on the receiver', 'Modern polymer handguard', 'Curved AK-style magazine', 'Folding stock and muzzle brake'],
  ),
  'p320': (
    'SIG P320 family',
    ['No exposed hammer (striker-fired)', 'Modular grip', 'Front slide serrations', 'Accessory rail ahead of the trigger guard'],
  ),
  'rem': (
    'Remington family',
    ['Synthetic-stock bolt-action rifle', 'Scope', 'Detachable magazine (some models)', 'Turn-bolt action'],
  ),
};


/// 该枪是否有前 5 族系的识别图；有则返回族系 key，否则返回 null。
String? familyDiagramOf(Gun gun) {
  final n = gun.name
      .toUpperCase()
      .replaceAll(' ', '')
      .replaceAll('·', '')
      .replaceAll('-', '')
      .replaceAll('.', '')
      .replaceAll('/', '');
  if (n.contains('格洛克') || n.contains('GLOCK')) return 'glock';
  if (n.contains('莫斯伯格') || n.contains('MOSSBERG')) return 'mossberg';
  if (n.contains('精确国际') ||
      n.contains('精密国际') ||
      n.contains('ACCURACY') ||
      n.contains('L96') ||
      n.contains('AWM') ||
      n.contains('AXMC') ||
      n.contains('AXSR') ||
      n.contains('ATX') ||
      n.contains('AEMK') ||
      n.contains('AT执法')) {
    return 'aw';
  }
  if (n.contains('毛瑟') ||
      n.contains('MAUSER') ||
      n.contains('KAR98') ||
      n.contains('98K') ||
      n.contains('98式') ||
      n.contains('98A') ||
      n.contains('VZ98') ||
      n.contains('VZ24') ||
      n.contains('VZ33') ||
      n.contains('WZ29') ||
      n.contains('M49卡宾') ||
      n.contains('M48') ||
      n.contains('3340') ||
      n.contains('中正式') ||
      n.contains('M1943') ||
      n.contains('M1938') ||
      n.contains('M2447')) {
    return 'mauser98';
  }
  // 第 6-20 族（顺序即特例优先：先于 AR 系与 SIG 系余量）。
  // XM214 是通用电气转管机枪，名字含 M21 子串，不得误中 M14 分支。
  if ((n.contains('M14') ||
          RegExp(r'M1A(?![0-9])').hasMatch(n) ||
          RegExp(r'M21(?![ASC])').hasMatch(n) ||
          n.contains('M25')) &&
      !n.contains('XM214')) {
    return 'm14';
  }
  if (n.contains('切塔克') || n.contains('CHEYTAC')) return 'cheytac';
  const sigClassic = [
    'P226', 'P229', 'P220', 'P210', 'P225', 'P228', 'P230', 'P232', 'P239',
  ];
  if (sigClassic.any(n.contains)) return 'sigclassic';
  if (n.contains('P320') || n.contains('M17') || n.contains('M18')) {
    return 'p320';
  }
  if ((n.contains('萨维奇') || n.contains('SAVAGE')) &&
      !n.contains('MSR')) {
    return 'savage';
  }
  if (((n.contains('麦克米兰') || n.contains('MCMILLAN')) &&
          !n.contains('XBOLT')) ||
      n.contains('TAC50')) {
    return 'tac';
  }
  if (n.contains('蒂卡') || n.contains('TIKKA')) return 'tikka';
  if (n.contains('萨科') || n.contains('SAKO')) return 'sako';
  if (RegExp(r'(?<!西格)绍尔').hasMatch(n) ||
      RegExp(r'(?<!SIG)SAUER').hasMatch(n)) {
    return 'sauer';
  }
  if (n.contains('贝加拉') || n.contains('BERGARA')) return 'bergara';
  if (n.contains('雷明顿700') ||
      RegExp(r'M40(?![0-9])').hasMatch(n) ||
      n.contains('M24狙击')) {
    return 'rem700';
  }
  if (n.contains('加利尔') || n.contains('GALIL')) return 'galil';
  const ak12 = [
    'AK12', 'AK15', 'AK19', 'AK200', 'AK201', 'AK202', 'AK203', 'AK204',
    'AK205',
  ];
  if (ak12.any(n.contains)) return 'ak12';
  if ((n.contains('雷明顿') || n.contains('REMINGTON')) &&
      !n.contains('870')) {
    return 'rem';
  }
  // AR 系：霰弹枪里的 M4（贝内利 M4）与 M40 不在此列，M400 是 SIG 的 AR 构型步枪；
  // M16/LAR 需防子串误中（如 SOCOM 16、Galil ARM）。
  if (gun.category == '霰弹枪') return null;
  if (n.contains('M110A1')) return null; // HK417 系，不属 AR 系
  final arStart = RegExp(r'^M4(?![0-9])').hasMatch(n);
  final arWord = RegExp(r'(?<![A-Z])(M16|LAR)').hasMatch(n);
  const arMarks = [
    'AR15', 'AR10', 'AR556', 'M&P15', 'MP15', 'M&P10', 'MP10', 'M110',
    'STAG15', 'STAG10', 'DDM4', 'DD5', 'DD4', 'MR556', 'REC7', 'SIG516',
    'SIG716', 'FN15', 'LMT', 'LWRC', 'SR15', 'SR25', 'MK18', 'M468', 'DPMS',
    'C7A2', 'C8A3', 'POF', 'ZION', 'ARAD', 'SAINT', '圣徒', '锡安', '阿拉德', 'M400',
    '卡梅尔', 'SFAR', 'MSR10', 'M4E1', 'M5E1',
  ];
  if (arStart || arWord || arMarks.any(n.contains)) return 'ar';
  // SIG 栓动步枪系：Cross / SSG 3000 一系，须在通用 SIG 手枪分支之前，
  // 否则 4 支栓动步枪会误中手枪图。
  if (n.contains('CROSS') || n.contains('SSG3000')) {
    return 'sigbolt';
  }
  // SIG 系余量：SG550、MCX、P365 另有其系，M400 是 AR 构型，MPX 是冲锋枪，
  // 这些都不画 SIG 手枪图，退回参数化轮廓。
  if ((n.contains('SIG') || n.contains('西格')) &&
      !n.contains('SG550') &&
      !n.contains('SG551') &&
      !n.contains('SG552') &&
      !n.contains('SG553') &&
      !n.contains('SIG556') &&
      !n.contains('MCX') &&
      !n.contains('P365') &&
      !n.contains('M400') &&
      gun.category != '冲锋枪') {
    return 'sig';
  }
  return null;
}

class FamilyDiagram extends StatelessWidget {
  final String family;
  final double width;
  final double height;
  final Color color;
  const FamilyDiagram({
    super.key,
    required this.family,
    this.width = 288,
    this.height = 144,
    this.color = const Color(0xFFE8E2D4),
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(
        painter: _FamilyPainter(family, color),
      ),
    );
  }
}

Path _rrect(double x, double y, double w, double h, [double r = 2]) {
  return Path()..addRRect(RRect.fromLTRBR(x, y, x + w, y + h, Radius.circular(r)));
}

Path _rect(double x, double y, double w, double h) {
  return Path()..addRect(Rect.fromLTWH(x, y, w, h));
}

Path _guardRing(double x, double y, double w, double h, [double r = 3]) {
  return Path()
    ..fillType = PathFillType.evenOdd
    ..addRRect(RRect.fromLTRBR(x, y, x + w, y + h, Radius.circular(r)))
    ..addRect(Rect.fromLTWH(x + 3, y + 3, w - 6, h - 6));
}

Path _circle(double cx, double cy, double r) {
  return Path()..addOval(Rect.fromCircle(center: Offset(cx, cy), radius: r));
}

class _FamilyPainter extends CustomPainter {
  final String family;
  final Color color;
  _FamilyPainter(this.family, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 120, size.height / 60);
    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    for (final p in _shapes()) {
      canvas.drawPath(p, fill);
    }
  }

  List<Path> _shapes() {
    switch (family) {
      case 'ar':
        // M4：导轨机匣、A2 准星、直弹匣、伸缩托。
        return [
          _rect(78, 27, 38, 2.2), // 枪管
          _rrect(114, 26, 4, 4.5, 1), // 消焰器
          _rect(106, 22.5, 2, 4.5), // A2 准星柱
          _rect(104.5, 22.5, 5, 1.5), // 准星护耳
          _rrect(52, 25.5, 26, 6, 1.5), // 护木
          for (var i = 0; i < 5; i++) _rect(54.0 + i * 4, 24.5, 2, 1), // 护木导轨齿
          _rrect(28, 25, 24, 8, 1.5), // 导轨机匣
          for (var i = 0; i < 5; i++) _rect(30.0 + i * 4, 24, 2, 1), // 机匣导轨齿
          _rect(30, 22.5, 3, 2.5), // 后照门
          _rect(14, 27, 14, 2.5), // 缓冲管
          _rrect(4, 24, 10, 12, 1.5), // 伸缩枪托
          Path() // 握把
            ..moveTo(30, 33)
            ..lineTo(37, 33)
            ..quadraticBezierTo(36, 39, 35, 44)
            ..lineTo(28, 44)
            ..close(),
          Path() // 近直弹匣（轻微弧度）
            ..moveTo(42, 33)
            ..lineTo(49, 33)
            ..quadraticBezierTo(48, 40, 46, 47)
            ..lineTo(40, 47)
            ..quadraticBezierTo(41, 40, 42, 33)
            ..close(),
          _guardRing(34, 33, 11, 7),
          _rect(40, 35, 2, 4), // 扳机
        ];
      case 'glock':
        // Glock：方正套筒、方形护圈、无外露击锤、大倾角握把。
        return [
          Path() // 套筒（前端微斜）
            ..moveTo(16, 22)
            ..lineTo(108, 22)
            ..lineTo(112, 25)
            ..lineTo(112, 29)
            ..lineTo(16, 29)
            ..close(),
          _rect(20, 19, 6, 3), // 照门
          _rect(104, 19, 3, 3), // 准星
          _rect(18, 29, 66, 4), // 底把
          Path() // 大倾角握把
            ..moveTo(36, 33)
            ..lineTo(58, 33)
            ..quadraticBezierTo(57, 44, 52, 54)
            ..lineTo(38, 54)
            ..quadraticBezierTo(37, 44, 36, 33)
            ..close(),
          _guardRing(40, 33, 15, 8, 1), // 方形护圈
          _rect(48, 35, 2, 5), // 扳机
        ];
      case 'aw':
        // 精密国际 AW：大物镜瞄准镜、重枪管制退器、拇指孔枪托、脚架。
        return [
          _rrect(36, 13, 30, 5, 2.5), // 瞄准镜筒
          _rrect(64, 11, 8, 9, 2), // 大物镜
          _rrect(32, 13, 4, 5, 2), // 目镜
          _rect(42, 18, 3, 2), // 镜座
          _rect(58, 18, 3, 2),
          _rect(70, 25, 44, 3.5), // 重枪管
          _rrect(112, 23.5, 6, 6.5, 1), // 制退器
          _rrect(30, 24, 40, 9, 2), // 机匣
          Path() // 拇指孔枪托（外框 + 镂空内孔一次成型）
            ..fillType = PathFillType.evenOdd
            ..moveTo(30, 24)
            ..quadraticBezierTo(14, 23, 5, 26)
            ..lineTo(4, 36)
            ..quadraticBezierTo(14, 38, 30, 33)
            ..close()
            ..addRRect(
                RRect.fromLTRBR(12, 27, 22, 32, const Radius.circular(2))),
          _rrect(10, 20, 14, 3, 1.5), // 可调贴腮板
          _rect(44, 33, 10, 10), // 可拆弹匣
          _guardRing(38, 33, 9, 6),
          _rect(42, 35, 2, 3), // 扳机
          _circle(33, 30, 2), // 枪机拉柄球头
          Path() // 脚架
            ..moveTo(80, 33)
            ..lineTo(82, 33)
            ..lineTo(88, 54)
            ..lineTo(86, 54)
            ..close(),
          Path()
            ..moveTo(80, 33)
            ..lineTo(82, 33)
            ..lineTo(76, 54)
            ..lineTo(74, 54)
            ..close(),
        ];
      case 'mauser98':
        // 毛瑟 98：长木护木、向下弯的拉机柄、刀片准星、桥夹导槽。
        return [
          _rect(66, 26.5, 50, 2), // 枪管
          _rect(110, 23, 2, 3.5), // 刀片准星
          _rect(60, 23, 4, 3.5), // 表尺照门
          _rect(58, 26, 8, 1),
          _rrect(34, 23, 24, 9, 2), // 机匣
          Path() // 长木护木与枪托
            ..moveTo(34, 27)
            ..lineTo(88, 27)
            ..lineTo(88, 32)
            ..lineTo(44, 35)
            ..lineTo(8, 36)
            ..lineTo(5, 31)
            ..lineTo(5, 27)
            ..close(),
          _rrect(4, 26, 2.5, 11, 1), // 托底板
          _rect(40, 20, 2.5, 4), // 拉机柄杆
          _circle(41, 19, 2), // 拉机柄球头
          _rect(42, 32, 10, 2), // 弹仓底板
          _guardRing(44, 32, 10, 7),
          _rect(50, 34, 2, 4), // 扳机
        ];
      case 'mossberg':
        // 莫斯伯格：顶置保险、泵动护木、管状弹仓、珠状准星。
        return [
          _rect(50, 25, 66, 2.5), // 枪管
          _circle(112, 23, 1.5), // 珠状准星
          _rect(50, 28.5, 42, 3), // 管状弹仓
          _rrect(56, 27.5, 16, 6, 2), // 泵动护木
          _rrect(26, 23, 24, 10, 2), // 机匣
          _rect(28, 21, 4, 2), // 顶置保险
          Path() // 枪托
            ..moveTo(26, 23)
            ..lineTo(10, 24)
            ..lineTo(4, 28)
            ..lineTo(4, 38)
            ..lineTo(12, 38)
            ..lineTo(26, 33)
            ..close(),
          _rrect(3, 27, 2.5, 12, 1), // 托底板
          Path() // 握把
            ..moveTo(30, 33)
            ..lineTo(36, 33)
            ..quadraticBezierTo(35, 37, 34, 40)
            ..lineTo(28, 40)
            ..close(),
          _guardRing(32, 33, 10, 7),
          _rect(38, 35, 2, 4), // 扳机
        ];
      case 'm14':
        // M14：木质枪托、20 发弹匣、导气式半自动。
        return [
          _rect(70, 27, 46, 2), // 枪管
          _rect(108, 23.5, 2, 3.5), // 准星
          _rect(32, 22, 4, 2), // 照门
          _rrect(30, 24, 26, 9, 2), // 机匣
          _rect(88, 29, 8, 2), // 导气箍
          Path() // 木质枪托与护木
            ..moveTo(30, 27)
            ..lineTo(78, 27)
            ..lineTo(78, 32)
            ..lineTo(44, 35)
            ..lineTo(8, 36)
            ..lineTo(5, 30)
            ..lineTo(5, 27)
            ..close(),
          _rrect(4, 26, 2.5, 11, 1), // 托底板
          Path() // 弹匣
            ..moveTo(40, 33)
            ..lineTo(48, 33)
            ..quadraticBezierTo(47, 39, 47, 45)
            ..lineTo(41, 45)
            ..close(),
          _guardRing(34, 33, 10, 7),
          _rect(40, 35, 2, 4), // 扳机
        ];
      case 'cheytac':
        // 切塔克 M200：超长重枪管、大型制退器、大物镜镜、脚架。
        return [
          _rrect(30, 13, 28, 5, 2.5), // 瞄准镜筒
          _rrect(56, 11, 8, 9, 2), // 大物镜
          _rrect(26, 13, 4, 5, 2), // 目镜
          _rect(36, 18, 3, 2), // 镜座
          _rect(50, 18, 3, 2),
          _rect(64, 25, 48, 3.5), // 重枪管
          _rrect(110, 22.5, 8, 8, 1), // 大型制退器
          _rrect(28, 24, 36, 9, 2), // 机匣
          Path() // 枪托
            ..moveTo(28, 24)
            ..quadraticBezierTo(14, 23, 5, 26)
            ..lineTo(4, 36)
            ..quadraticBezierTo(14, 38, 28, 33)
            ..close(),
          _rrect(8, 20, 14, 3, 1.5), // 可调贴腮板
          _rect(40, 33, 10, 10), // 弹匣
          _guardRing(36, 33, 9, 6),
          _rect(40, 35, 2, 3), // 扳机
          _circle(30, 29, 2), // 枪机拉柄球头
          Path() // 脚架
            ..moveTo(76, 33)
            ..lineTo(78, 33)
            ..lineTo(84, 54)
            ..lineTo(82, 54)
            ..close(),
          Path()
            ..moveTo(76, 33)
            ..lineTo(78, 33)
            ..lineTo(72, 54)
            ..lineTo(70, 54)
            ..close(),
          Path() // 尾部单脚架
            ..moveTo(9, 38)
            ..lineTo(11, 38)
            ..lineTo(12, 46)
            ..lineTo(10, 46)
            ..close(),
        ];
      case 'sigclassic':
        // SIG 经典 P 系：外露击锤、待击解脱杆、合金底把。
        return [
          Path() // 套筒
            ..moveTo(16, 22)
            ..lineTo(104, 22)
            ..lineTo(108, 25)
            ..lineTo(108, 29)
            ..lineTo(16, 29)
            ..close(),
          _rect(20, 19, 6, 3), // 照门
          _rect(100, 19, 3, 3), // 准星
          _rect(13, 19, 3, 5), // 外露击锤
          _rect(18, 29, 64, 4), // 底把
          _rect(22, 30, 4, 2), // 待击解脱杆
          Path() // 握把
            ..moveTo(36, 33)
            ..lineTo(56, 33)
            ..quadraticBezierTo(55, 43, 54, 52)
            ..lineTo(38, 52)
            ..quadraticBezierTo(37, 43, 36, 33)
            ..close(),
          _guardRing(40, 33, 13, 8, 3),
          _rect(47, 35, 2, 5), // 扳机
        ];
      case 'sig':
        // SIG 系余量手枪：套筒与握把轮廓，附件导轨。
        return [
          Path() // 套筒
            ..moveTo(18, 22)
            ..lineTo(100, 22)
            ..lineTo(104, 25)
            ..lineTo(104, 29)
            ..lineTo(18, 29)
            ..close(),
          _rect(22, 19, 6, 3), // 照门
          _rect(96, 19, 3, 3), // 准星
          _rect(20, 29, 60, 4), // 底把
          _rect(66, 33, 10, 2), // 附件导轨
          Path() // 握把
            ..moveTo(38, 33)
            ..lineTo(56, 33)
            ..quadraticBezierTo(55, 43, 53, 52)
            ..lineTo(40, 52)
            ..quadraticBezierTo(39, 43, 38, 33)
            ..close(),
          _guardRing(42, 33, 13, 8, 3),
          _rect(49, 35, 2, 5), // 扳机
        ];
      case 'savage':
        // 萨维奇 110：栓动、瞄准镜、可拆弹匣、合成枪托。
        return [
          _rrect(34, 14, 28, 5, 2.5), // 瞄准镜筒
          _rrect(60, 12, 7, 9, 2), // 物镜
          _rrect(30, 14, 4, 5, 2), // 目镜
          _rect(64, 25, 50, 2.5), // 枪管
          _rrect(30, 24, 34, 9, 2), // 机匣
          Path() // 合成枪托
            ..moveTo(30, 26)
            ..lineTo(70, 26)
            ..lineTo(70, 31)
            ..lineTo(40, 34)
            ..lineTo(8, 35)
            ..lineTo(5, 30)
            ..lineTo(5, 26)
            ..close(),
          _rect(36, 20, 2.5, 4), // 枪机拉柄杆
          _circle(37, 19, 2), // 球头
          _rect(42, 33, 9, 8), // 弹匣
          _guardRing(38, 33, 10, 7),
          _rect(44, 35, 2, 4), // 扳机
        ];
      case 'tac':
        // 麦克米兰 TAC：超长重枪管、A5 式可调枪托、大物镜镜。
        return [
          _rrect(32, 12, 30, 5, 2.5), // 瞄准镜筒
          _rrect(60, 10, 9, 10, 2), // 大物镜
          _rrect(28, 12, 4, 5, 2), // 目镜
          _rect(66, 25, 46, 3.5), // 重枪管
          _rrect(110, 23, 8, 7, 1), // 制退器
          _rrect(28, 24, 38, 9, 2), // 机匣
          Path() // A5 式枪托（带尾钩）
            ..moveTo(28, 24)
            ..quadraticBezierTo(14, 23, 5, 26)
            ..lineTo(5, 36)
            ..lineTo(10, 40)
            ..lineTo(14, 36)
            ..lineTo(28, 33)
            ..close(),
          _rrect(10, 20, 14, 3, 1.5), // 可调贴腮板
          _rect(42, 33, 10, 10), // 弹匣
          _guardRing(38, 33, 9, 6),
          _rect(42, 35, 2, 3), // 扳机
          _circle(30, 29, 2), // 枪机拉柄球头
          Path() // 脚架
            ..moveTo(78, 33)
            ..lineTo(80, 33)
            ..lineTo(86, 54)
            ..lineTo(84, 54)
            ..close(),
          Path()
            ..moveTo(78, 33)
            ..lineTo(80, 33)
            ..lineTo(74, 54)
            ..lineTo(72, 54)
            ..close(),
        ];
      case 'tikka':
        // Tikka T3x：细长枪管、简洁合成枪托。
        return [
          _rrect(36, 15, 26, 4.5, 2.5), // 瞄准镜筒
          _rrect(60, 13, 6, 8, 2), // 物镜
          _rect(64, 25, 52, 2), // 细长枪管
          _rrect(32, 24, 32, 8, 2), // 机匣
          Path() // 简洁枪托
            ..moveTo(32, 26)
            ..lineTo(66, 26)
            ..lineTo(66, 30)
            ..lineTo(40, 33)
            ..lineTo(10, 34)
            ..lineTo(6, 29)
            ..lineTo(6, 26)
            ..close(),
          _rect(38, 20, 2.5, 4), // 枪机拉柄杆
          _circle(39, 19, 2), // 球头
          _rect(44, 32, 8, 7), // 小弹匣
          _guardRing(40, 32, 10, 7),
          _rect(46, 34, 2, 4), // 扳机
        ];
      case 'sako':
        // 萨科 TRG：TRG 式枪托、制退器、脚架。
        return [
          _rrect(34, 13, 28, 5, 2.5), // 瞄准镜筒
          _rrect(60, 11, 8, 9, 2), // 物镜
          _rect(66, 25, 46, 3), // 枪管
          _rrect(110, 23.5, 6, 6, 1), // 制退器
          _rrect(30, 24, 36, 9, 2), // 机匣
          Path() // TRG 式枪托
            ..moveTo(30, 24)
            ..lineTo(16, 24)
            ..lineTo(10, 28)
            ..lineTo(10, 34)
            ..lineTo(6, 38)
            ..lineTo(14, 38)
            ..lineTo(30, 33)
            ..close(),
          _rrect(12, 21, 12, 3, 1.5), // 贴腮板
          _rect(42, 33, 10, 9), // 弹匣
          _guardRing(38, 33, 9, 6),
          _rect(42, 35, 2, 3), // 扳机
          _circle(32, 29, 2), // 枪机拉柄球头
          Path() // 脚架
            ..moveTo(80, 33)
            ..lineTo(82, 33)
            ..lineTo(88, 54)
            ..lineTo(86, 54)
            ..close(),
          Path()
            ..moveTo(80, 33)
            ..lineTo(82, 33)
            ..lineTo(76, 54)
            ..lineTo(74, 54)
            ..close(),
        ];
      case 'sauer':
        // 绍尔 100：经典猎枪式枪托、内置弹仓。
        return [
          _rrect(36, 15, 26, 4.5, 2.5), // 瞄准镜筒
          _rrect(60, 13, 6, 8, 2), // 物镜
          _rect(64, 26, 52, 2), // 枪管
          _rrect(32, 24, 32, 8, 2), // 机匣
          Path() // 猎枪式枪托
            ..moveTo(32, 26)
            ..lineTo(72, 26)
            ..lineTo(72, 31)
            ..lineTo(42, 34)
            ..lineTo(10, 35)
            ..lineTo(6, 30)
            ..lineTo(6, 26)
            ..close(),
          _rect(40, 32, 10, 2), // 弹仓底板
          _rect(38, 20, 2.5, 4), // 枪机拉柄杆
          _circle(39, 19, 2), // 球头
          _guardRing(40, 32, 10, 7),
          _rect(46, 34, 2, 4), // 扳机
        ];
      case 'bergara':
        // 贝加拉 B-14 HMR：可调贴腮、竖直握把、重枪管。
        return [
          _rrect(34, 13, 28, 5, 2.5), // 瞄准镜筒
          _rrect(60, 11, 8, 9, 2), // 物镜
          _rect(66, 25, 48, 3), // 重枪管
          _rrect(30, 24, 36, 9, 2), // 机匣
          Path() // HMR 式枪托
            ..moveTo(30, 24)
            ..lineTo(12, 24)
            ..lineTo(5, 28)
            ..lineTo(5, 37)
            ..lineTo(14, 37)
            ..lineTo(30, 33)
            ..close(),
          _rrect(10, 21, 14, 3, 1.5), // 可调贴腮板
          Path() // 竖直握把
            ..moveTo(26, 33)
            ..lineTo(32, 33)
            ..quadraticBezierTo(31, 38, 31, 42)
            ..lineTo(25, 42)
            ..close(),
          _rect(42, 33, 9, 9), // 弹匣
          _guardRing(38, 33, 9, 6),
          _rect(42, 35, 2, 3), // 扳机
          _circle(32, 29, 2), // 枪机拉柄球头
        ];
      case 'rem700':
        // 雷明顿 700：圆柱机匣、经典运动步枪枪托。
        return [
          _rrect(36, 15, 26, 4.5, 2.5), // 瞄准镜筒
          _rrect(60, 13, 6, 8, 2), // 物镜
          _rect(64, 26, 52, 2), // 枪管
          _rrect(32, 24, 32, 8, 4), // 圆柱形机匣
          Path() // 运动步枪枪托
            ..moveTo(32, 26)
            ..lineTo(68, 26)
            ..lineTo(68, 31)
            ..lineTo(42, 34)
            ..lineTo(10, 35)
            ..lineTo(6, 30)
            ..lineTo(6, 26)
            ..close(),
          _rect(40, 32, 10, 2), // 弹仓底板
          _rect(38, 20, 2.5, 4), // 枪机拉柄杆
          _circle(39, 19, 2), // 球头
          _guardRing(40, 32, 10, 7),
          _rect(46, 34, 2, 4), // 扳机
        ];
      case 'galil':
        // 加利尔：AK 式弯弹匣、折叠枪托、护木提把。
        return [
          _rect(78, 27, 38, 2.2), // 枪管
          _rect(106, 23, 2, 4), // 准星
          _rrect(52, 25.5, 26, 6, 1.5), // 护木
          _rect(58, 23, 14, 1.5), // 提把
          _rect(58, 23, 1.5, 2.5),
          _rect(70.5, 23, 1.5, 2.5),
          _rrect(28, 25, 24, 8, 1.5), // 机匣
          _rect(6, 26, 20, 2.5), // 折叠枪托骨架
          _rect(6, 31, 20, 2.5),
          _rect(4, 26, 2.5, 7.5),
          Path() // 握把
            ..moveTo(30, 33)
            ..lineTo(37, 33)
            ..quadraticBezierTo(36, 39, 35, 44)
            ..lineTo(28, 44)
            ..close(),
          Path() // 大弯弹匣
            ..moveTo(42, 33)
            ..lineTo(49, 33)
            ..quadraticBezierTo(50, 40, 46, 49)
            ..lineTo(39, 49)
            ..quadraticBezierTo(41, 41, 42, 33)
            ..close(),
          _guardRing(34, 33, 11, 7),
          _rect(40, 35, 2, 4), // 扳机
        ];
      case 'ak12':
        // AK-12：全长导轨、现代护木、折叠枪托。
        return [
          _rect(78, 27, 36, 2.2), // 枪管
          _rrect(112, 25.5, 5, 5, 1), // 制退器
          _rect(104, 23, 2, 4), // 准星
          _rrect(52, 25.5, 26, 6, 1.5), // 聚合物护木
          for (var i = 0; i < 5; i++) _rect(54.0 + i * 4, 24.5, 2, 1), // 护木导轨齿
          _rrect(28, 25, 24, 8, 1.5), // 机匣
          for (var i = 0; i < 5; i++) _rect(30.0 + i * 4, 24, 2, 1), // 机匣导轨齿
          Path() // 折叠枪托
            ..moveTo(26, 25)
            ..lineTo(8, 24)
            ..lineTo(4, 28)
            ..lineTo(4, 34)
            ..lineTo(10, 35)
            ..lineTo(26, 33)
            ..close(),
          Path() // 握把
            ..moveTo(30, 33)
            ..lineTo(37, 33)
            ..quadraticBezierTo(36, 39, 35, 44)
            ..lineTo(28, 44)
            ..close(),
          Path() // 弯弹匣
            ..moveTo(42, 33)
            ..lineTo(49, 33)
            ..quadraticBezierTo(49, 40, 47, 48)
            ..lineTo(40, 48)
            ..quadraticBezierTo(41, 40, 42, 33)
            ..close(),
          _guardRing(34, 33, 11, 7),
          _rect(40, 35, 2, 4), // 扳机
        ];
      case 'p320':
        // SIG P320：击针式、模块化握把、无外露击锤。
        return [
          Path() // 套筒
            ..moveTo(16, 22)
            ..lineTo(108, 22)
            ..lineTo(112, 25)
            ..lineTo(112, 29)
            ..lineTo(16, 29)
            ..close(),
          _rect(20, 19, 6, 3), // 照门
          _rect(104, 19, 3, 3), // 准星
          _rect(18, 29, 66, 4), // 底把
          _rect(70, 33, 10, 2), // 附件导轨
          _rect(34, 31, 4, 3), // 海狸尾
          Path() // 模块化握把
            ..moveTo(36, 33)
            ..lineTo(58, 33)
            ..quadraticBezierTo(57, 44, 55, 54)
            ..lineTo(39, 54)
            ..quadraticBezierTo(38, 44, 36, 33)
            ..close(),
          _guardRing(40, 33, 14, 8, 2),
          _rect(48, 35, 2, 5), // 扳机
        ];
      case 'rem':
        // 雷明顿系余量栓动：合成枪托、可拆弹匣。
        return [
          _rrect(36, 15, 26, 4.5, 2.5), // 瞄准镜筒
          _rrect(60, 13, 6, 8, 2), // 物镜
          _rect(64, 26, 52, 2), // 枪管
          _rrect(32, 24, 32, 8, 2), // 机匣
          Path() // 合成枪托
            ..moveTo(32, 26)
            ..lineTo(66, 26)
            ..lineTo(66, 31)
            ..lineTo(40, 34)
            ..lineTo(10, 35)
            ..lineTo(6, 30)
            ..lineTo(6, 26)
            ..close(),
          _rect(42, 32, 9, 8), // 弹匣
          _rect(38, 20, 2.5, 4), // 枪机拉柄杆
          _circle(39, 19, 2), // 球头
          _guardRing(40, 32, 10, 7),
          _rect(46, 34, 2, 4), // 扳机
        ];
      case 'sigbolt':
        // SIG 栓动步枪（Cross / SSG 3000 一系）：瞄准镜、自由浮置护木、
        // 可调贴腮枪托、可拆弹匣、后拉枪机拉柄；与手枪图一眼可区分。
        return [
          _rrect(34, 13, 28, 5, 2.5), // 瞄准镜筒
          _rrect(60, 11, 8, 9, 2), // 大物镜
          _rrect(30, 13, 4, 5, 2), // 目镜
          _rect(40, 18, 3, 2), // 镜座
          _rect(56, 18, 3, 2),
          _rect(66, 25, 46, 2.5), // 枪管
          _rrect(112, 23.5, 6, 5.5, 1), // 制退器
          _rrect(66, 28.5, 30, 3, 1), // 自由浮置护木（与枪管留空隙）
          _rrect(28, 24, 38, 9, 2), // 机匣
          Path() // 可调贴腮枪托
            ..moveTo(28, 24)
            ..quadraticBezierTo(14, 23, 6, 26)
            ..lineTo(6, 36)
            ..lineTo(12, 38)
            ..lineTo(28, 33)
            ..close(),
          _rrect(8, 20, 14, 3, 1.5), // 可调贴腮板
          _rect(36, 20, 2.5, 4), // 枪机拉柄杆
          _circle(37, 19, 2), // 拉柄球头
          _rect(44, 33, 9, 9), // 可拆弹匣
          _guardRing(40, 33, 10, 7),
          _rect(46, 35, 2, 4), // 扳机
        ];
      default:
        return [];
    }
  }

  @override
  bool shouldRepaint(covariant _FamilyPainter old) =>
      old.family != family || old.color != color;
}
