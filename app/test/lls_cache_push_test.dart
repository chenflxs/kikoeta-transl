import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kikoeta_transl/app_state.dart';
import 'package:kikoeta_transl/pages/output_page.dart';
import 'package:kikoeta_transl/services/engine.dart';

class CacheEngine extends EngineClient {
  final calls = <String>[];
  final firstUpload = Completer<void>();
  Map<String, dynamic>? saved;
  bool empty = false;
  bool failSave = false;

  @override
  Future<Map<String, dynamic>> saveSettings(Map<String, dynamic> body) async {
    if (failSave) throw StateError('save failed');
    saved = body;
    return body;
  }

  @override
  Future<List<Map<String, dynamic>>> llsCache() async {
    calls.add('list');
    return empty
        ? []
        : [
            for (final id in ['new', 'old'])
              {
                'job_id': id,
                'work_id': 'RJ123',
                'files': [
                  {'track_path': 'song.mp3'},
                ],
              },
          ];
  }

  @override
  Future<void> pushLlsCachedFile(String jobId, int index) async {
    calls.add('$jobId/$index');
    if (jobId == 'old') {
      await firstUpload.future;
      throw StateError('HTTP 401');
    }
  }

  @override
  Future<void> shutdown() async {}
}

Future<AppState> showOutput(WidgetTester tester, CacheEngine engine) async {
  await tester.binding.setSurfaceSize(const Size(1000, 1800));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final app = AppState(engine: engine)
    ..settings = {
      'output': {'lls_sync': false},
    };
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: OutputPage(app: app)),
    ),
  );
  addTearDown(app.dispose);
  return app;
}

void main() {
  testWidgets(
    'manual push saves credentials, reports partial failure and continues',
    (tester) async {
      final engine = CacheEngine();
      await showOutput(tester, engine);
      await tester.enterText(find.byType(TextField).last, 'a1B2c3D4e5F6');
      await tester.tap(find.text('将缓存推送到 LLS'));
      await tester.pump();
      expect(engine.saved!['output']['lls_key'], 'a1B2c3D4e5F6');
      expect(engine.saved!['output']['lls_sync'], false);
      expect(engine.calls, ['list', 'old/0']);
      expect(
        tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
        isNull,
      );
      engine.firstUpload.complete();
      await tester.pumpAndSettle();
      expect(engine.calls, ['list', 'old/0', 'new/0']);
      expect(find.text('推送完成：成功 1 个，失败 1 个'), findsOneWidget);
      await tester.tap(find.text('查看失败详情'));
      await tester.pumpAndSettle();
      expect(find.textContaining('HTTP 401'), findsOneWidget);
    },
  );

  testWidgets('empty cache shows a useful result without uploads', (
    tester,
  ) async {
    final engine = CacheEngine()..empty = true;
    await showOutput(tester, engine);
    await tester.tap(find.text('将缓存推送到 LLS'));
    await tester.pumpAndSettle();
    expect(engine.calls, ['list']);
    expect(find.text('暂无可推送的 Kikoeta 歌词缓存'), findsOneWidget);
  });

  testWidgets('settings failure prevents uploads with stale credentials', (
    tester,
  ) async {
    final engine = CacheEngine()..failSave = true;
    await showOutput(tester, engine);
    await tester.enterText(find.byType(TextField).last, 'a1B2c3D4e5F6');
    await tester.tap(find.text('将缓存推送到 LLS'));
    await tester.pumpAndSettle();
    expect(engine.calls, isEmpty);
    expect(find.textContaining('save failed'), findsOneWidget);
  });
}
