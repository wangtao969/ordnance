import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_icon.dart';
import 'gun_cabinet_data.dart';
import 'theme_accent.dart';
import 'community_store.dart';
import 'haptics.dart';
import 'i18n.dart';
import 'screens/catalog_screen.dart';
import 'screens/community_compose_screen.dart';
import 'screens/community_screen.dart';
import 'screens/my_screen.dart';
import 'screens/tools_screen.dart';
import 'widgets/app_toast.dart';
import 'widgets/liquid_glass_nav.dart';
import 'widgets/page_transitions.dart';

/// 主题选择状态：设置页写入，MaterialApp 监听切换。
/// 仅本次打开期间生效，不做持久化。
final ValueNotifier<ThemeMode> themeModeNotifier =
    ValueNotifier(ThemeMode.system);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 先从本机读回社区数据（带超时兜底，不阻塞启动太久），再进首页。
  await communityStore.init();
  // 2.2.5 枪柜迁移：旧收藏的拥有枪幂等迁入枪柜自有存储（有标记则跳过，
  // 失败不阻塞启动，下次再试；旧收藏数据原样保留）。
  await migrateCabinetFromCollection();
  // 启动图标：固定黑底色，冷启动应用一次；不再跟随主题或平台亮度变化。
  await syncAppIcon();
  // 主题强调色：读回上次选择，读不到则默认铜色。
  await loadAccent();
  runApp(const FirearmsApp());
}

/// 白天米白、夜晚纯黑（OLED：大面积像素不发光，更省电），跟随系统自动切换。
class FirearmsApp extends StatelessWidget {
  const FirearmsApp({super.key});

