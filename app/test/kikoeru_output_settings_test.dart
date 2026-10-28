import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kikoeta_transl/app_state.dart';
import 'package:kikoeta_transl/pages/output_page.dart';
import 'package:kikoeta_transl/services/engine.dart';

class _SettingsEngine extends EngineClient {
  Map<String, dynamic> saved = {};
  int saves = 0;
  int statusReads = 0;
  final retried = <String>[];
  List<Map<String, dynamic>> entries = [];
  List<Map<String, dynamic>> pendingJobs = [];
  Completer<void>? retryWait;
  bool failSave = false;

  @override
  Future<Map<String, dynamic>> saveSettings(Map<String, dynamic> body) async {
    if (failSave) throw StateError('save failed');
    saves++;
    saved = Map<String, dynamic>.from(jsonDecode(jsonEncode(body)) as Map);
    return saved;
  }

  @override
  Future<Map<String, dynamic>> kikoeruDeliveries() async {
    statusReads++;
    return {'entries': entries, 'pending_jobs': pendingJobs};
  }

  @override
  Future<Map<String, dynamic>> retryKikoeruDelivery(String deliveryId) async {
    retried.add(deliveryId);
    await retryWait?.future;
    entries = [
      for (final item in entries)
        if (item['delivery_id'] == deliveryId)
          {...item, 'status': 'queued'}
        else
          item,
    ];
    return entries.firstWhere((item) => item['delivery_id'] == deliveryId);
  }
}

Map<String, dynamic> _settings() => {
  'output': {
    'preset': 'target_lrc',
    'formats': ['lrc'],
    'suffix': '.keep',
    'lls_sync': true,
    'lls_key': 'existing-key',
    'kikoeru_sync': true,
    'kikoeru_url': 'http://127.0.0.1:2379',
    'kikoeru_token': 'sidecar-secret',
    'kikoeru_source_id': 'home-library',
    'kikoeru_media_url_prefix': 'https://library.example/api/media/download/',
  },
};

Finder _field(String label) => find.byWidgetPredicate(
  (widget) => widget is TextField && widget.decoration?.labelText == label,
);

Future<void> _show(WidgetTester tester, AppState app) async {
  tester.view.physicalSize = const Size(1200, 2600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  app.tab = 5;
  app.tabNotifier.value = 5;
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: OutputPage(app: app)),
    ),
  );
}

