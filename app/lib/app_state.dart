import 'dart:async';

import 'package:flutter/foundation.dart';

import 'l10n/strings.dart';
import 'services/completion_action.dart';
import 'services/engine.dart';
import 'l10n/app_language.dart';

class AppState extends ChangeNotifier {
  AppState({EngineClient? engine}) : engine = engine ?? EngineClient();

  static const _successfulJobStatuses = {'done', 'completed'};
  static const _endedJobStatuses = {
    ..._successfulJobStatuses,
    'failed',
    'cancelled',
    'paused',
  };

  final EngineClient engine;
  final ValueNotifier<int> tabNotifier = ValueNotifier(0);
  final ValueNotifier<String> themeNotifier = ValueNotifier('system');
  final ValueNotifier<String> languageNotifier = ValueNotifier(
    AppLanguage.system,
  );
  final Map<int, Future<void> Function()> _pageSavers = {};
  Future<void> _settingsWrite = Future<void>.value();
  int _settingsRevision = 0;
  bool _switchingTab = false;

  int tab = 0;
  bool engineOnline = false;
  String Function() _engineMessage = () => appL10n.engineConnecting;
  String get engineMessage => _engineMessage();
  Map<String, dynamic> settings = {};
  Map<String, dynamic> tools = {};
  final List<String> files = [];
  bool enableCorrect = true;
  bool enableTranslate = true;
  String? jobId;
  String jobStatus = '';
  String jobSource = '';
  List<({String path, String error})> _jobFileFailures = const [];
  bool _jobHasFileOnlyFailure = false;
  int _processedJobFiles = 0;
  int _totalJobFiles = 0;
  double _jobStageProgress = 0;
  final List<String> logs = [];
  int _cursor = 0;
  int _runStartCursor = 0;
  Timer? _poll;
  Timer? _remoteJobDiscovery;
  int _pollRevision = 0;
  bool _pollInFlight = false;
  bool _remoteJobDiscoveryInFlight = false;
  bool _submittingJob = false;
  CompletionAction _completionAction = CompletionAction.none;

  bool get submittingJob => _submittingJob;
  CompletionAction get completionAction => _completionAction;
  List<({String path, String error})> get jobFileFailures => _jobFileFailures;
  String get jobDisplayStatus => jobStatus == 'failed' && _jobHasFileOnlyFailure
      ? 'partially_failed'
      : jobStatus;
  double get jobProgress => _totalJobFiles == 0
      ? 0
      : ((_processedJobFiles + _jobStageProgress) / _totalJobFiles).clamp(
          0.0,
          1.0,
        );

  bool get hasActiveJob {
    if (_submittingJob) return true;
    final id = jobId;
    if (id == null || id.isEmpty) return false;
    return _poll?.isActive == true || !_endedJobStatuses.contains(jobStatus);
  }

  void setCompletionAction(CompletionAction action) {
    if (action == _completionAction) return;
    _completionAction = action;
    notifyListeners();
  }

