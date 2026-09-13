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
  bool enableCorrect = false;
  bool enableTranslate = true;
  String? jobId;
  String jobStatus = '';
  String jobSource = '';
  final List<String> logs = [];
  int _cursor = 0;
  Timer? _poll;
  Timer? _remoteJobDiscovery;
  bool _pollInFlight = false;
  bool _remoteJobDiscoveryInFlight = false;

  bool get hasActiveJob {
    final id = jobId;
    if (id == null || id.isEmpty) return false;
    return !const {
      'done',
      'completed',
      'failed',
      'cancelled',
    }.contains(jobStatus);
  }

  Future<void> bootstrap() async {
    engineOnline = await engine.ensureStarted();
    engineMessage = engineOnline
        ? 'engine 已连接'
        : '${engine.startupError ?? '未能启动 engine'}，请手动运行 python engine/server.py';
    if (engineOnline) {
      await reload();
      _startRemoteJobDiscovery();
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
      'enable_correct': enableCorrect,
      'enable_translate': enableTranslate,
    };
    settings = await engine.saveSettings(next);
    notifyListeners();
  }

  void setStageFlag(String name, bool value) {
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
    if (engineOnline) {
      await reload();
      _startRemoteJobDiscovery();
    }
    engineMessage = engineOnline
        ? 'engine 已连接'
        : engine.startupError ?? '未能启动 engine';
    notifyListeners();
  }

  Future<void> shutdownEngine() async {
    _poll?.cancel();
    _poll = null;
    _remoteJobDiscovery?.cancel();
    _remoteJobDiscovery = null;
    await engine.shutdown();
    engineOnline = false;
  }

  Future<void> forceShutdownEngine() async {
    _poll?.cancel();
    _poll = null;
    _remoteJobDiscovery?.cancel();
    _remoteJobDiscovery = null;
    await engine.forceShutdown();
    engineOnline = false;
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
      enableCorrect: enableCorrect,
      enableTranslate: enableTranslate,
    );
    jobId = created['job_id'] as String?;
    jobStatus = created['status'] as String? ?? 'running';
    jobSource = created['source']?.toString() ?? 'desktop';
    engineMessage = '任务已开始';
    notifyListeners();
    _poll?.cancel();
    _poll = Timer.periodic(const Duration(milliseconds: 800), (_) => _tick());
  }

  Future<void> cancelJob() async {
    final id = jobId;
    if (id == null || !hasActiveJob) return;
    await engine.cancel(id);
    jobStatus = 'cancelling';
    engineMessage = '正在停止任务…';
    _appendLog('已请求停止任务，正在等待当前阶段结束');
    notifyListeners();
  }

  Future<void> _tick() async {
    final id = jobId;
    if (id == null || _pollInFlight) return;
    _pollInFlight = true;
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
        _appendLog(file == null ? message : '$file  $message');
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
      if (e is TimeoutException) {
        _appendLog('等待 engine 事件超时，将继续轮询');
      } else {
        _appendLog('轮询失败: $e');
      }
      notifyListeners();
    } finally {
      _pollInFlight = false;
    }
  }

  void _startRemoteJobDiscovery() {
    _remoteJobDiscovery?.cancel();
    _remoteJobDiscovery = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _discoverKikoetaJob(),
    );
    unawaited(_discoverKikoetaJob());
  }

  Future<void> _discoverKikoetaJob() async {
    if (!engineOnline ||
        _remoteJobDiscoveryInFlight ||
        (hasActiveJob && jobSource != 'kikoeta')) {
      return;
    }
    _remoteJobDiscoveryInFlight = true;
    try {
      final jobs = await engine.jobs();
      final candidates = jobs.reversed.where(
        (job) =>
            job['source'] == 'kikoeta' &&
            const {'queued', 'running', 'cancelling'}.contains(job['status']),
      );
      if (candidates.isEmpty) return;
      final job = candidates.first;
      final id = job['job_id']?.toString() ?? '';
      if (id.isEmpty || id == jobId) return;

      _poll?.cancel();
      logs.clear();
      _cursor = 0;
      jobId = id;
      jobStatus = job['status']?.toString() ?? 'queued';
      jobSource = 'kikoeta';
      engineMessage = '正在显示由 kikoeta 发起的任务日志';
      _poll = Timer.periodic(const Duration(milliseconds: 800), (_) => _tick());
      notifyListeners();
      unawaited(_tick());
    } catch (_) {
      // The next discovery cycle retries after temporary local-engine errors.
    } finally {
      _remoteJobDiscoveryInFlight = false;
    }
  }

  void _appendLog(String message) {
    final now = DateTime.now();
    String twoDigits(int value) => value.toString().padLeft(2, '0');
    final timestamp =
        '${now.year.toString().padLeft(4, '0')}-${twoDigits(now.month)}-'
        '${twoDigits(now.day)} ${twoDigits(now.hour)}:${twoDigits(now.minute)}:'
        '${twoDigits(now.second)}';
    logs.add('[$timestamp] $message');
    if (logs.length > 400) logs.removeRange(0, logs.length - 400);
  }

  @override
  void dispose() {
    _poll?.cancel();
    _remoteJobDiscovery?.cancel();
    unawaited(engine.shutdown());
    tabNotifier.dispose();
    themeNotifier.dispose();
    super.dispose();
  }
}
