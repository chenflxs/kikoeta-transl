import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

class EngineClient {
  EngineClient({this.baseUrl = 'http://127.0.0.1:18765'});

  String baseUrl;
  Process? _process;
  Timer? _heartbeatTimer;
  bool _heartbeatInFlight = false;
  Future<void>? _shutdownFuture;
  http.Client? _eventsClient;
  String? startupError;
  final StringBuffer _startupOutput = StringBuffer();
  static const int port = 18765;

  Uri _uri(String path, [Map<String, String>? query]) =>
      Uri.parse('$baseUrl$path').replace(queryParameters: query);

  Future<bool> health() async {
    try {
      final res = await http
          .get(_uri('/api/health'))
          .timeout(const Duration(seconds: 2));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> ensureStarted() async {
    startupError = null;
    if (await health()) {
      _startHeartbeat();
      return true;
    }
    await _freeEnginePort();
    final python = _python();
    final server = _serverPath();
    if (python == null) {
      startupError = '未找到可用的 Python 3 解释器';
      return false;
    }
    if (server == null) {
      startupError = '未找到 engine/server.py';
      return false;
    }
    final engineDir = p.dirname(server);
    final rootDir = p.dirname(engineDir);
    final pathExtra = [
      p.join(rootDir, 'bin', 'ffmpeg', 'bin'),
      p.join(rootDir, 'bin', 'ffmpeg'),
      p.join(rootDir, 'bin', 'crispasr'),
    ].join(Platform.isWindows ? ';' : ':');
    final env = Map<String, String>.from(Platform.environment);
    final currentPath = env['PATH'] ?? env['Path'] ?? '';
    env['PATH'] = '$pathExtra${Platform.isWindows ? ';' : ':'}$currentPath';
    env['Path'] = env['PATH']!;
    _startupOutput.clear();
    try {
      _process = await Process.start(
        python,
        [server, '--host', '127.0.0.1', '--port', '$port'],
        workingDirectory: engineDir,
        environment: env,
        mode: ProcessStartMode.normal,
      );
      _watchProcess(_process!);
    } on ProcessException catch (error) {
      startupError = '无法启动 Python：${error.message}';
      return false;
    }
    for (var i = 0; i < 30; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 400));
      if (await health()) {
        _startHeartbeat();
        return true;
      }
      if (_process == null) return false;
    }
    final detail = _startupOutput.toString().trim();
    startupError ??= detail.isEmpty
        ? '等待 engine 响应超时'
        : '等待 engine 响应超时：$detail';
    return false;
  }

  Future<bool> restart() async {
    await shutdown();
    return ensureStarted();
  }

  Future<void> shutdown() {
    final inFlight = _shutdownFuture;
    if (inFlight != null) return inFlight;
    late final Future<void> shutdownFuture;
    shutdownFuture = _shutdownNow().whenComplete(() {
      if (identical(_shutdownFuture, shutdownFuture)) {
        _shutdownFuture = null;
      }
    });
    _shutdownFuture = shutdownFuture;
    return shutdownFuture;
  }

  Future<void> _shutdownNow() async {
    _stopHeartbeat();
    _cancelEventsRequest();
    final process = _process;
    try {
      await http
          .post(_uri('/api/shutdown'))
          .timeout(const Duration(seconds: 2));
    } catch (_) {
      // The process may already be stopping or the HTTP listener may be gone.
    }
    _process = null;
    if (process == null) return;
    try {
      await process.exitCode.timeout(const Duration(seconds: 3));
    } catch (_) {
      try {
        process.kill(ProcessSignal.sigterm);
      } catch (_) {}
      try {
        await process.exitCode.timeout(const Duration(seconds: 2));
      } catch (_) {
        try {
          process.kill(ProcessSignal.sigkill);
        } catch (_) {}
      }
    }
  }

  Future<void> _freeEnginePort() async {
    if (!Platform.isWindows) return;
    try {
      final result = await Process.run('netstat', [
        '-ano',
        '-p',
        'tcp',
      ], runInShell: true);
      final re = RegExp(
        r'^\s*TCP\s+(?:127\.0\.0\.1|0\.0\.0\.0):18765\s+\S+\s+LISTENING\s+(\d+)\s*$',
        caseSensitive: false,
        multiLine: true,
      );
      final pids = <String>{};
      for (final match in re.allMatches(result.stdout.toString())) {
        final pid = match.group(1);
        if (pid != null && pid != '0') pids.add(pid);
      }
      for (final pid in pids) {
        await Process.run('taskkill', ['/F', '/PID', pid], runInShell: true);
      }
    } catch (_) {}
  }