  Future<void> bootstrap() async {
    engineOnline = await engine.ensureStarted();
    _engineMessage = () => engineOnline
        ? appL10n.engineConnected
        : appL10n.engineStartHelp(
            engine.startupError ?? appL10n.engineStartFailed,
          );
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
    _syncLanguage();
    try {
      tools = await engine.tools();
    } catch (e) {
      tools = {};
      _engineMessage = () => appL10n.toolDetectionFailed(e);
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
    final existing = files.toSet();
    final previousCount = files.length;
    files.addAll(paths.where((path) => path.isNotEmpty && existing.add(path)));
    if (files.length != previousCount) notifyListeners();
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
      _syncLanguage();
      notifyListeners();
    });
    _settingsWrite = pending;
    return pending;
  }

  void previewTheme(String value) {
    themeNotifier.value = _themeValue(value);
  }

  void _syncLanguage() {
    AppLanguage.setPreference(
      settings['ui_language']?.toString() ?? AppLanguage.system,
    );
    languageNotifier.value = AppLanguage.preference;
  }

  Future<void> setUiLanguage(String value) => updateSettings(
    (next) =>
        next['ui_language'] = AppLanguage.selectablePreferences.contains(value)
        ? value
        : AppLanguage.system,
  );

  String _themeValue(Object? value) {
    final theme = value?.toString();
    return const {'system', 'light', 'dark'}.contains(theme)
        ? theme!
        : 'system';
  }

  Future<void> restartEngine() async {
    _pollRevision++;
    if (hasActiveJob) _completionAction = CompletionAction.none;
    engineOnline = false;
    notifyListeners();
    engineOnline = await engine.restart();
    if (engineOnline) {
      await reload();
      _startRemoteJobDiscovery();
    }
    _engineMessage = () => engineOnline
        ? appL10n.engineConnected
        : engine.startupError ?? appL10n.engineStartFailed;
    notifyListeners();
  }

  Future<void> shutdownEngine() async {
    _pollRevision++;
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

  Future<void> startJob({
    String additionalText = '',
    List<String> additionalFiles = const [],
  }) async {
    if (hasActiveJob) return;
    if (files.isEmpty) {
      _engineMessage = () => appL10n.addFilesFirst;
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
        additionalText: additionalText,
        additionalFiles: additionalFiles,
      );
      logs.clear();
      _restoreJobFailures();
      _restoreJobProgress(created, reset: true);
      _runStartCursor =
          (created['run_start_cursor'] as int?) ??
          (created['event_cursor'] as num?)?.toInt() ??
          0;
      _cursor = _runStartCursor;
      jobId = created['job_id'] as String?;
      jobStatus = created['status'] as String? ?? 'running';
      jobSource = created['source']?.toString() ?? 'desktop';
      _engineMessage = () => appL10n.jobStarted;
      _restartPolling();
    } catch (error) {
      _engineMessage = () => appL10n.jobSubmitError(error);
    } finally {
      _submittingJob = false;
      notifyListeners();
    }
  }

  Future<void> cancelJob() async {
    final id = jobId;
    if (id == null || !hasActiveJob) return;
    final revision = _pollRevision;
    await engine.cancel(id);
    if (revision != _pollRevision) return;
    jobStatus = 'cancelling';
    _engineMessage = () => appL10n.jobStopping;
    _appendLog(appL10n.jobStopRequested);
    notifyListeners();
  }

  Future<void> _tick() async {
    final id = jobId;
    final revision = _pollRevision;
    if (id == null || !engineOnline || _pollInFlight) return;
    final from = _cursor;
    _pollInFlight = true;
    try {
      final payload = await engine.events(id, from);
      if (revision != _pollRevision) return;
      final events = (payload['events'] as List?) ?? [];
      final eventCursor = payload['cursor'] as int?;
      _cursor = eventCursor ?? _cursor;
      var changed = false;
      for (final (index, item) in events.indexed) {
        if (item is! Map) continue;
        final type = item['type']?.toString() ?? '';
        final currentRun = from + index >= _runStartCursor;
        if (type == 'file_progress') {
          if (currentRun) {
            changed =
                _setJobProgress(item['processed_files'], item['total_files']) ||
                changed;
          }
          continue;
        }
        final message =
            item['message']?.toString() ?? item['error']?.toString() ?? type;
        final file = item['file']?.toString();
        if (currentRun && type == 'status' && file != null) {
          _jobStageProgress = switch (item['stage']) {
            'parse' || 'transcoding' => 0.12,
            'asr' => 0.38,
            'correcting' => 0.62,
            'translating' => 0.74,
            'exporting' => 0.92,
            _ => _jobStageProgress,
          };
        }
        _appendLog(file == null ? message : '$file  $message');
        changed = true;
      }
      if (payload['closed'] == true) {
        final job = await engine.job(id);
        if (revision != _pollRevision) return;
        final status = job['status']?.toString();
        final jobCursor = job['event_cursor'] as int?;
        final sameEventCursor = eventCursor != null && eventCursor == jobCursor;
        final eventsAdvanced =
            jobCursor != null && eventCursor != null && !sameEventCursor;
        // A resumed workflow may have advanced past the event stream we saw close.
        if (!eventsAdvanced &&
            (status == null || _endedJobStatuses.contains(status))) {
          changed = true;
          _poll?.cancel();
          _pollRevision++;
          jobStatus = status ?? 'done';
          _restoreJobFailures(job);
          _restoreJobProgress(job);
          _engineMessage = () => jobStatus == 'paused'
              ? appL10n.jobPausedMessage
              : appL10n.jobEnded(appL10n.jobStatusLabel(jobDisplayStatus));
          final action = _completionAction;
          _completionAction = CompletionAction.none;
          if (sameEventCursor &&
              _successfulJobStatuses.contains(status) &&
              action != CompletionAction.none) {
            unawaited(_runCompletionAction(action, _pollRevision));
          }
        }
      }
      if (changed) notifyListeners();
    } catch (e) {
      if (revision != _pollRevision) return;
      if (e is TimeoutException) {
        _appendLog(appL10n.eventTimeoutRetry);
      } else {
        _appendLog(appL10n.pollFailed(e));
      }
      notifyListeners();
    } finally {
      _pollInFlight = false;
    }
  }

  Future<void> _runCompletionAction(
    CompletionAction action,
    int revision,
  ) async {
    try {
      await action.perform();
    } catch (error) {
      if (revision != _pollRevision) return;
      final l10n = appL10n;
      _appendLog(l10n.completionActionFailed(action.label(l10n), error));
      notifyListeners();
    }
  }

  bool _setJobProgress(Object? processed, Object? total) {
    if (processed is! int || total is! int || total < 0) return false;
    final before = jobProgress;
    _processedJobFiles = processed.clamp(0, total);
    _totalJobFiles = total;
    _jobStageProgress = 0;
    return jobProgress != before;
  }

  void _restoreJobFailures([Map<String, dynamic>? job]) {
    final results = job?['results'];
    if (job?['status'] != 'failed' || results is! List) {
      _jobFileFailures = const [];
      _jobHasFileOnlyFailure = false;
      return;
    }
    final failures = <({String path, String error})>[];
    for (final result in results.whereType<Map>()) {
      final path = result['path'];
      if (result['status'] == 'failed' && path is String && path.isNotEmpty) {
        failures.add((path: path, error: result['error']?.toString() ?? ''));
      }
    }
    _jobFileFailures = List.unmodifiable(failures);
    _jobHasFileOnlyFailure =
        failures.isNotEmpty &&
        (job?['error']?.toString().trim().isEmpty ?? true);
  }

  void _restoreJobProgress(Map<String, dynamic> job, {bool reset = false}) {
    final results = job['results'];
    final processed = results is List
        ? results
              .whereType<Map>()
              .where(
                (result) => const {'done', 'failed'}.contains(result['status']),
              )
              .length
        : job['completed_files'];
    final total = job['total_files'];
    if (processed is int && total is int) {
      _setJobProgress(processed, total);
    } else if (reset) {
      _setJobProgress(0, 0);
    } else {
      _jobStageProgress = 0;
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
    final revision = _pollRevision;
    try {
      final jobs = await engine.jobs();
      if (revision != _pollRevision || _submittingJob || !engineOnline) return;
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
          _restoreJobFailures();
          _restoreJobProgress(job);
          _runStartCursor = (job['run_start_cursor'] as int?) ?? 0;
          _engineMessage = () => appL10n.jobResumed;
          _restartPolling();
        }
        if (changed || restart) notifyListeners();
        return;
      }

      if (_poll?.isActive == true) _completionAction = CompletionAction.none;
      _poll?.cancel();
      logs.clear();
      _restoreJobFailures();
      _restoreJobProgress(job, reset: true);
      _runStartCursor = (job['run_start_cursor'] as int?) ?? 0;
      _cursor = 0;
      jobId = id;
      jobStatus = job['status']?.toString() ?? 'queued';
      jobSource = 'kikoeta';
      _engineMessage = () => appL10n.showingKikoetaLogs;
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
    languageNotifier.dispose();
    super.dispose();
  }
}
