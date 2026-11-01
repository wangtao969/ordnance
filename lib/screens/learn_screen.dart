import 'package:flutter/material.dart';

import '../i18n.dart';
import '../widgets/app_top_bar.dart';

/// 射手基础课：静态内容页，只讲基础和安全。
/// 课文正文用中文（描述性 prose 保留中文的既有惯例），
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
      ]),
      _Chapter('learn_c_zero', [
        '归零就是让瞄准点和弹着点在某个距离上重合。先定一个归零距离，常见的起步是 25 码或 100 码，定下来就不要来回换。',
        '打三发一组，看弹着点的中心偏哪边：偏左就往右调，偏上就往下调——调的方向是“追着弹着点走”。每格调多少看瞄具说明书，调完再打一组验证。',
        '归零要从稳固的依托开始打，消除姿势抖动的影响；等归零稳定了，再练无依托。',
        '换弹药、换批次、换枪管配件后归零都可能变，重新验证一次再记到卡上。归零卡只记实测结果，不抄别人的数。',
      ]),
      _Chapter('learn_c_breath', [
        '呼吸用自然停顿法：吸气、呼气，在呼气末尾自然停住的那一两秒里击发，不要憋一口大气硬撑。',
        '扳机要匀速向后压，像按门铃一样稳，击发瞬间不要猛扣、不要预判枪响而提前抖。',
        '击发后保持瞄准一秒再松手，这叫跟进（follow-through），能帮你看出自己有没有在击发瞬间推枪。',
        '练扳机最好的办法是空枪练习：确认枪膛为空后，对着安全方向反复练压扳机，看准星动不动。',
      ]),
      _Chapter('learn_c_stance', [
        '站姿：双脚与肩同宽，身体略向前倾，重心在前脚掌，枪托实实在在抵住肩窝，不要留空隙。',
        '卧姿是最稳的：身体与枪线成一个小角度，双腿自然分开，肘部撑地形成稳定的三角。',
        '坐姿和跪姿介于两者之间：肘部顶在膝盖上，骨骼承重而不是靠肌肉硬撑，肌肉一抖枪就抖。',
        '不管哪种姿势，原则都一样：骨骼支撑、身体放松、枪托抵实、瞄准线自然落在目标上，不用肌肉去“拽”枪。',
      ]),
      _Chapter('learn_c_wind', [
        '读风先看身边的东西：靶场旗、草、树叶、水面涟漪、扬起的尘土，都能告诉你风向和大概风力。',
        '风向分两种：正侧风影响最大，顺风逆风主要影响远距离的弹着高低。先学会判断“风从哪边来”，再谈修正。',
        '风越大，弹着点偏得越远；距离越远，风的影响也越大。这是定性规律，具体偏多少没有通用数——看你自己的 DOPE 实测。',
        '本课不给风偏公式和换算表：风是现场条件，唯一可靠的是你在同样风况下打出来的实测记录。',
      ]),
      _Chapter('learn_c_dope', [
        'DOPE 是你自己实测的数据卡：每个距离上，你的枪、你的弹，弹着点实际落在哪、归零要调几格，全记在上面。',
        '读卡的方法是查表：先找到距离那一行，再看那一行记的修正和弹着点，不要凭印象估。',
        '一张卡只对应一套组合：同一支枪、同一弹药批次。换弹药就另起一张卡，混记等于没记。',
        '卡上的数只能来自你打出来的成绩：靶场成绩和测速记录就是 DOPE 的原材料，平时多记，关键时刻才有得查。',
      ]),
      _Chapter('learn_c_fault', [
        '不发火：保持枪口朝安全方向，等候至少 30 秒，手指离开扳机，再按规程退弹检查。不要立刻拉枪机对着自己看。',
        '卡壳或双进弹：枪口朝安全方向，退弹匣、拉枪机清出卡住的弹，清完再检查枪膛是否干净。',
        '枪声、后坐明显不对（特别轻或特别闷）：立刻停手，枪口朝安全方向，检查枪管里有没有异物，不要接着打下一发。',
        '自己处理不了的故障，交给靶场安全员或枪匠，不要在现场拆改。',
      ]),
      _Chapter('learn_c_etiquette', [
        '听从安全员的口令：喊停火就停手，冷枪线期间不碰枪、不装弹，等“热线”指令再开始。',
        '枪口永远朝向靶的方向或地面安全区，走动、递枪、放枪时也一样。',
        '自己的弹壳自己收，靶纸打完及时换，不要占用别人的靶位和时间。',
        '新手多问、慢打没人笑话；抢快、炫技、违反安全规则才是靶场最不受欢迎的行为。',
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
                    children: c.paragraphs
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
  const _Chapter(this.titleKey, this.paragraphs);
}
