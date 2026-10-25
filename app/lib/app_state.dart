import 'dart:async';

import 'package:flutter/foundation.dart';

import 'services/engine.dart';

class AppState extends ChangeNotifier {
  AppState({EngineClient? engine}) : engine = engine ?? EngineClient();

  final EngineClient engine;
  final ValueNotifier<int> tabNotifier = ValueNotifier(0);
  final ValueNotifier<String> themeNotifier = ValueNotifier('system');
  final Map<int, Future<void> Function()> _pageSavers = {};
  Future<void> _settingsWrite = Future<void>.value();
  int _settingsRevision = 0;
  bool _switchingTab = false;

  int tab = 0;
  bool engineOnline = false;
  String engineMessage = '正在连接 engine…';
  Map<String, dynamic> settings = {};
  Map<String, dynamic> tools = {};
  final List<String> files = [];
  bool enableCorrect = true;
  bool enableTranslate = true;
  String? jobId;
  String jobStatus = '';
  String jobSource = '';
  final List<String> logs = [];
  int _cursor = 0;
  Timer? _poll;
  Timer? _remoteJobDiscovery;
  int _pollRevision = 0;
  bool _pollInFlight = false;
  bool _remoteJobDiscoveryInFlight = false;
  bool _submittingJob = false;

  bool get submittingJob => _submittingJob;

  bool get hasActiveJob {
    if (_submittingJob) return true;
    final id = jobId;
    if (id == null || id.isEmpty) return false;
    return !const {
      'done',
      'completed',
      'failed',
      'cancelled',
      'paused',
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
    final revision = _settingsRevision;
    final loadedSettings = await engine.settings();
    if (revision == _settingsRevision) settings = loadedSettings;
    themeNotifier.value = _themeValue(settings['theme']);
    try {
      tools = await engine.tools();
    } catch (e) {
      tools = {};
      engineMessage = '工具检测失败：$e';
    }
    final flags = (settings['flags'] as Map?) ?? {};
    enableCorrect = flags['enable_correct'] != false;
    enableTranslate = flags['enable_translate'] != false;
    notifyListeners();
  }

  Future<void> refreshTools() async {
    tools = await engine.tools();
    notifyListeners();
  }

  VoidCallback registerPageSaver(int index, Future<void> Function() save) {
    _pageSavers[index] = save;
    return () {
      if (identical(_pageSavers[index], save)) _pageSavers.remove(index);
    };
  }

  Future<void> flushSettings() async {
    await _pageSavers[tab]?.call();
    await _settingsWrite;
  }

  Future<void> selectTab(int index) async {
    if (index == tab || _switchingTab) return;
    _switchingTab = true;
    try {
      await flushSettings();
    } finally {
      _switchingTab = false;
    }
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
    await updateSettings((next) {
      next['flags'] = {
        'enable_correct': enableCorrect,
        'enable_translate': enableTranslate,
      };
    });
  }

  void setStageFlag(String name, bool value) {
    if (name == 'correct') enableCorrect = value;
    if (name == 'translate') enableTranslate = value;
    notifyListeners();
    unawaited(persistFlags());
  }

  Future<void> updateSettings(void Function(Map<String, dynamic>) update) {
    final pending = _settingsWrite.onError((_, _) {}).then((_) async {
      final next = Map<String, dynamic>.from(settings);
      update(next);
      _settingsRevision++;
      settings = await engine.saveSettings(next);
      _settingsRevision++;
      themeNotifier.value = _themeValue(settings['theme']);
      notifyListeners();
    });
    _settingsWrite = pending;
    return pending;
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
    _pollRevision++;
    _poll?.cancel();
    _poll = null;
    _remoteJobDiscovery?.cancel();
    _remoteJobDiscovery = null;
    await engine.forceShutdown();
    engineOnline = false;
  }

  Future<void> startJob() async {
    if (hasActiveJob) return;
    if (files.isEmpty) {
      engineMessage = '请先添加文件';
      notifyListeners();
      return;
    }
    _submittingJob = true;
    notifyListeners();
    try {
      final created = await engine.createJob(
        files: List.of(files),
        enableCorrect: enableCorrect,
        enableTranslate: enableTranslate,
      );
      logs.clear();
      _cursor = (created['event_cursor'] as num?)?.toInt() ?? 0;
      jobId = created['job_id'] as String?;
      jobStatus = created['status'] as String? ?? 'running';
      jobSource = created['source']?.toString() ?? 'desktop';
      engineMessage = '任务已开始';
      _restartPolling();
    } catch (error) {
      engineMessage = '提交任务失败：$error';
    } finally {
      _submittingJob = false;
      notifyListeners();
    }
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
    final revision = _pollRevision;
    if (id == null || _pollInFlight) return;
    _pollInFlight = true;
    try {
      final payload = await engine.events(id, _cursor);
      if (revision != _pollRevision) return;
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
        if (revision != _pollRevision) return;
        jobStatus = job['status']?.toString() ?? 'done';
        engineMessage = jobStatus == 'paused' ? '任务已暂存' : '任务结束：$jobStatus';
      }
      if (changed) notifyListeners();
    } catch (e) {
      if (revision != _pollRevision) return;
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

  void _restartPolling() {
    _poll?.cancel();
    _pollRevision++;
    _poll = Timer.periodic(const Duration(milliseconds: 800), (_) => _tick());
    unawaited(_tick());
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
            const {
              'queued',
              'running',
              'pausing',
              'cancelling',
            }.contains(job['status']),
      );
      if (candidates.isEmpty) return;
      final job = candidates.first;
      final id = job['job_id']?.toString() ?? '';
      if (id.isEmpty) return;
      if (id == jobId) {
        final status = job['status']?.toString() ?? jobStatus;
        final changed = status != jobStatus;
        final restart = _poll?.isActive != true;
        jobStatus = status;
        if (restart) {
          engineMessage = '任务继续处理中';
          _restartPolling();
        }
        if (changed || restart) notifyListeners();
        return;
      }

      _poll?.cancel();
      logs.clear();
      _cursor = 0;
      jobId = id;
      jobStatus = job['status']?.toString() ?? 'queued';
      jobSource = 'kikoeta';
      engineMessage = '正在显示由 kikoeta 发起的任务日志';
      _restartPolling();
      notifyListeners();
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
  }

  @override
  void dispose() {
    _pollRevision++;
    _poll?.cancel();
    _remoteJobDiscovery?.cancel();
    unawaited(engine.shutdown());
    tabNotifier.dispose();
    themeNotifier.dispose();
    super.dispose();
  }
}
