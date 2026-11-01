import 'package:flutter/material.dart';
import '../community_store.dart';
import '../data.dart';
import '../gun_cabinet_data.dart';
import '../english_terms.dart';
import '../haptics.dart';
import '../i18n.dart';
import '../models.dart';
import '../widgets/category_silhouette.dart';
import '../widgets/app_top_bar.dart';
import 'gun_cabinet_screen.dart';
import '../news_data.dart';
import 'news_screen.dart';
import 'gun_list_screen.dart';
import 'gun_detail_screen.dart';
import 'legend_list_screen.dart';
import '../knife_data.dart';
import 'knife_detail_screen.dart';
import 'knife_list_screen.dart';
import '../weather_api.dart';
import '../tools_units.dart';
import '../sensors_api.dart';
import 'weather_screen.dart';

class CatalogScreen extends StatefulWidget {
  const CatalogScreen({super.key});

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  String _query = '';
  bool _searchExpanded = false;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final grey = dark ? const Color(0xFF8A8578) : const Color(0xFF9A917F);
    final bronze = dark ? const Color(0xFFC9A86A) : const Color(0xFF6B5B3E);
    final ink = dark ? const Color(0xFFEDE8DF) : const Color(0xFF2E2A24);
    final cardBg = dark ? const Color(0xFF0D0D0D) : Colors.white;
    final q = _query.trim().toLowerCase();
    final results = q.isEmpty
        ? <Gun>[]
        : guns
            .where((g) =>
                g.name.toLowerCase().contains(q) ||
                (g.nameEn ?? '').toLowerCase().contains(q) ||
                g.vendor.toLowerCase().contains(q) ||
                g.caliber.toLowerCase().contains(q) ||
                // 第 10 项：品类中英文都要命中。
                categoryMatches(g.category, q))
            .toList();
    // 刀具搜索与枪械搜索并列：搜刀名、英文名、国家、分类都能命中。
    // 今日一枪：按天取固定一把，当天不变、次日换枪。
    final todayGun = guns[
        DateTime.now().difference(DateTime(2020, 1, 1)).inDays % guns.length];
    // 首页枪柜模块：优先读枪柜内存镜像（枪柜页/迁移同步），
    // 尚未加载时回落旧收藏快照（迁移前的冻结数据，统一映射成档案）。
    final myGuns = cabinetProfilesCache ??
        communityStore.current?.collection
            .where((c) => c.kind == 'gun' && c.status == 'owned')
            .map((c) => GunProfile(gunName: c.gunName, rounds: c.rounds))
            .toList() ??
        [];
    final knifeResults = q.isEmpty
        ? <Knife>[]
        : knives
            .where((k) =>
                k.name.toLowerCase().contains(q) ||
                k.nameEn.toLowerCase().contains(q) ||
                k.country.toLowerCase().contains(q) ||
                k.type.toLowerCase().contains(q))
            .toList();
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: const OrdnanceAppBar(),
      body: SafeArea(
        top: true,
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8 + kToolbarHeight, 16, 110),
          children: [
            // 首页细长条天气：不高，横向滚动播报当前位置温度/湿度/
            // 风速风向；点卡片进天气页；搜索时隐藏。
            if (_query.isEmpty) const _HomeWeatherStrip(),
            if (_query.isEmpty) const SizedBox(height: 12),
            // 枪械资讯入口：页头太空，补一条厂商与弹药商资讯快讯；搜索时隐藏。
            if (_query.isEmpty)
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {
                    tapHaptic();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const NewsScreen()),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: bronze,
                          ),
                          child: Icon(Icons.newspaper_outlined,
                              size: 20,
                              color: dark
                                  ? const Color(0xFF000000)
                                  : Colors.white),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(tr('news_title'),
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14)),
                              const SizedBox(height: 2),
                              Text(
                                newsItems.first.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    color: grey, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right, color: grey),
                      ],
                    ),
                  ),
                ),
              ),
            // 今日一枪 + 我的枪柜前置：搜索时隐藏，平时放在资讯卡下方。
            if (_query.isEmpty)
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {
                    tapHaptic();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => GunDetailScreen(gun: todayGun)),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: bronze,
                          ),
                          child: Icon(Icons.calendar_today_outlined,
                              size: 20,
                              color: dark
                                  ? const Color(0xFF000000)
                                  : Colors.white),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(tr('catalog_today'),
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14)),
                              const SizedBox(height: 2),
                              Text(
                                '${gunDisplayName(todayGun)} · ${todayGun.caliber}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    color: grey, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right, color: grey),
                      ],
                    ),
                  ),
                ),
              ),
            if (_query.isEmpty && myGuns.isNotEmpty)
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(tr('cab_title'),
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 14)),
                          const Spacer(),
                          GestureDetector(
                            onTap: () {
                              tapHaptic();
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        const GunCabinetScreen()),
                              );
                            },
                            child: Text(tr('catalog_view_all'),
                                style: TextStyle(color: grey, fontSize: 12)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      for (final c in myGuns.take(3))
                        InkWell(
                          onTap: () {
                            final match = guns.where(
                                (g) => g.name == c.gunName);
                            if (match.isEmpty) return;
                            tapHaptic();
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                      GunDetailScreen(gun: match.first)),
                            );
                          },
                          child: Padding(
                            padding:
                                const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                      // 档案里没有口径，按枪名回查图鉴；查不到只显示枪名。
                                      guns
                                              .where((g) =>
                                                  g.name == c.gunName)
                                              .isEmpty
                                          ? c.gunName
                                          : '${c.gunName} · ${guns.firstWhere((g) => g.name == c.gunName).caliber}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 13)),
                                ),
                                Text(tr('cab_rounds') + ' ${c.rounds} ' + tr('cab_rounds_suffix'),
                                    style: TextStyle(
                                        color: grey, fontSize: 12)),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 12),
            // 搜索：平时只显示一个放大镜圆钮，点开才展开成输入框；
            // 收起时清空搜索，避免看不见的筛选条件留在后台。
            if (!_searchExpanded)
              Row(
                children: [
                  Text(tr('tab_catalog'),
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: ink)),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => setState(() => _searchExpanded = true),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: cardBg,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(Icons.search, color: bronze, size: 22),
                    ),
                  ),
                ],
              )
            else
              // 展开后是无边输入框：不套卡片底与阴影，不带放大镜前缀，
              // 只留提示文字与光标；收起仍用右边圆钮。
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      autofocus: true,
                      // TextField 本身任何状态都不画框：focusedBorder 不写会
                      // 回落全局主题的橙色聚焦边，聚焦时裸输入框里会再冒出
                      // 一个橙色框。
                      decoration: InputDecoration(
                        hintText: tr('search_gun_hint'),
                        hintStyle: TextStyle(color: grey),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        disabledBorder: InputBorder.none,
                        errorBorder: InputBorder.none,
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onChanged: (v) => setState(() => _query = v),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => setState(() {
                      _searchExpanded = false;
                      _query = '';
                    }),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: cardBg,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(Icons.close, color: grey, size: 20),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 12),
            const SizedBox(height: 12),
            const SizedBox(height: 20),
            if (_query.isNotEmpty) ...[
              ...results.map((g) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: ListTile(
                      title: Text(gunDisplayName(g)),
                      subtitle: Text('${vendorDisplay(g.vendor)} · ${g.caliber}'),
                      onTap: () {
                        tapHaptic();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => GunDetailScreen(gun: g)),
                        );
                      },
                    ),
                  )),
              if (knifeResults.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(tr('catalog_knives_label'),
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: ink)),
                const SizedBox(height: 8),
                ...knifeResults.map((k) => Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: ListTile(
                        title: Text(k.nameEn),
                        subtitle: Text(
                            '${countryDisplay(k.country)} · ${knifeTypeDisplay(k.type)}'),
                        onTap: () {
                          tapHaptic();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) =>
                                    KnifeDetailScreen(knife: k)),
                          );
                        },
                      ),
                    )),
              ],
              if (results.isEmpty && knifeResults.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 24),
                  child: Center(
                    child: Text(tr('catalog_search_empty'),
                        style: TextStyle(color: grey)),
                  ),
                ),
            ],
            if (_query.isEmpty) ...[
              Text(tr('gun_categories'),
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: ink)),
              const SizedBox(height: 12),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.95,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: categories.length,
                itemBuilder: (context, i) {
                  final c = categories[i];
                  final count = guns.where((g) => g.category == c).length;
                  return GestureDetector(
                    onTap: () {
                      tapHaptic();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => GunListScreen(category: c)),
                      );
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // 品类图：固定高度 + contain 全枪可见、居中摆放。
                          // cover 会裁掉枪身两端（之前显示不全就是它造成的），
                          // 透明底抠图用 contain 才能保证整枪可见且位置统一。
                          SizedBox(
                            height: 76,
                            width: double.infinity,
                            child: Image.asset(
                              categoryPhoto[c] ??
                                  'assets/images/category-rifle.png',
                              fit: BoxFit.contain,
                              alignment: Alignment.center,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(categoryDisplay(c),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: ink)),
                          const SizedBox(height: 2),
                          Text(countText(count),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: grey, fontSize: 12)),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 6),
              Text(tr('catalog_img_credit'),
                  style: TextStyle(color: grey, fontSize: 11)),
              // 刀具图鉴：枪械品类下方单独的大类入口，不进 categories 列表
              //（该列表驱动枪械网格与计数，混入会串位）。
              const SizedBox(height: 24),
              Text(tr('knife_title'),
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: ink)),
              const SizedBox(height: 4),
              Text(tr('catalog_knives_sub'),
                  style: TextStyle(color: grey, fontSize: 13)),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () {
                  tapHaptic();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const KnifeListScreen()),
                  );
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(tr('catalog_enter_knives'),
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: ink)),
                            const SizedBox(height: 4),
                            Text(
                                '卡巴军刀、M9 刺刀、莫拉伴侣刀……' + tr('catalog_total_prefix') + '${knives.length}' + tr('catalog_total_suffix_knives'),
                                style:
                                    TextStyle(color: grey, fontSize: 13)),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right, color: grey),
                    ],
                  ),
                ),
              ),
              // 停售名枪鉴赏：首页下方的大类入口。
              const SizedBox(height: 24),
              Text(tr('legends'),
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: ink)),
              const SizedBox(height: 4),
              Text(tr('catalog_legends_sub'),
                  style: TextStyle(color: grey, fontSize: 13)),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () {
                  tapHaptic();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const LegendListScreen()),
                  );
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(tr('catalog_enter_legends'),
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: ink)),
                            const SizedBox(height: 4),
                            Text(
                                'M1 加兰德、Kar98k、STG44、汤普森……' + tr('catalog_total_prefix') + '${legends.length}' + tr('catalog_total_suffix_guns'),
                                style:
                                    TextStyle(color: grey, fontSize: 13)),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right, color: grey),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 首页细长条天气卡片：默认只显示一行提示，点按才要定位权限并拉取
