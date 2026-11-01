import 'package:flutter/material.dart';
import '../i18n.dart';
import '../theme_accent.dart';
import '../tools_units.dart';
import '../widgets/app_top_bar.dart';
import 'accessories_screen.dart';
import 'ammo_inventory_screen.dart';
import 'chrono_screen.dart';
import 'learn_screen.dart';
import 'load_tools_screen.dart';
import 'maintenance_screen.dart';
import 'range_tools_screen.dart';
import 'range_trip_screen.dart';
import 'reload_cost_screen.dart';
import 'gun_picker_dialog.dart';
import 'dope_screen.dart';
import 'reloading_screen.dart';

/// 工具 Tab：底部 Tab = 工具，板块 = 讨论，分工定死。
/// 配件目录、复装手册是已有页面的入口；
/// 装药工具只做单位换算与用户输入的动能/后坐力计算，不查手册、不推算装药；
/// 两枪参数对比只对照纸面参数，不画弹道曲线（初速与弹道系数未收录）。
class ToolsScreen extends StatefulWidget {
  const ToolsScreen({super.key});

  @override
  State<ToolsScreen> createState() => _ToolsScreenState();
}

class _ToolsScreenState extends State<ToolsScreen> {
  @override
  void initState() {
    super.initState();
    loadUnitSystem();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: const OrdnanceAppBar(),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
            16, MediaQuery.of(context).padding.top + kToolbarHeight + 16, 16, 110),
        children: [
          const Text('查数据、算单位、对照参数都在这里；讨论请去社区板块。',
              style: TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 16),
          // 单位制选择：精简成一行小开关（左英制、右公制），
          // 切换行为与存储 key（tools_units_v1）不动，各工具的单位跟随逻辑不动。
          Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: ValueListenableBuilder<String>(
                valueListenable: unitSystemNotifier,
                builder: (_, system, __) => Row(
                  children: [
                    const Icon(Icons.straighten_outlined,
                        color: Color(0xFF8C6A2F), size: 20),
                    const SizedBox(width: 8),
                    const Text('单位制',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const Spacer(),
                    Text('英制',
                        style: TextStyle(
                            color: system == 'imperial'
                                ? null
                                : Colors.grey,
                            fontSize: 13)),
                    Transform.scale(
                      scale: 0.8,
                      child: ValueListenableBuilder<Color>(
                        valueListenable: accentNotifier,
                        builder: (_, accent, __) => Switch(
                          value: system == 'metric',
                          activeThumbColor: accent,
                          onChanged: (v) =>
                              saveUnitSystem(v ? 'metric' : 'imperial'),
                        ),
                      ),
                    ),
                    Text('公制',
                        style: TextStyle(
                            color:
                                system == 'metric' ? null : Colors.grey,
                            fontSize: 13)),
                  ],
                ),
              ),
            ),
          ),
          _ToolTile(
            icon: Icons.handyman_outlined,
            title: '配件目录',
            subtitle: '按品类筛选的知名厂商配件',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AccessoriesScreen()),
            ),
          ),
          _ToolTile(
            icon: Icons.science_outlined,
            title: '复装手册',
            subtitle: '口径图鉴、装药表、供应商与 SOP（只收录手册原文）',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ReloadingScreen()),
            ),
          ),
          _ToolTile(
            icon: Icons.inventory_outlined,
            title: '弹药库存',
            subtitle: '只记手头现存发数，不用登录，数据只存本机',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const AmmoInventoryScreen()),
            ),
          ),
          _ToolTile(
            icon: Icons.cleaning_services_outlined,
            title: '保养记录',
            subtitle: '清洁与换件记录，记枪名、日期与当时已打发数',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MaintenanceScreen()),
            ),
          ),
          _ToolTile(
            icon: Icons.calculate_outlined,
            title: '装药工具',
            subtitle: '单位换算、枪口动能、后坐力（只算你输入的数，不给装药建议）',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const LoadToolsScreen()),
            ),
          ),
          _ToolTile(
            icon: Icons.gps_fixed,
            title: '靶场换算',
            subtitle: '散布换算 MOA/密位与速查表，只算你输入的数；归零调瞄去 DOPE数据本',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const RangeToolsScreen()),
            ),
          ),
          _ToolTile(
            icon: Icons.book_outlined,
            title: 'DOPE数据本',
            subtitle: '归零助手 + 每把枪的归零卡、分组趋势与常用弹药，先选枪再看',
            onTap: () async {
              final gun = await showGunPickerDialog(context);
              if (gun == null || !context.mounted) return;
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => DopeScreen(gun: gun)),
              );
            },
          ),
          _ToolTile(
            icon: Icons.speed_outlined,
            title: tr('tool_chrono'),
            subtitle: tr('tool_chrono_sub'),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ChronoScreen()),
            ),
          ),
          _ToolTile(
            icon: Icons.trip_origin_outlined,
            title: tr('tool_trip'),
            subtitle: tr('tool_trip_sub'),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const RangeTripScreen()),
            ),
          ),
          _ToolTile(
            icon: Icons.school_outlined,
            title: tr('tool_learn'),
            subtitle: tr('tool_learn_sub'),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const LearnScreen()),
            ),
          ),
          _ToolTile(
            icon: Icons.attach_money_outlined,
            title: '复装成本',
            subtitle: '按你输入的组件价格算每发成本，不提供报价、不给装药建议',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ReloadCostScreen()),
            ),
          ),
        ],
      ),
    );
  }
}

class _ToolTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _ToolTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFF8C6A2F)),
        title: Text(title,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
