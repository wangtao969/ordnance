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
import 'weather_screen.dart';
import 'sensor_screen.dart';
import 'ballistic_profile_screen.dart';
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
          Text(tr('tools_note'),
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
                    Text(tr('tools_units_title'),
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const Spacer(),
                    Text(tr('tools_unit_imperial'),
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
                    Text(tr('tools_unit_metric'),
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
            title: tr('acc_catalog_title'),
            subtitle: tr('tools_acc_sub'),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AccessoriesScreen()),
            ),
          ),
          _ToolTile(
            icon: Icons.science_outlined,
            title: tr('tools_reload_title'),
            subtitle: tr('tools_reload_sub'),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ReloadingScreen()),
            ),
          ),
          _ToolTile(
            icon: Icons.inventory_outlined,
            title: tr('tools_ammo_title'),
            subtitle: tr('tools_ammo_sub'),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const AmmoInventoryScreen()),
            ),
          ),
          _ToolTile(
            icon: Icons.cleaning_services_outlined,
            title: tr('tools_maint_title'),
            subtitle: tr('tools_maint_sub'),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MaintenanceScreen()),
            ),
          ),
          _ToolTile(
            icon: Icons.calculate_outlined,
            title: tr('tools_load_title'),
            subtitle: tr('tools_load_sub'),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const LoadToolsScreen()),
            ),
          ),
          _ToolTile(
            icon: Icons.gps_fixed,
            title: tr('tools_range_title'),
            subtitle: tr('tools_range_sub'),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const RangeToolsScreen()),
            ),
          ),
          _ToolTile(
            icon: Icons.book_outlined,
            title: tr('tool_dope'),
            subtitle: tr('tools_dope_sub'),
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
            title: tr('tools_cost_title'),
            subtitle: tr('tools_cost_sub'),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ReloadCostScreen()),
            ),
          ),
          _ToolTile(
            icon: Icons.wb_cloudy_outlined,
            title: tr('weather'),
            subtitle: tr('weather_sub'),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const WeatherScreen()),
            ),
          ),
          _ToolTile(
            icon: Icons.explore_outlined,
            title: tr('sensors'),
            subtitle: tr('sensors_sub'),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SensorScreen()),
            ),
          ),
          _ToolTile(
            icon: Icons.timeline_outlined,
            title: tr('ballistic_profile'),
            subtitle: tr('ballistic_sub'),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const BallisticProfileScreen()),
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
