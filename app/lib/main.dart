import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:tray_manager/tray_manager.dart' as tray;
import 'package:window_manager/window_manager.dart';

import 'app_state.dart';
import 'pages/dict_page.dart';
import 'pages/models_page.dart';
import 'pages/model_params_page.dart';
import 'pages/output_page.dart';
import 'pages/params_page.dart';
import 'pages/recent_page.dart';
import 'pages/settings_page.dart';
import 'pages/task_page.dart';
import 'services/theme_reveal.dart';
import 'theme.dart';
import 'widgets.dart';

final appState = AppState();
final navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();
  await windowManager.setPreventClose(true);
  final options = WindowOptions(
    size: Size(1180, 760),
    minimumSize: Size(900, 600),
    title: 'Kikoeta Transl',
  );
  unawaited(
    windowManager.waitUntilReadyToShow(options, () async {
      await windowManager.show();
      await windowManager.focus();
    }),
  );
  runApp(const KtApp());
  unawaited(appState.bootstrap());
}

class KtApp extends StatefulWidget {
  const KtApp({super.key});

  @override
  State<KtApp> createState() => _KtAppState();
}

class _KtAppState extends State<KtApp>
    with
        WidgetsBindingObserver,
        WindowListener,
        tray.TrayListener,
        SingleTickerProviderStateMixin {
  bool _closing = false;
  bool _closePromptOpen = false;

  /// 圆形揭示时长：覆盖整个窗口的扩散，接近 Android 圆形揭示的观感
  static const Duration _revealDuration = Duration(milliseconds: 450);

  /// 根节点：抓「切换前外观」的截图用
  final GlobalKey _rootKey = GlobalKey();
  late final AnimationController _revealAnim = AnimationController(
    vsync: this,
    duration: _revealDuration,
  );
  late final CurvedAnimation _revealCurve = CurvedAnimation(
    parent: _revealAnim,
    curve: Curves.fastOutSlowIn,
  );
  ui.Image? _revealImage;
  Offset _revealOrigin = Offset.zero;
  int _revealSeq = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    windowManager.addListener(this);
    tray.trayManager.addListener(this);
    _revealAnim.addStatusListener(_onRevealStatus);
    ThemeReveal.instance.bind(_switchThemeWithReveal);
    unawaited(_initTray());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    tray.trayManager.removeListener(this);
    unawaited(tray.trayManager.destroy());
    windowManager.removeListener(this);
    _revealImage?.dispose();
    _revealCurve.dispose();
    _revealAnim.dispose();
    super.dispose();
  }

  /// 跟随系统时，系统深浅色的变化同样从窗口中心扩散
  @override
  void didChangePlatformBrightness() {
    if (appState.themeNotifier.value == 'system') {
      unawaited(_switchThemeWithReveal('system', null));
    }
  }

  /// 切换主题并播放圆形揭示动画。
  ///
  /// 顺序是关键：先抓「切换前」的截图，再让真实界面重建一次换成新主题，
  /// 最后把截图按不断扩大的圆裁掉。因此每帧只多一次贴图绘制，
  /// 没有第二棵控件树、也没有新旧外观同时插值的浑浊感。
  Future<void> _switchThemeWithReveal(
    String theme,
    Offset? globalOrigin,
  ) async {
    final seq = ++_revealSeq;
    // 目标亮度与当前渲染亮度相同（例如深色切到「跟随系统」而系统本就是深色）时无需动画
    if (_targetBrightness(theme) == _renderedBrightness) {
      appState.previewTheme(theme);
      return;
    }
    if (_revealImage != null) {
      // 上一次揭示还没播完：先撤掉贴图并等这一帧落地，避免把它拍进新截图
      _revealAnim.stop();
      _endReveal();
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted || seq != _revealSeq) return;
    }

    final image = await _captureRoot();
    if (!mounted || seq != _revealSeq) {
      image?.dispose(); // 期间又切了一次，交给最后一次
      return;
    }

    final box = _rootKey.currentContext?.findRenderObject() as RenderBox?;
    final origin = box == null || !box.hasSize
        ? Offset.zero
        : globalOrigin == null
        ? box.size.center(Offset.zero) // 设置页 / 跟随系统：窗口中心
        : box.globalToLocal(globalOrigin); // 按钮：按钮中心

    setState(() {
      _revealImage?.dispose();
      _revealImage = image;
      _revealOrigin = origin;
      _revealAnim.value = 0;
    });
    appState.previewTheme(theme); // 真实界面只在这里重建一次
    if (image == null) return; // 截图失败：直接切换，不播放动画
    _revealAnim.forward();
  }

  /// 抓取根节点当前外观（切换前的样子），失败返回 null
  Future<ui.Image?> _captureRoot() async {
    final boundary =
        _rootKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null || boundary.size.isEmpty) return null;
    try {
      // 上限 2.0：再高只是徒增一次读回的内存与耗时
      final ratio = math.min(MediaQuery.devicePixelRatioOf(context), 2.0);
      return await boundary.toImage(pixelRatio: ratio);
    } catch (_) {
      return null;
    }
  }

  void _onRevealStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) _endReveal();
  }

  void _endReveal() {
    final image = _revealImage;
    if (image == null) return;
    setState(() => _revealImage = null);
    image.dispose();
  }

  /// 该主题下应显示的亮度
  Brightness _targetBrightness(String theme) => switch (theme) {
    'light' => Brightness.light,
    'dark' => Brightness.dark,
    _ => WidgetsBinding.instance.platformDispatcher.platformBrightness,
  };

  /// 当前这一帧实际渲染的亮度（跟随系统时以 MaterialApp 读到的平台亮度为准）
  Brightness get _renderedBrightness => switch (appState.themeNotifier.value) {
    'light' => Brightness.light,
    'dark' => Brightness.dark,
    _ => MediaQuery.platformBrightnessOf(context),
  };

  Future<void> _initTray() async {
    try {
      await tray.trayManager.setIcon('windows/runner/resources/app_icon.ico');
      await tray.trayManager.setToolTip('Kikoeta Transl');
      await tray.trayManager.setContextMenu(
        tray.Menu(
          items: [
            tray.MenuItem(key: 'show_window', label: '显示窗口'),
            tray.MenuItem(key: 'stop_task', label: '停止任务'),
            tray.MenuItem.separator(),
            tray.MenuItem(key: 'exit_app', label: '退出'),
          ],
        ),
      );
    } catch (_) {
      // The desktop app remains usable if the system tray is unavailable.
    }
  }

  @override
  void onWindowMinimize() {
    if (_closing) return;
    unawaited(_hideToTray());
  }

  Future<void> _hideToTray() async {
    try {
      await windowManager.hide();
    } catch (_) {}
  }

  Future<void> _showWindow() async {
    try {
      if (await windowManager.isMinimized()) {
        await windowManager.restore();
      }
      await windowManager.show();
      await windowManager.focus();
    } catch (_) {}
  }

  @override
  void onTrayIconMouseDown() {
    unawaited(_showWindow());
  }

  @override
  void onTrayIconRightMouseDown() {
    unawaited(tray.trayManager.popUpContextMenu());
  }

  @override
  void onTrayMenuItemClick(tray.MenuItem menuItem) {
    switch (menuItem.key) {
      case 'show_window':
        unawaited(_showWindow());
        return;
      case 'stop_task':
        unawaited(appState.cancelJob());
        return;
      case 'exit_app':
        if (_closing) return;
        _closing = true;
        unawaited(_terminateApplication());
        return;
    }
  }

  @override
  void onWindowClose() async {
    if (_closing || _closePromptOpen) return;

    if (appState.hasActiveJob) {
      final dialogContext = navigatorKey.currentState?.overlay?.context;
      if (dialogContext == null) return;
      _closePromptOpen = true;
      var confirmed = false;
      try {
        confirmed =
            await showDialog<bool>(
              context: dialogContext,
              barrierDismissible: false,
              builder: (dialogContext) => AlertDialog(
                title: const Text('任务正在运行'),
                content: const Text('关闭窗口将停止当前任务，确定要关闭吗？'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(false),
                    child: const Text('取消'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.of(dialogContext).pop(true),
                    child: const Text('确定关闭'),
                  ),
                ],
              ),
            ) ??
            false;
      } finally {
        _closePromptOpen = false;
      }
      if (confirmed != true || !mounted) return;
    }

    _closing = true;
    await _terminateApplication();
  }

  Future<void> _terminateApplication() async {
    try {
      await appState.flushSettings();
    } catch (error) {
      _closing = false;
      final context = navigatorKey.currentContext;
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('设置保存失败，尚未退出：$error')),
        );
      }
      return;
    }

    try {
      await tray.trayManager.destroy().timeout(
        const Duration(milliseconds: 150),
      );
    } catch (_) {}

    // Remove the UI first. Flutter/plugin disposal and network futures are not
    // part of the user-visible close path anymore.
    try {
      await windowManager.hide().timeout(const Duration(milliseconds: 150));
    } catch (_) {}

    // Give process-tree termination a small, fixed budget, then end the
    // desktop process unconditionally. The engine watchdog remains a fallback
    // for an engine instance that was not started by this client.
    try {
      await appState.forceShutdownEngine().timeout(
        const Duration(milliseconds: 750),
      );
    } catch (_) {}
    exit(0);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appState.themeNotifier,
      builder: (context, _) => MaterialApp(
        navigatorKey: navigatorKey,
        title: 'Kikoeta Transl',
        debugShowCheckedModeBanner: false,
        builder: (context, child) {
          // 整个窗口都在根 RepaintBoundary 里：主题切换的圆形揭示
          // 既要抓它的截图，也要盖住它
          return RepaintBoundary(
            key: _rootKey,
            child: Stack(
              fit: StackFit.expand,
              children: [
                child ?? const SizedBox.shrink(),
                if (_revealImage != null)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: ThemeRevealPainter(
                          image: _revealImage!,
                          origin: _revealOrigin,
                          progress: _revealCurve,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
        theme: buildTheme(Brightness.light),
        darkTheme: buildTheme(Brightness.dark),
        themeMode: _themeMode(appState.themeNotifier.value),
        // 主题切换交给圆形揭示动画，这里必须瞬时生效：否则被圆露出的区域
        // 会同步做颜色插值，圆的边界上会看到新旧混色
        themeAnimationDuration: Duration.zero,
        home: const Shell(),
      ),
    );
  }

  ThemeMode _themeMode(String? value) {
    switch (value) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }
}

class Shell extends StatelessWidget {
  const Shell({super.key});

  void _selectTab(BuildContext context, int index) {
    unawaited(
      appState.selectTab(index).catchError((Object error) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('自动保存失败，已留在当前页面：$error')));
        }
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = paletteOf(context);
    return ListenableBuilder(
      listenable: appState.tabNotifier,
      builder: (context, _) {
        return Scaffold(
          body: Row(
            children: [
              SizedBox(
                width: 88,
                child: NavigationRail(
                  selectedIndex: appState.tab < 7 ? appState.tab : null,
                  onDestinationSelected: (index) => _selectTab(context, index),
                  scrollable: true,
                  trailingAtBottom: true,
                  trailing: Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => _selectTab(context, 7),
                      child: SizedBox(
                        width: 76,
                        height: 62,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              appState.tab == 7
                                  ? Icons.history
                                  : Icons.history_outlined,
                              color: appState.tab == 7 ? p.accent : p.dim,
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '最近',
                              style: TextStyle(
                                color: appState.tab == 7 ? p.accent : p.dim,
                                fontSize: 12,
                                fontWeight: appState.tab == 7
                                    ? FontWeight.w700
                                    : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  backgroundColor: p.surface,
                  indicatorColor: p.accent.withValues(alpha: .14),
                  selectedIconTheme: IconThemeData(color: p.accent),
                  unselectedIconTheme: IconThemeData(color: p.dim),
                  selectedLabelTextStyle: TextStyle(
                    color: p.accent,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                  unselectedLabelTextStyle: TextStyle(
                    color: p.dim,
                    fontSize: 12,
                  ),
                  labelType: NavigationRailLabelType.all,
                  destinations: const [
                    NavigationRailDestination(
                      icon: Icon(Icons.playlist_play_outlined),
                      selectedIcon: Icon(Icons.playlist_play),
                      label: Text('任务'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.memory_outlined),
                      selectedIcon: Icon(Icons.memory),
                      label: Text('模型'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.tune_outlined),
                      selectedIcon: Icon(Icons.tune),
                      label: Text('听写参数'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.tune_outlined),
                      selectedIcon: Icon(Icons.tune),
                      label: Text('模型参数'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.menu_book_outlined),
                      selectedIcon: Icon(Icons.menu_book),
                      label: Text('字典'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.outbox_outlined),
                      selectedIcon: Icon(Icons.outbox),
                      label: Text('输出'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.settings_outlined),
                      selectedIcon: Icon(Icons.settings),
                      label: Text('设置'),
                    ),
                  ],
                ),
              ),
              VerticalDivider(width: 1, thickness: 1, color: p.line),
              Expanded(
                child: ColoredBox(
                  color: p.bg,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
                    child: _AnimatedPageStack(
                      index: appState.tab,
                      children: [
                        TaskPage(app: appState),
                        ModelsPage(app: appState),
                        ParamsPage(app: appState),
                        ModelParamsPage(app: appState),
                        DictPage(app: appState),
                        OutputPage(app: appState),
                        SettingsPage(app: appState),
                        RecentPage(app: appState),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AnimatedPageStack extends StatelessWidget {
  final int index;
  final List<Widget> children;

  const _AnimatedPageStack({required this.index, required this.children});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        for (var childIndex = 0; childIndex < children.length; childIndex++)
          IgnorePointer(
            ignoring: childIndex != index,
            child: AnimatedOpacity(
              opacity: childIndex == index ? 1 : 0,
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              child: AnimatedSlide(
                offset: childIndex == index
                    ? Offset.zero
                    : const Offset(.018, 0),
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                child: RepaintBoundary(child: children[childIndex]),
              ),
            ),
          ),
      ],
    );
  }
}
