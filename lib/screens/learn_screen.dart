import 'package:flutter/material.dart';

import '../i18n.dart';
import '../widgets/app_top_bar.dart';

/// 射手基础课：静态内容页，只讲基础和安全。
/// 2.2.5 全量英文：英文界面显示 paragraphsEn，中文段落原文不动；
/// 章节标题与页面文案走 i18n 三语。
/// 红线：不写制造、改装、零件交易相关内容，不做弹道计算；
/// 读风只讲定性观察，具体修正看自己 DOPE 实测，不给风偏公式与换算表；
/// DOPE 章只讲怎么读自己实测的卡。
class LearnScreen extends StatelessWidget {
  const LearnScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final chapters = <_Chapter>[
      _Chapter('learn_c_safety', [
        '四条铁律，任何时候都不能破：枪口永远不指向不想击中的人或物；手指离开扳机，直到瞄准具对准目标才放上；永远当作枪已上膛来对待；开枪前确认目标以及目标后方。',
        '拿起任何一把枪，第一件事是验枪：确认枪膛和弹仓是空的。别人递过来的枪，也要自己再验一次，不要只信对方说“空的”。',
        '装弹、退弹、清枪都在安全方向上做，枪口朝向挡弹墙或地面安全区。靶场听从安全员指令，听到“停火”立刻停手、手指离扳机。',
        '护目镜和耳罩每次都要戴。哪怕只打一发，听力损伤也是不可逆的。',
      ],
      paragraphsEn: [
        'The four rules are never to be broken: never point the muzzle at anything you do not intend to shoot; keep your finger off the trigger until the sights are on target; always treat the gun as if it were loaded; and confirm your target and what is behind it before firing.',
        'Pick up any gun and the first thing you do is check it: confirm the chamber and magazine are empty. Even a gun handed to you by someone else gets checked again by you — never take their word that it is empty.',
        'Load, unload and clear on a safe direction, with the muzzle toward a backstop or a safe patch of ground. On a range, follow the safety officer: on hearing cease-fire, stop at once and take your finger off the trigger.',
        'Wear eye protection and ear protection every time. Even a single shot can cause irreversible hearing damage.',
      ]),
      _Chapter('learn_c_zero', [
        '归零就是让瞄准点和弹着点在某个距离上重合。先定一个归零距离，常见的起步是 25 码或 100 码，定下来就不要来回换。',
        '打三发一组，看弹着点的中心偏哪边：偏左就往右调，偏上就往下调——调的方向是“追着弹着点走”。每格调多少看瞄具说明书，调完再打一组验证。',
        '归零要从稳固的依托开始打，消除姿势抖动的影响；等归零稳定了，再练无依托。',
        '换弹药、换批次、换枪管配件后归零都可能变，重新验证一次再记到卡上。归零卡只记实测结果，不抄别人的数。',
      ],
      paragraphsEn: [
        'Zeroing means making the point of aim and the point of impact coincide at a given distance. Pick a zero distance first — 25 yards or 100 yards are common starting points — and stick with it instead of switching back and forth.',
        'Shoot a three-round group and look at where the center of the group sits: if it is left, adjust right; if it is high, adjust down — you chase the group. Check the sight manual for how much each click moves the impact, then shoot another group to confirm.',
        'Start zeroing from a solid rest to take wobble out of the equation; once the zero is stable, practice unsupported.',
        'Ammunition, batch or barrel-accessory changes can shift your zero — re-verify it and record it on your card. A zero card only records measured results, never someone else’s numbers.',
      ]),
      _Chapter('learn_c_breath', [
        '呼吸用自然停顿法：吸气、呼气，在呼气末尾自然停住的那一两秒里击发，不要憋一口大气硬撑。',
        '扳机要匀速向后压，像按门铃一样稳，击发瞬间不要猛扣、不要预判枪响而提前抖。',
        '击发后保持瞄准一秒再松手，这叫跟进（follow-through），能帮你看出自己有没有在击发瞬间推枪。',
        '练扳机最好的办法是空枪练习：确认枪膛为空后，对着安全方向反复练压扳机，看准星动不动。',
      ],
      paragraphsEn: [
        'Breathe with the natural pause: breathe in, breathe out, and fire during the one or two seconds of natural stillness at the end of the exhale. Do not hold a big breath and force it.',
        'Press the trigger straight back at a steady speed, like ringing a doorbell. Do not jerk it at the moment of firing, and do not flinch in anticipation of the shot.',
        'Hold your aim for a second after the shot before relaxing — this is follow-through, and it shows whether you pushed the gun at the moment of firing.',
        'The best trigger practice is dry fire: after confirming the chamber is empty, practice pressing the trigger toward a safe direction and watch whether the front sight moves.',
      ]),
      _Chapter('learn_c_stance', [
        '站姿：双脚与肩同宽，身体略向前倾，重心在前脚掌，枪托实实在在抵住肩窝，不要留空隙。',
        '卧姿是最稳的：身体与枪线成一个小角度，双腿自然分开，肘部撑地形成稳定的三角。',
        '坐姿和跪姿介于两者之间：肘部顶在膝盖上，骨骼承重而不是靠肌肉硬撑，肌肉一抖枪就抖。',
        '不管哪种姿势，原则都一样：骨骼支撑、身体放松、枪托抵实、瞄准线自然落在目标上，不用肌肉去“拽”枪。',
      ],
      paragraphsEn: [
        'Standing: feet shoulder-width apart, body leaning slightly forward, weight on the balls of your feet, buttstock firmly seated in the shoulder pocket with no gap.',
        'Prone is the most stable: body at a slight angle to the line of fire, legs naturally apart, elbows on the ground forming a stable triangle.',
        'Sitting and kneeling sit in between: elbow on the knee, weight carried by bone rather than muscle — the moment muscle strains, the gun shakes.',
        'Whatever the position, the principles are the same: bone support, relaxed body, buttstock seated, and the sight line falling naturally on target without muscling the gun around.',
      ]),
      _Chapter('learn_c_wind', [
        '读风先看身边的东西：靶场旗、草、树叶、水面涟漪、扬起的尘土，都能告诉你风向和大概风力。',
        '风向分两种：正侧风影响最大，顺风逆风主要影响远距离的弹着高低。先学会判断“风从哪边来”，再谈修正。',
        '风越大，弹着点偏得越远；距离越远，风的影响也越大。这是定性规律，具体偏多少没有通用数——看你自己的 DOPE 实测。',
        '本课不给风偏公式和换算表：风是现场条件，唯一可靠的是你在同样风况下打出来的实测记录。',
      ],
      paragraphsEn: [
        'Read the wind from what is around you: range flags, grass, leaves, ripples on water and kicked-up dust all tell you direction and rough strength.',
        'Two kinds of wind: a full crosswind matters most, while headwinds and tailwinds mainly affect elevation at long range. Learn which way the wind comes from first, then talk about corrections.',
        'Stronger wind means more drift, and longer distance means more wind effect. That is the qualitative rule — exactly how much it drifts has no universal number. Check your own measured DOPE.',
        'This lesson gives no wind formulas or conversion tables: wind is a field condition, and the only reliable reference is the measured record you shot in the same conditions.',
      ]),
      _Chapter('learn_c_dope', [
        'DOPE 是你自己实测的数据卡：每个距离上，你的枪、你的弹，弹着点实际落在哪、归零要调几格，全记在上面。',
        '读卡的方法是查表：先找到距离那一行，再看那一行记的修正和弹着点，不要凭印象估。',
        '一张卡只对应一套组合：同一支枪、同一弹药批次。换弹药就另起一张卡，混记等于没记。',
        '卡上的数只能来自你打出来的成绩：靶场成绩和测速记录就是 DOPE 的原材料，平时多记，关键时刻才有得查。',
      ],
      paragraphsEn: [
        'DOPE is your own measured data card: at each distance, where your gun and your ammunition actually print, and how many clicks your zero needs — all written down.',
        'Read the card like a table: find the row for the distance, then read the correction and point of impact on that row. Do not guess from memory.',
        'One card covers one combination only: the same gun and the same ammunition batch. Change ammunition and you start a new card — mixing records is the same as having none.',
        'The numbers on the card can only come from your own shooting: range scores and chronograph records are the raw material for DOPE. Record often, so you have something to check when it matters.',
      ]),
      _Chapter('learn_c_fault', [
        '不发火：保持枪口朝安全方向，等候至少 30 秒，手指离开扳机，再按规程退弹检查。不要立刻拉枪机对着自己看。',
        '卡壳或双进弹：枪口朝安全方向，退弹匣、拉枪机清出卡住的弹，清完再检查枪膛是否干净。',
        '枪声、后坐明显不对（特别轻或特别闷）：立刻停手，枪口朝安全方向，检查枪管里有没有异物，不要接着打下一发。',
        '自己处理不了的故障，交给靶场安全员或枪匠，不要在现场拆改。',
      ],
      paragraphsEn: [
        'Failure to fire: keep the muzzle on a safe direction, wait at least 30 seconds with your finger off the trigger, then unload and inspect by the book. Do not pull the bolt back and look toward yourself right away.',
        'Jam or double feed: muzzle on a safe direction, drop the magazine, work the bolt to clear the jammed round, then check the chamber is clean.',
        'A shot that sounds or recoils clearly wrong — unusually light or dull: stop at once, muzzle on a safe direction, and check the barrel for obstructions. Do not fire the next round.',
        'A malfunction you cannot handle yourself goes to the range safety officer or a gunsmith. Do not take the gun apart and modify it on the spot.',
      ]),
      _Chapter('learn_c_etiquette', [
        '听从安全员的口令：喊停火就停手，冷枪线期间不碰枪、不装弹，等“热线”指令再开始。',
        '枪口永远朝向靶的方向或地面安全区，走动、递枪、放枪时也一样。',
        '自己的弹壳自己收，靶纸打完及时换，不要占用别人的靶位和时间。',
        '新手多问、慢打没人笑话；抢快、炫技、违反安全规则才是靶场最不受欢迎的行为。',
      ],
      paragraphsEn: [
        'Follow the safety officer’s commands: on cease-fire, stop and do not touch guns or load; wait for the hot-line call before starting again.',
        'Keep the muzzle toward the target or a safe patch of ground at all times — while walking, handing a gun over, or putting one down.',
        'Pick up your own brass, change shot-up targets promptly, and do not hog someone else’s lane or time.',
        'Nobody laughs at a beginner who asks questions and shoots slowly. Rushing, showing off and breaking safety rules are what a range dislikes most.',
      ]),
    ];
    return ValueListenableBuilder<String>(
      valueListenable: localeNotifier,
      builder: (_, __, ___) => Scaffold(
        appBar: SubPageAppBar(title: tr('learn_title')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(tr('learn_note'),
                style: const TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 12),
            ...chapters.map((c) => Card(
                  child: ExpansionTile(
                    title: Text(c.titleKey.isEmpty ? '' : tr(c.titleKey),
                        style: const TextStyle(
                            fontWeight: FontWeight.bold)),
                    children: (localeNotifier.value == localeEn &&
                            c.paragraphsEn.length == c.paragraphs.length
                        ? c.paragraphsEn
                        : c.paragraphs)
                        .map((p) => Padding(
                              padding: const EdgeInsets.fromLTRB(
                                  16, 0, 16, 12),
                              child: Text(p,
                                  style: const TextStyle(fontSize: 14)),
                            ))
                        .toList(),
                  ),
                )),
          ],
        ),
      ),
    );
  }
}

class _Chapter {
  final String titleKey;
  final List<String> paragraphs;
  /// 英文段落（2.2.5 全量英文）：英文界面显示它，与中文段落一一对应。
  final List<String> paragraphsEn;
  const _Chapter(this.titleKey, this.paragraphs, {this.paragraphsEn = const []});
}