/// 当前位置天气（不在首页打开时擅自弹权限）；拉取成功后横向滚动播报
/// 温度/湿度/风速风向，点卡片进天气详情页；失败点按重试。
class _HomeWeatherStrip extends StatefulWidget {
  const _HomeWeatherStrip();

  @override
  State<_HomeWeatherStrip> createState() => _HomeWeatherStripState();
}

class _HomeWeatherStripState extends State<_HomeWeatherStrip> {
  // 第 8 项：存原始数据不存格式化串，显示时按单位偏好换算。
  WeatherData? _w;
  bool _loading = false;
  bool _failed = false;

  String _lineText() {
    final w = _w;
    if (w == null) return '';
    final parts = <String>[];
    if (w.temp != null) parts.add(fmtTemp(w.temp!));
    if (w.humidity != null) parts.add('湿度 ${w.humidity!.toStringAsFixed(0)}%');
    if (w.windSpeed != null) {
      parts.add('风速 ${fmtWind(w.windSpeed!)}'
          '${w.windDir == null ? '' : ' ${compassDir(w.windDir!)}'}');
    }
    if (w.pressure != null) parts.add('气压 ${fmtPressure(w.pressure!)}');
    return parts.join(' · ');
  }

  Future<void> _load() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final ok = await requestLocationPermission();
      if (!mounted) return;
      if (!ok) {
        setState(() => _failed = true);
        return;
      }
      final pos = await getGpsPosition();
      if (!mounted) return;
      if (pos.value == null) {
        setState(() => _failed = true);
        return;
      }
      final w = await fetchWeather(pos.value!.latitude, pos.value!.longitude);
      if (!mounted) return;
      setState(() => _w = w);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF0D0D0D) : Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          if (_w != null) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const WeatherScreen()),
            );
          } else {
            _load();
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              const Icon(Icons.wb_sunny_outlined, size: 18),
              const SizedBox(width: 8),
              if (_loading)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else if (_w != null)
                Expanded(
                  child: ValueListenableBuilder<Map<String, String>>(
                    valueListenable: unitPrefsNotifier,
                    builder: (_, __, ___) => SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Text(_lineText(),
                          style: const TextStyle(fontSize: 13)),
                    ),
                  ),
                )
              else
                Expanded(
                  child: Text(
                    _failed
                        ? tr('home_weather_failed')
                        : tr('home_weather_load'),
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              if (_w != null)
                const Icon(Icons.chevron_right, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