void main() {
  testWidgets(
    'restores sidecar configuration without saving unchanged fields',
    (tester) async {
      final engine = _SettingsEngine();
      final app = AppState(engine: engine)..settings = _settings();
      await _show(tester, app);
      expect(
        tester.widget<TextField>(_field('外挂地址（HTTP/HTTPS）')).controller!.text,
        'http://127.0.0.1:2379',
      );
      final secret = tester.widget<TextField>(_field('外挂访问密钥'));
      expect(secret.controller!.text, 'sidecar-secret');
      expect(secret.obscureText, true);
      expect(
        tester.widget<TextField>(_field('来源 ID')).controller!.text,
        'home-library',
      );
      await app.selectTab(0);
      expect(engine.saves, 0);
      await tester.pumpWidget(const SizedBox.shrink());
      app.dispose();
    },
  );

  testWidgets('sidecar edits autosave and preserve unrelated output settings', (
    tester,
  ) async {
    final engine = _SettingsEngine();
    final app = AppState(engine: engine)..settings = _settings();
    await _show(tester, app);
    await tester.tap(find.text('将匹配来源的歌词写回 Kikoeru 音轨目录'));
    await tester.enterText(
      _field('外挂地址（HTTP/HTTPS）'),
      ' http://localhost:2380 ',
    );
    await tester.enterText(_field('外挂访问密钥'), ' new-secret ');
    await tester.enterText(_field('来源 ID'), ' second-library ');
    await tester.enterText(
      _field('媒体 URL 前缀'),
      ' https://media.example/private/audio/ ',
    );
    await app.selectTab(0);
    final output = engine.saved['output'] as Map;
    expect(output['kikoeru_sync'], false);
    expect(output['kikoeru_url'], 'http://localhost:2380');
    expect(output['kikoeru_token'], 'new-secret');
    expect(output['kikoeru_source_id'], 'second-library');
    expect(
      output['kikoeru_media_url_prefix'],
      'https://media.example/private/audio/',
    );
    expect(output['suffix'], '.keep');
    expect(output['lls_sync'], true);
    expect(output['lls_key'], 'existing-key');
    expect(engine.saves, 1);
    await tester.pumpWidget(const SizedBox.shrink());
    app.dispose();
  });

  testWidgets(
    'late configuration load preserves a locally edited sidecar field',
    (tester) async {
      final engine = _SettingsEngine();
      final app = AppState(engine: engine);
      await _show(tester, app);
      await tester.enterText(_field('来源 ID'), 'edited-source');
      app.settings = _settings();
      app.notifyListeners();
      await tester.pump();
      expect(
        tester.widget<TextField>(_field('来源 ID')).controller!.text,
        'edited-source',
      );
      expect(
        tester.widget<TextField>(_field('媒体 URL 前缀')).controller!.text,
        'https://library.example/api/media/download/',
      );
      await app.selectTab(0);
      expect(engine.saved['output']['kikoeru_source_id'], 'edited-source');
      expect(engine.saved['output']['kikoeru_sync'], true);
      await tester.pumpWidget(const SizedBox.shrink());
      app.dispose();
    },
  );

  testWidgets(
    'writeback status is loaded on demand and distinguishes matching',
    (tester) async {
      final engine = _SettingsEngine()
        ..entries = [
          {
            'delivery_id': 'selected',
            'work_id': 'RJ123456',
            'track_path': 'selected.wav',
            'status': 'completed',
            'result': {'match': 'selected'},
          },
          {
            'delivery_id': 'unselected',
            'work_id': 'RJ123456',
            'track_path': 'unselected.wav',
            'status': 'completed',
            'result': {'match': 'present_not_selected'},
          },
        ]
        ..pendingJobs = [
          {
            'job_id': 'pending-job',
            'kikoeru_pending_count': 2,
            'kikoeru_delivery_error': 'storage temporarily unavailable',
          },
        ];
      final app = AppState(engine: engine)..settings = _settings();
      await _show(tester, app);
      expect(engine.statusReads, 0);
      await tester.tap(find.text('查看写回状态'));
      await tester.pumpAndSettle();
      expect(find.textContaining('服务端已选中此歌词'), findsOneWidget);
      expect(find.textContaining('文件已写入，服务端当前未选中'), findsOneWidget);
      expect(find.text('待保存 2 个写回结果'), findsOneWidget);
      expect(
        find.textContaining('storage temporarily unavailable'),
        findsOneWidget,
      );
      await tester.pump(const Duration(seconds: 5));
      expect(engine.statusReads, 1);
      await tester.pumpWidget(const SizedBox.shrink());
      app.dispose();
    },
  );

  testWidgets(
    'conflict retry saves settings and refreshes the delivery record',
    (tester) async {
      final engine = _SettingsEngine()
        ..retryWait = Completer<void>()
        ..entries = [
          {
            'delivery_id': 'conflict',
            'work_id': 'RJ123456',
            'track_path': 'track.wav',
            'status': 'conflict',
            'error': 'existing lyric differs',
          },
        ];
      final app = AppState(engine: engine)..settings = _settings();
      await _show(tester, app);
      await tester.tap(find.text('查看写回状态'));
      await tester.pumpAndSettle();
      expect(find.textContaining('同名歌词冲突'), findsOneWidget);
      expect(find.textContaining('existing lyric differs'), findsOneWidget);
      await tester.enterText(_field('外挂访问密钥'), 'updated-secret');
      await tester.ensureVisible(find.text('重试'));
      await tester.tap(find.text('重试'));
      await tester.pump();
      expect(engine.saved['output']['kikoeru_token'], 'updated-secret');
      expect(engine.retried, ['conflict']);
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, '正在重试…'))
            .onPressed,
        isNull,
      );
      engine.retryWait!.complete();
      await tester.pumpAndSettle();
      expect(engine.statusReads, 2);
      expect(find.textContaining('等待发送'), findsOneWidget);
      expect(find.text('重试'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      app.dispose();
    },
  );

  testWidgets(
    'failed configuration save prevents retry with stale credentials',
    (tester) async {
      final engine = _SettingsEngine()
        ..failSave = true
        ..entries = [
          {
            'delivery_id': 'failed',
            'work_id': 'RJ123456',
            'track_path': 'track.wav',
            'status': 'failed',
          },
        ];
      final app = AppState(engine: engine)..settings = _settings();
      await _show(tester, app);
      await tester.tap(find.text('查看写回状态'));
      await tester.pumpAndSettle();
      await tester.enterText(_field('外挂访问密钥'), 'updated-secret');
      await tester.ensureVisible(find.text('重试'));
      await tester.tap(find.text('重试'));
      await tester.pumpAndSettle();
      expect(engine.retried, isEmpty);
      expect(find.textContaining('重试写回失败'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      app.dispose();
    },
  );
}