  static const _paper = Color(0xFFF7F2E9);
  static const _ink = Color(0xFF2E2A24);
  static const _night = Color(0xFF000000);
  static const _nightCard = Color(0xFF0D0D0D);
  static const _nightInk = Color(0xFFEDE8DF);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeModeNotifier,
      builder: (_, mode, __) => ValueListenableBuilder<String>(
        valueListenable: localeNotifier,
        builder: (_, ___, ____) => ValueListenableBuilder<Color>(
        valueListenable: accentNotifier,
        builder: (_, accent, _____) => MaterialApp(
        title: "Ordnance",
        themeMode: mode,
      theme: ThemeData.light().copyWith(
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: <TargetPlatform, PageTransitionsBuilder>{
            TargetPlatform.android:
                SlideFadePageTransitionsBuilder(),
            TargetPlatform.iOS: SlideFadePageTransitionsBuilder(),
            TargetPlatform.macOS: SlideFadePageTransitionsBuilder(),
            TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
            TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
            TargetPlatform.fuchsia: FadeUpwardsPageTransitionsBuilder(),
          },
        ),
        colorScheme: ColorScheme.light(
          primary: accent,
          secondary: const Color(0xFF8C7A5A),
        ),
        scaffoldBackgroundColor: _paper,
        cardColor: Colors.white,
        // 全局输入框样式：圆角 12、浅底、聚焦铜色边框；
        // 未显式写 border 的输入框走这里，显式写了方形边框的下面批量改圆角。
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  BorderSide(color: Colors.grey.withValues(alpha: 0.35))),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                  color: Color(0xFFE86A1C), width: 1.5)),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: _paper,
          foregroundColor: _ink,
          elevation: 0,
          scrolledUnderElevation: 0,
          systemOverlayStyle: SystemUiOverlayStyle.dark,
        ),
        textTheme: ThemeData.light().textTheme.apply(
              bodyColor: _ink,
              displayColor: _ink,
              fontFamily: 'Manrope',
            ),
      ),
      darkTheme: ThemeData.dark().copyWith(
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: <TargetPlatform, PageTransitionsBuilder>{
            TargetPlatform.android:
                SlideFadePageTransitionsBuilder(),
            TargetPlatform.iOS: SlideFadePageTransitionsBuilder(),
            TargetPlatform.macOS: SlideFadePageTransitionsBuilder(),
            TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
            TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
            TargetPlatform.fuchsia: FadeUpwardsPageTransitionsBuilder(),
          },
        ),
        colorScheme: ColorScheme.dark(
          primary: lightenedAccent(accent),
          secondary: const Color(0xFF8C7A5A),
          surface: Colors.black,
        ),
        scaffoldBackgroundColor: _night,
        canvasColor: Colors.black,
        dialogTheme: const DialogThemeData(backgroundColor: _nightCard),
        cardColor: _nightCard,
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: _nightCard,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  BorderSide(color: Colors.grey.withValues(alpha: 0.35))),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                  color: Color(0xFFE86A1C), width: 1.5)),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: _night,
          foregroundColor: _nightInk,
          elevation: 0,
          scrolledUnderElevation: 0,
          systemOverlayStyle: SystemUiOverlayStyle.light,
        ),
        textTheme: ThemeData.dark().textTheme.apply(
              bodyColor: _nightInk,
              displayColor: _nightInk,
              fontFamily: 'Manrope',
            ),
        ),
        home: HomePage(),
        ),
      ),
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _index = 0;

  /// 中间＋号发布（第 11 项）：未登录先提示登录，否则进发布页。
  void _openComposer() {
    if (communityStore.current == null) {
      showAppToast(context, tr('login_required_body'));
      return;
    }
    tapHaptic();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CommunityComposeScreen()),
    );
  }

  static const _tabs = [
    (Icons.grid_view_rounded, Icons.grid_view_rounded, 'tab_catalog'),
    (Icons.forum_outlined, Icons.forum_rounded, 'tab_community'),
    (Icons.handyman_outlined, Icons.handyman_rounded, 'tab_tools'),
    (Icons.person_outlined, Icons.person_rounded, 'tab_mine'),
  ];

  @override
  Widget build(BuildContext context) {
    // 状态栏底色跟随主题背景不透明，内容滑到顶部时不再透出变色。
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    // 页面每次构建时新建实例（不用 const），语言切换时当前页才能重译；
    // 元素复用保证 State 不丢，社区当次数据不会因切语言清空。
    final pages = [
      CatalogScreen(),
      CommunityScreen(),
      ToolsScreen(),
      MyScreen(),
    ];
    // 语言切换时重建导航（含底部 Tab 文案）；各页内部另有自己的语言监听。
    return ValueListenableBuilder<String>(
      valueListenable: localeNotifier,
      builder: (_, __, ___) => AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: theme.scaffoldBackgroundColor,
        statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
        systemNavigationBarColor: theme.scaffoldBackgroundColor,
        systemNavigationBarIconBrightness:
            dark ? Brightness.light : Brightness.dark,
      ),
      child: Scaffold(
        extendBody: true,
        // 输入法弹起时主壳不收缩：底部悬浮导航钉在屏幕底部，
        // 不再跟键盘一起上移；各子页有自己的 Scaffold，底部输入条不受影响。
        resizeToAvoidBottomInset: false,
        // 导航栏不再占底部槽位：以悬浮层盖在页面之上，
        // 各页内容从玻璃栏下面滑过，不再被顶出整整一个底部。
        body: Stack(
          children: [
            // 底部 Tab 切换只淡入：上下滑动会让页面一震一震像 bug，已去掉。
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeIn,
              transitionBuilder: (child, anim) =>
                  FadeTransition(opacity: anim, child: child),
              child: KeyedSubtree(
                key: ValueKey(_index),
                child: pages[_index],
              ),
            ),
            Positioned(
              left: 24,
              right: 24,
              bottom: 0,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 18),
                  child: _FloatingNavBar(
                    index: _index,
                    onTap: (i) {
                      tapHaptic();
                      setState(() => _index = i);
                    },
                    onCompose: _openComposer,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}

/// iOS 风格半透明悬浮药丸导航：不贴底、不撑满宽度，毛玻璃 + 柔和阴影。
/// 颜色跟随主题：白天白底半透明，夜晚深底半透明。
class _FloatingNavBar extends StatelessWidget {
  final int index;
  final ValueChanged<int> onTap;
  final VoidCallback onCompose;
  const _FloatingNavBar(
      {required this.index, required this.onTap, required this.onCompose});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return ClipRRect(
          borderRadius: BorderRadius.circular(34),
          // 底改走 v2 真折射：着色器采样条后实时画面做边缘折射；
          // 加载失败或不支持的设备自动退回 blur 40 毛玻璃。
          // 2.2.5 加重：veil tint 0.16、fallback blur 40、药丸底色
          // 不透明度上调，白天夜晚都比原来实、比原来糊；仍是
          // 毛玻璃 + 折射，不改成实心不透明条，布局与图标不动。
          child: LiquidGlassBackdrop(
            radius: 34,
            tint: 0.16,
            fallbackSigma: 40,
            child: Stack(
              children: [
                Container(
                  height: 68,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: dark
                          ? [
                              const Color(0xFF000000).withValues(alpha: 0.78),
                              const Color(0xFF0D0D0D).withValues(alpha: 0.60),
                            ]
                          : [
                              Colors.white.withValues(alpha: 0.75),
                              Colors.white.withValues(alpha: 0.55),
                            ],
                    ),
                    borderRadius: BorderRadius.circular(34),
                    border: Border.all(
                      color: dark
                          ? Colors.white.withValues(alpha: 0.28)
                          : Colors.white.withValues(alpha: 0.75),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.14),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  // 5 槽：图鉴 / 社区 / 中间＋号（栏内居中方形按钮，
                  // 方形底 + 十字，不用圆形）/ 工具 / 我的；槽位与页下标
                  // 的映射：0、1、3、4。
                  child: Row(
                    children: [
                      for (var slot = 0; slot < 5; slot++)
                        if (slot == 2)
                          SizedBox(
                            width: 56,
                            child: Center(
                              child: GestureDetector(
                                onTap: onCompose,
                                behavior: HitTestBehavior.opaque,
                                child: Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE86A1C),
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black
                                            .withValues(alpha: 0.25),
                                        blurRadius: 12,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(Icons.add,
                                      color: Colors.white, size: 30),
                                ),
                              ),
                            ),
                          )
                        else
                          Expanded(child: _NavItem(
                            icon: _HomePageState
                                ._tabs[slot < 2 ? slot : slot - 1].$1,
                            activeIcon: _HomePageState
                                ._tabs[slot < 2 ? slot : slot - 1].$2,
                            selected: index == (slot < 2 ? slot : slot - 1),
                            onTap: () =>
                                onTap(slot < 2 ? slot : slot - 1),
                          )),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
  }
}

/// 底部导航项：只显示图标，不显示文字；选中态为铜色药丸。
class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final bool selected;
  final VoidCallback onTap;
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final grey = dark ? const Color(0xFF8A8578) : const Color(0xFF9A917F);
    return ValueListenableBuilder<Color>(
      valueListenable: accentNotifier,
      builder: (_, accent, __) {
        final pill = dark ? lightenedAccent(accent) : accent;
        return GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
              decoration: BoxDecoration(
                color: selected ? pill : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                selected ? activeIcon : icon,
                size: 26,
                color: selected
                    ? (dark ? const Color(0xFF000000) : Colors.white)
                    : grey,
              ),
            ),
          ),
        );
      },
    );
  }
}