  void _watchProcess(Process process) {
    process.stdout.transform(utf8.decoder).listen(_startupOutput.write);
    process.stderr.transform(utf8.decoder).listen(_startupOutput.write);
    process.exitCode.then((code) {
      if (!identical(_process, process)) return;
      _process = null;
      _stopHeartbeat();
      final detail = _startupOutput.toString().trim();
      startupError = detail.isEmpty
          ? 'engine 已退出（退出码 $code）'
          : 'engine 已退出：$detail';
    });
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => unawaited(_sendHeartbeat()),
    );
    unawaited(_sendHeartbeat());
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  Future<void> _sendHeartbeat() async {
    if (_heartbeatInFlight) return;
    _heartbeatInFlight = true;
    try {
      await http
          .post(_uri('/api/client-heartbeat'))
          .timeout(const Duration(seconds: 2));
    } catch (_) {
      // The engine watchdog handles a disappeared client; the next tick can retry.
    } finally {
      _heartbeatInFlight = false;
    }
  }

  Future<void> forceShutdown() async {
    _stopHeartbeat();
    _cancelEventsRequest();
    final process = _process;
    _process = null;

    if (process == null) {
      // This client may have attached to an already-running engine, in which
      // case no Process handle is available. Ask it to stop and rely on its
      // heartbeat watchdog if the request cannot be delivered in time.
      try {
        await http
            .post(_uri('/api/shutdown'))
            .timeout(const Duration(milliseconds: 250));
      } catch (_) {}
      return;
    }

    if (Platform.isWindows) {
      try {
        final result = await Process.run('taskkill', [
          '/PID',
          '${process.pid}',
          '/T',
          '/F',
        ]).timeout(const Duration(milliseconds: 600));
        if (result.exitCode == 0) return;
      } catch (_) {}
    }

    try {
      process.kill(ProcessSignal.sigkill);
    } catch (_) {}
  }

  Future<Map<String, dynamic>> settings() async => _get('/api/settings');

