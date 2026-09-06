import 'dart:async';

import 'package:flutter/foundation.dart';

import 'services/engine.dart';

class AppState extends ChangeNotifier {
  AppState({EngineClient? engine}) : engine = engine ?? EngineClient();

  final EngineClient engine;
  final ValueNotifier<int> tabNotifier = ValueNotifier(0);
  final ValueNotifier<String> themeNotifier = ValueNotifier('system');

  int tab = 0;
  bool engineOnline = false;
  String engineMessage = '正在连接 engine…';
  Map<String, dynamic> settings = {};
  Map<String, dynamic> tools = {};
  final List<String> files = [];
  bool enableUvr = false;
  bool enableCorrect = false;
  bool enableTranslate = true;
  String? jobId;
  String jobStatus = '';
  final List<String> logs = [];
  int _cursor = 0;
  Timer? _poll;

  Future<void> bootstrap() async {
    engineOnline = await engine.ensureStarted();
    engineMessage = engineOnline
        ? 'engine 已连接'
        : '${engine.startupError ?? '未能启动 engine'}，请手动运行 python engine/server.py';
    if (engineOnline) {
      await reload();
    }
    notifyListeners();
  }

  Future<void> reload() async {
    settings = await engine.settings();
    themeNotifier.value = _themeValue(settings['theme']);
    try {
      tools = await engine.tools();
    } catch (e) {
      tools = {};
      engineMessage = '工具检测失败：$e';
    }
    final flags = (settings['flags'] as Map?) ?? {};
    enableUvr = flags['enable_uvr'] == true;
    enableCorrect = flags['enable_correct'] == true;
    enableTranslate = flags['enable_translate'] != false;
    notifyListeners();
  }

  Future<void> refreshTools() async {
    tools = await engine.tools();
    notifyListeners();
  }

  void selectTab(int index) {
    tab = index;
    tabNotifier.value = index;
    notifyListeners();
  }

  void addFiles(Iterable<String> paths) {
    for (final path in paths) {
      if (path.isNotEmpty && !files.contains(path)) files.add(path);
    }
    notifyListeners();
  }

  void removeFile(String path) {
    files.remove(path);
    notifyListeners();
  }

  void clearFiles() {
    files.clear();
    notifyListeners();
  }

  Future<void> persistFlags() async {
    final next = Map<String, dynamic>.from(settings);
    next['flags'] = {
      'enable_uvr': enableUvr,
      'enable_correct': enableCorrect,
      'enable_translate': enableTranslate,
    };
    settings = await engine.saveSettings(next);
    notifyListeners();
  }

  void setStageFlag(String name, bool value) {
    if (name == 'uvr') enableUvr = value;
    if (name == 'correct') enableCorrect = value;
    if (name == 'translate') enableTranslate = value;
    notifyListeners();
    unawaited(persistFlags());
  }

  Future<void> persistSettings(Map<String, dynamic> next) async {
    settings = await engine.saveSettings(next);
    themeNotifier.value = _themeValue(settings['theme']);
    notifyListeners();
  }

  void previewTheme(String value) {
    themeNotifier.value = _themeValue(value);
  }

  String _themeValue(Object? value) {
    final theme = value?.toString();
    return const {'system', 'light', 'dark'}.contains(theme)
        ? theme!
        : 'system';
  }

  Future<void> restartEngine() async {
    engineOnline = false;
    notifyListeners();
    engineOnline = await engine.restart();
    if (engineOnline) await reload();
    engineMessage = engineOnline
        ? 'engine 已连接'
        : engine.startupError ?? '未能启动 engine';
    notifyListeners();
  }

  Future<void> startJob() async {
    if (files.isEmpty) {
      engineMessage = '请先添加文件';
      notifyListeners();
      return;
    }
    logs.clear();
    _cursor = 0;
    final created = await engine.createJob(
      files: List.of(files),
      enableUvr: enableUvr,
      enableCorrect: enableCorrect,
      enableTranslate: enableTranslate,
    );
    jobId = created['job_id'] as String?;
    jobStatus = created['status'] as String? ?? 'running';
    engineMessage = '任务已开始';
    notifyListeners();
    _poll?.cancel();
    _poll = Timer.periodic(const Duration(milliseconds: 800), (_) => _tick());
  }

  Future<void> cancelJob() async {
    final id = jobId;
    if (id == null) return;
    await engine.cancel(id);
  }

  Future<void> _tick() async {
    final id = jobId;
    if (id == null) return;
    try {
      final payload = await engine.events(id, _cursor);
      final events = (payload['events'] as List?) ?? [];
      _cursor = payload['cursor'] as int? ?? _cursor;
      var changed = events.isNotEmpty;
      for (final item in events) {
        if (item is! Map) continue;
        final type = item['type']?.toString() ?? '';
        final message =
            item['message']?.toString() ?? item['error']?.toString() ?? type;
        final file = item['file']?.toString();
        logs.add(file == null ? message : '$file  $message');
        if (logs.length > 400) logs.removeRange(0, logs.length - 400);
      }
      if (payload['closed'] == true) {
        changed = true;
        _poll?.cancel();
        final job = await engine.job(id);
        jobStatus = job['status']?.toString() ?? 'done';
        engineMessage = '任务结束：$jobStatus';
      }
      if (changed) notifyListeners();
    } catch (e) {
      logs.add('轮询失败: $e');
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _poll?.cancel();
    tabNotifier.dispose();
    themeNotifier.dispose();
    super.dispose();
  }
}
