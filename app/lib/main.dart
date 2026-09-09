import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'app_state.dart';
import 'pages/dict_page.dart';
import 'pages/models_page.dart';
import 'pages/model_params_page.dart';
import 'pages/output_page.dart';
import 'pages/params_page.dart';
import 'pages/settings_page.dart';
import 'pages/task_page.dart';
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

class _KtAppState extends State<KtApp> with WindowListener {
  bool _closing = false;
  bool _closePromptOpen = false;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
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
    // Remove the UI first. Flutter/plugin disposal and network futures are not
    // part of the user-visible close path anymore.
    try {
      await windowManager.hide().timeout(const Duration(milliseconds: 150));
    } catch (_) {}

    // Give process-tree termination a small, fixed budget, then end the
    // desktop process unconditionally. The engine watchdog remains a fallback
    // for an engine instance that was not started by this client.
    try {
      await appState
          .forceShutdownEngine()
          .timeout(const Duration(milliseconds: 750));
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
        theme: buildTheme(Brightness.light),
        darkTheme: buildTheme(Brightness.dark),
        themeMode: _themeMode(appState.themeNotifier.value),
        themeAnimationDuration: const Duration(milliseconds: 220),
        themeAnimationCurve: Curves.easeOutCubic,
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
                  selectedIndex: appState.tab,
                  onDestinationSelected: appState.selectTab,
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
