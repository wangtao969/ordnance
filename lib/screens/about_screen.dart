import 'dart:io';
import '../i18n.dart';

import 'package:flutter/material.dart';
import '../widgets/app_toast.dart';
import '../system_actions.dart';
import '../widgets/app_top_bar.dart';

/// 项目手册：Ordnance 是什么、能干什么、每块怎么用。
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  Widget _section(String title, List<String> lines, Color grey,
      {IconData icon = Icons.info_outlined}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 22),
            const SizedBox(width: 8),
            Text(title,
                style: const TextStyle(
                    fontSize: 17, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < lines.length; i++) ...[
                  if (i > 0) const SizedBox(height: 8),
                  Text(lines[i], style: const TextStyle(fontSize: 14)),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final grey = dark ? const Color(0xFF8A8578) : const Color(0xFF9A917F);
    return Scaffold(
      appBar: SubPageAppBar(title: tr('about_title')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _section(tr('about_intro'), [
            'Ordnance 是一款枪械图鉴 App，包含四块：枪械图鉴、配件目录、复装手册与社区。',
            '图鉴收录 738 支真实枪械（8 个品类），每支含厂商、口径、动作、枪管、全长、重量、弹容量、产地与美国零售参考价；品类图片与名枪照片来自 Wikimedia Commons 免费授权图，详情页脚已署名。',
            '配件目录收录 163 条国内外知名厂商配件，按品类筛选；复装手册收录子弹目录、装药表、供应商与 SOP，只收录 Hornady 等公开手册原文，查不到出处的留空，绝不现编、不推算。',
            '刀具图鉴另收录 21 把各国军刀与知名实用刀，按军用格斗刀、军用刺刀、实用直刀、实用折刀、传统刀具 5 类与国家筛选；图为刀形剪影，非实物照片，刃长与钢材查不到的写未确认。',
            '社区目前为本机版：账号、帖子、等级、勋章、靶场成绩都只保存在本机，换设备或联网版上线后需重新注册；经验榜为本机数据。',
            '本项目开源：GitHub 仓库 wangtao969/ordnance，设置页“GitHub 开源代码”可直达。',
          ], grey, icon: Icons.info_outlined),
          _section(tr('about_manual_catalog'), [
            '首页图鉴页顶部搜索框可按名称、厂商、口径搜索；品类卡点进去按厂商分组折叠浏览。',
            '枪械详情页可把枪登记进“我的枪柜”（拥有状态）；枪柜里记购买日期、入手价、射弹数、归零状态、保养与故障，配件可装机到具体枪上。',
            '图鉴首屏有枪柜入口；停售名枪鉴赏在图鉴页内有独立入口。',
            '刀具图鉴在图鉴页枪械品类下方有独立入口，点进去按分类与国家筛选，图鉴搜索也能搜到刀具。',
            '枪柜里的枪可从配件目录选配件装机到具体枪上；枪柜页可添加或移除已拥有的枪。',
          ], grey, icon: Icons.grid_view_rounded),
          _section(tr('about_manual_reload'), [
            '工具 Tab → 配件目录：按品类筛选，点卡片看适配枪械、售价与购买渠道。',
            '工具 Tab → 复装手册：子弹目录查尺寸与适配枪械；装药表只看手册原文；复装记录页按 SOP 打勾，全部完成才能记一条。',
            '工具 Tab → 复装记录：输入时上方实时显示单位换算、枪口动能与后坐力换算，不给装药建议；两枪参数对比只对照纸面参数，不画弹道曲线。',
            '工具 Tab → DOPE数据本：归零助手输入上方实时显示偏移量 MOA/密位与瞄具调节格数；复装成本：按输入价格算每发成本，不提供报价。',
            '工具 Tab → 弹药库存与保养记录：只存本机，不用登录；每条装药均带手册名与版本，查不到版本的不编；全 App 输入框统一圆角与聚焦铜色边框。',
            '配件详情可点“加入我的配件库”，只记本机件数，不登录、不交易；工具页的计算输入退出后仍保留，展开区与卡片风格统一。',
          ], grey, icon: Icons.handyman_outlined),
          _section(tr('about_manual_community'), [
            '社区首页是动态流：关注的人与全站用户的图文分享；动态顶部有经验榜前三横条，点开展开完整榜；右上角信封进私信。',
            '发动态点右下角大圆钮；草稿会自动保存；发动态可带定位、天气快照、图片或视频。',
            '发帖、评论、获赞等动态互动涨经验，等级 1–60 共六档铭牌；勋章墙在个人主页，共 28 枚；新勋章获得时会自动发一条公开动态。',
            '私信入口在社区右上角与“我的”页，带未读红点；编辑资料与退出登录在“我的”页。',
            '创始、管理员、版主头像右下角有橙色 V 标；等级铭牌特效为向外散发的光，不遮挡铭牌本身。',
            '私信行间为淡灰细线，输入区顶部不再有横线。',
          ], grey, icon: Icons.forum_outlined),
          _section(tr('about_manual_update'), [
            if (!Platform.isIOS)
              '设置页 → 检查更新：有新版时可直接下载安装包并拉起系统安装器安装（需在系统设置中允许本应用安装未知应用）。',
            '设置页 → 清理缓存：只删临时文件（含已下载的安装包），账号、靶场成绩、弹药库存、保养与复装记录等本机数据不会被删除。',
            '设置页顶部有快捷操作面板：检查更新、清理缓存、导出我的数据都在上面。',
            tr('about_hist_01'),
            tr('about_hist_02'),
            tr('about_hist_03'),
            tr('about_hist_04'),
            tr('about_hist_05'),
            tr('about_hist_06'),
            tr('about_hist_07'),
            tr('about_hist_08'),
            tr('about_hist_09'),
            tr('about_hist_10'),
            tr('about_hist_11'),
            tr('about_hist_12'),
            tr('about_hist_13'),
            tr('about_hist_14'),
            tr('about_hist_15'),
            tr('about_hist_16'),
            tr('about_hist_17'),
            tr('about_hist_18'),
            tr('about_hist_19'),
            tr('about_hist_20'),
            tr('about_hist_21'),
            tr('about_hist_22'),
            tr('about_hist_23'),
            tr('about_hist_24'),
            tr('about_hist_25'),
            tr('about_hist_26'),
            tr('about_hist_27'),
            tr('about_hist_28'),
            tr('about_hist_29'),
            tr('about_hist_30'),
            tr('about_hist_31'),
            tr('about_hist_32'),
            tr('about_hist_33'),
            tr('about_hist_34'),
            tr('about_hist_35'),
          ], grey, icon: Icons.system_update_alt),
          Card(
            child: ListTile(
              leading: const Icon(Icons.code, size: 22),
              title: Text(tr('about_github')),
              subtitle: const Text('wangtao969/ordnance'),
              onTap: () async {
                final ok = await openSystemUrl(
                    'https://github.com/wangtao969/ordnance');
                if (!ok && context.mounted) {
                  showAppToast(context, tr('browser_open_failed'));
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