  Future<Map<String, dynamic>> saveSettings(Map<String, dynamic> body) async {
    final res = await http
        .put(
          _uri('/api/settings'),
          headers: {'content-type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 10));
    return _decode(res);
  }

  Future<Map<String, dynamic>> tools() async {
    try {
      final remote = await _get('/api/tools');
      if (_hasTools(remote)) return remote;
    } catch (_) {}
    return scanBundled();
  }

  Future<List<String>> listOpenAiModels({
    required String baseUrl,
    String apiKey = '',
    String kind = '',
  }) async {
    final res = await http
        .post(
          _uri('/api/models/openai'),
          headers: {'content-type': 'application/json'},
          body: jsonEncode({
            'base_url': baseUrl,
            'api_key': apiKey,
            'kind': kind,
          }),
        )
        .timeout(const Duration(seconds: 20));
    final data = _decode(res);
    final error = data['error']?.toString();
    if (error != null && error.isNotEmpty) {
      throw Exception(error);
    }
    final models = data['models'];
    if (models is! List) return const [];
    return [
      for (final item in models)
        if ('$item'.trim().isNotEmpty) '$item'.trim(),
    ];
  }

  Future<Map<String, dynamic>> createJob({
    required List<String> files,
    required bool enableCorrect,
    required bool enableTranslate,
  }) async {
    final res = await http.post(
      _uri('/api/jobs'),
      headers: {'content-type': 'application/json'},
      body: jsonEncode({
        'files': files,
        'flags': {
          'enable_correct': enableCorrect,
          'enable_translate': enableTranslate,
        },
      }),
    );
    return _decode(res);
  }

  Future<Map<String, dynamic>> job(String id) async => _get('/api/jobs/$id');

  Future<List<Map<String, dynamic>>> jobs() async {
    final payload = await _get('/api/jobs');
    final items = payload['jobs'];
    if (items is! List) return const [];
    return [
      for (final item in items)
        if (item is Map) Map<String, dynamic>.from(item),
    ];
  }

  Future<Map<String, dynamic>> events(String id, int after) async {
    final client = http.Client();
    _eventsClient = client;
    try {
      final res = await client
          .get(_uri('/api/jobs/$id/events', {'after': '$after'}))
          .timeout(const Duration(seconds: 25));
      return _decode(res);
    } finally {
      if (identical(_eventsClient, client)) _eventsClient = null;
      client.close();
    }
  }

  void _cancelEventsRequest() {
    _eventsClient?.close();
    _eventsClient = null;
  }

  Future<void> cancel(String id) async {
    await http.post(_uri('/api/jobs/$id/cancel'));
  }

  Future<Map<String, dynamic>> _get(
    String path, {
    Map<String, String>? query,
    Duration timeout = const Duration(seconds: 8),
  }) async {
    final res = await http.get(_uri(path, query)).timeout(timeout);
    return _decode(res);
  }

  Map<String, dynamic> _decode(http.Response res) {
    final data = jsonDecode(utf8.decode(res.bodyBytes));
    if (data is Map) return Map<String, dynamic>.from(data);
    return {'data': data};
  }

  bool _hasTools(Map<String, dynamic> payload) {
    final asr = payload['asr'];
    final dicts = payload['gt_dicts'];
    final ffmpeg = payload['ffmpeg']?.toString() ?? '';
    final models = asr is Map ? asr['models'] : null;
    return ffmpeg.isNotEmpty ||
        (models is List && models.isNotEmpty) ||
        (dicts is List && dicts.isNotEmpty);
  }

  Map<String, dynamic> scanBundled() {
    final root = _repoRoot();
    final ffmpegDir = Directory(p.join(root, 'bin', 'ffmpeg'));
    final asrDir = Directory(p.join(root, 'bin', 'crispasr'));
    final llamaDir = Directory(p.join(root, 'bin', 'llama'));
    final dictDir = Directory(p.join(root, 'engine', 'GalTransl', 'Dict'));
    final ffmpeg = _firstFile([
      p.join(ffmpegDir.path, 'bin', 'ffmpeg.exe'),
      p.join(ffmpegDir.path, 'ffmpeg.exe'),
      p.join(root, 'bin', 'ffmpeg.exe'),
    ]);
    final ffprobeCandidates = <String>[
      p.join(ffmpegDir.path, 'bin', 'ffprobe.exe'),
      p.join(ffmpegDir.path, 'ffprobe.exe'),
    ];
    if (ffmpeg != null) {
      ffprobeCandidates.add(p.join(p.dirname(ffmpeg), 'ffprobe.exe'));
    }
    final ffprobe = _firstFile(ffprobeCandidates);
    final asrExe = _firstFile([
      p.join(asrDir.path, 'crispasr.exe'),
      p.join(asrDir.path, 'crispasr'),
    ]);
    final ggufs = _listNames(asrDir, '.gguf');
    final llamaModels = _listNames(llamaDir, '.gguf')
        .where(
          (name) =>
              !RegExp(
                r'-\d{5}-of-\d{5}\.gguf$',
                caseSensitive: false,
              ).hasMatch(name) ||
              RegExp(
                r'-00001-of-\d{5}\.gguf$',
                caseSensitive: false,
              ).hasMatch(name),
        )
        .toList();
    final models = [
      for (final name in ggufs)
        if (!name.toLowerCase().contains('aligner') &&
            !name.toLowerCase().contains('alignment'))
          name,
    ];
    final aligners = [
      for (final name in ggufs)
        if (name.toLowerCase().contains('aligner') ||
            name.toLowerCase().contains('alignment'))
          name,
    ];
    final dicts = <Map<String, dynamic>>[];
    if (dictDir.existsSync()) {
      final files = dictDir
          .listSync()
          .whereType<File>()
          .where((item) => item.path.toLowerCase().endsWith('.txt'))
          .toList();
      files.sort((a, b) => p.basename(a.path).compareTo(p.basename(b.path)));
      for (final file in files) {
        final name = p.basename(file.path);
        var count = 0;
        try {
          count = file
              .readAsLinesSync(encoding: utf8)
              .where(
                (line) =>
                    line.trim().isNotEmpty &&
                    !line.startsWith(r'\\') &&
                    !line.startsWith('//'),
              )
              .length;
        } catch (_) {}
        final lower = name.toLowerCase();
        String category = 'pre';
        if (lower.contains('gpt')) {
          category = 'gpt';
        } else if (name.contains('译后') || lower.contains('post')) {
          category = 'post';
        }
        dicts.add({
          'name': name,
          'path': file.path,
          'category': category,
          'count': count,
        });
      }
    }
    return {
      'ffmpeg': ffmpeg ?? '',
      'ffprobe': ffprobe ?? '',
      'ffmpeg_error': ffmpeg == null
          ? '未找到 ffmpeg。请将 ffmpeg.exe 放到 bin/ffmpeg/bin'
          : '',
      'asr': {
        'dir': asrDir.path,
        'models': models,
        'aligners': aligners,
        'executable': asrExe ?? '',
        'backends': const [
          'whisper',
          'parakeet',
          'canary',
          'cohere',
          'qwen3',
          'qwen3-1.7b',
          'mega-asr',
          'voxtral',
          'voxtral4b',
          'granite',
        ],
      },
      'llama': {
        'dir': llamaDir.path,
        'executable':
            _firstFile([p.join(llamaDir.path, 'llama-server.exe')]) ?? '',
        'models': llamaModels,
        'host': '127.0.0.1',
        'port': 18766,
        'endpoint': 'http://127.0.0.1:18766/v1',
        'locked': true,
        'status': 'stopped',
      },
      'dict_dir': dictDir.path,
      'gt_dicts': dicts,
      'source_langs': const [
        {'id': 'ja', 'label': 'ja · 日本語'},
        {'id': 'en', 'label': 'en · English'},
        {'id': 'zh', 'label': 'zh · 中文'},
        {'id': 'ko', 'label': 'ko · 한국어'},
        {'id': 'ru', 'label': 'ru · русский'},
        {'id': 'fr', 'label': 'fr · Français'},
        {'id': 'auto', 'label': 'auto · 自动检测'},
      ],
      'target_langs': const [
        {'id': 'zh-cn', 'label': 'zh-cn · 简体中文'},
        {'id': 'zh-tw', 'label': 'zh-tw · 繁體中文'},
        {'id': 'en', 'label': 'en · English'},
        {'id': 'ja', 'label': 'ja · 日本語'},
        {'id': 'ko', 'label': 'ko · 한국어'},
        {'id': 'ru', 'label': 'ru · русский'},
        {'id': 'fr', 'label': 'fr · Français'},
      ],
      'translators': const [
        {'id': 'ForGal-json', 'label': 'ForGal-json · Gal JSON'},
        {'id': 'ForNovel', 'label': 'ForNovel · 小说 / 其他文本'},
        {'id': 'ForGal-tsv', 'label': 'ForGal-tsv · Gal TSV'},
        {'id': 'galtransl-v3', 'label': 'galtransl-v3 · Sakura 接口'},
        {'id': 'sakura-v1.0', 'label': 'sakura-v1.0 · Sakura 接口'},
      ],
    };
  }

  List<String> _listNames(Directory dir, String ext) {
    if (!dir.existsSync()) return <String>[];
    final names = dir
        .listSync()
        .whereType<File>()
        .map((item) => p.basename(item.path))
        .where((name) => name.toLowerCase().endsWith(ext))
        .toList();
    names.sort();
    return names;
  }

  bool get hasRepo => _serverPath() != null;

  String _repoRoot() {
    final server = _serverPath();
    if (server != null) return p.dirname(p.dirname(server));
    final seeds = [
      Directory.current.path,
      File(Platform.resolvedExecutable).parent.path,
    ];
    for (final seed in seeds) {
      var dir = Directory(seed);
      for (var i = 0; i < 8; i++) {
        if (Directory(p.join(dir.path, 'bin', 'crispasr')).existsSync() ||
            File(p.join(dir.path, 'engine', 'server.py')).existsSync()) {
          return dir.path;
        }
        final parent = dir.parent;
        if (parent.path == dir.path) break;
        dir = parent;
      }
    }
    return Directory.current.path;
  }

  String? _firstFile(List<String> paths) {
    for (final item in paths) {
      if (File(item).existsSync()) return File(item).absolute.path;
    }
    return null;
  }

  String? _python() {
    for (final name in ['python', 'python3', 'py']) {
      try {
        final result = Process.runSync(name, [
          '-c',
          'import sys; sys.exit(0 if sys.version_info >= (3, 10) else 1)',
        ], runInShell: true);
        if (result.exitCode == 0) return name;
      } on ProcessException catch (_) {}
    }
    return null;
  }

  String? _serverPath() {
    final seeds = [
      Directory.current.path,
      File(Platform.resolvedExecutable).parent.path,
    ];
    for (final seed in seeds) {
      var dir = Directory(seed);
      for (var i = 0; i < 8; i++) {
        final nested = File(p.join(dir.path, 'engine', 'server.py'));
        if (nested.existsSync()) return nested.absolute.path;
        if (p.basename(dir.path).toLowerCase() == 'engine') {
          final direct = File(p.join(dir.path, 'server.py'));
          if (direct.existsSync()) return direct.absolute.path;
        }
        final parent = dir.parent;
        if (parent.path == dir.path) break;
        dir = parent;
      }
    }
    return null;
  }
}
