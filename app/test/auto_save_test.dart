import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kikoeta_transl/app_state.dart';
import 'package:kikoeta_transl/pages/output_page.dart';
import 'package:kikoeta_transl/pages/models_page.dart';
import 'package:kikoeta_transl/pages/params_page.dart';
import 'package:kikoeta_transl/pages/model_params_page.dart';
import 'package:kikoeta_transl/pages/settings_page.dart';
import 'package:kikoeta_transl/services/engine.dart';

class FakeEngine extends EngineClient {
  Map<String, dynamic> stored = {};
  int saves = 0;
  bool fail = false;

  @override
  Future<Map<String, dynamic>> saveSettings(Map<String, dynamic> body) async {
    if (fail) throw StateError('save failed');
    saves++;
    stored = Map<String, dynamic>.from(jsonDecode(jsonEncode(body)) as Map);
    return stored;
  }

  @override
  Future<Map<String, dynamic>> settings() async => stored;

  @override
  Future<Map<String, dynamic>> tools() async => {};
}

class SlowSettingsEngine extends FakeEngine {
  final response = Completer<Map<String, dynamic>>();

  @override
  Future<Map<String, dynamic>> settings() => response.future;
}

Map<String, dynamic> initialSettings() => {
  'output': {
    'directory': 'old',
    'preset': 'target_lrc',
    'formats': ['lrc'],
    'bilingual': false,
  },
};

void main() {
  test('serialized writes merge changes from different pages', () async {
    final engine = FakeEngine();
    final app = AppState(engine: engine)..settings = initialSettings();
    final first = app.updateSettings(
      (next) => next['flags'] = {'enable_correct': true},
    );
    final second = app.updateSettings((next) {
      next['output'] = {...(next['output'] as Map), 'directory': 'new'};
    });
    await Future.wait([first, second]);
    expect(engine.stored['flags']['enable_correct'], true);
    expect(engine.stored['output']['directory'], 'new');
    app.dispose();
  });

  test('late reload cannot replace a newer save', () async {
    final engine = SlowSettingsEngine();
    final app = AppState(engine: engine)..settings = initialSettings();
    final loading = app.reload();
    await app.updateSettings((next) {
      next['output'] = {...(next['output'] as Map), 'directory': 'new'};
    });
    engine.response.complete(initialSettings());
    await loading;
    expect(app.settings['output']['directory'], 'new');
    app.dispose();
  });

  testWidgets('leaving output saves the changed directory', (tester) async {
    final engine = FakeEngine();
    final app = AppState(engine: engine)..settings = initialSettings();
    app.tab = 5;
    app.tabNotifier.value = 5;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: OutputPage(app: app)),
      ),
    );
    await tester.enterText(find.byType(TextField).first, 'new');
    await app.selectTab(0);
    expect(engine.stored['output']['directory'], 'new');
    expect(app.tab, 0);
    await tester.pumpWidget(const SizedBox.shrink());
    app.dispose();
  });

  testWidgets('unchanged page does not write settings', (tester) async {
    final engine = FakeEngine();
    final app = AppState(engine: engine)..settings = initialSettings();
    app.tab = 5;
    app.tabNotifier.value = 5;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: OutputPage(app: app)),
      ),
    );
    await app.selectTab(0);
    expect(engine.saves, 0);
    await tester.pumpWidget(const SizedBox.shrink());
    app.dispose();
  });

  testWidgets('failed save keeps the current page', (tester) async {
    final engine = FakeEngine()..fail = true;
    final app = AppState(engine: engine)..settings = initialSettings();
    app.tab = 5;
    app.tabNotifier.value = 5;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: OutputPage(app: app)),
      ),
    );
    await tester.enterText(find.byType(TextField).first, 'new');
    await expectLater(app.selectTab(0), throwsStateError);
    expect(app.tab, 5);
    await tester.pumpWidget(const SizedBox.shrink());
    app.dispose();
  });

  testWidgets('late settings load updates an untouched page', (tester) async {
    final engine = FakeEngine();
    final app = AppState(engine: engine);
    app.tab = 5;
    app.tabNotifier.value = 5;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: OutputPage(app: app)),
      ),
    );
    app.settings = initialSettings();
    app.notifyListeners();
    await tester.pump();
    expect(
      tester.widget<TextField>(find.byType(TextField).first).controller!.text,
      'old',
    );
    await app.selectTab(0);
    expect(engine.saves, 0);
    await tester.pumpWidget(const SizedBox.shrink());
    app.dispose();
  });

  testWidgets('model page saves on navigation', (tester) async {
    final engine = FakeEngine();
    final app = AppState(engine: engine)..settings = initialSettings();
    app.tab = 1;
    app.tabNotifier.value = 1;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ModelsPage(app: app)),
      ),
    );
    await tester.enterText(find.byType(TextField).first, 'model.gguf');
    await app.selectTab(0);
    expect(engine.stored['asr']['model'], 'model.gguf');
    await tester.pumpWidget(const SizedBox.shrink());
    app.dispose();
  });

  testWidgets('ASR template saves on navigation', (tester) async {
    final engine = FakeEngine();
    final app = AppState(engine: engine)..settings = initialSettings();
    app.tab = 2;
    app.tabNotifier.value = 2;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ParamsPage(app: app)),
      ),
    );
    await tester.enterText(
      find.byType(TextField).first,
      '--threads 6 --max-new-tokens 512',
    );
    await app.selectTab(0);
    expect(engine.stored['asr']['threads'], 6);
    await tester.pumpWidget(const SizedBox.shrink());
    app.dispose();
  });

  testWidgets('model parameters save on navigation', (tester) async {
    final engine = FakeEngine();
    final app = AppState(engine: engine)..settings = initialSettings();
    app.tab = 3;
    app.tabNotifier.value = 3;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ModelParamsPage(app: app)),
      ),
    );
    await tester.enterText(find.byType(TextField).first, 'new prompt');
    await app.selectTab(0);
    expect(engine.stored['correct']['prompt'], 'new prompt');
    await tester.pumpWidget(const SizedBox.shrink());
    app.dispose();
  });

  testWidgets('settings page saves paths on navigation', (tester) async {
    final engine = FakeEngine();
    final app = AppState(engine: engine)..settings = initialSettings();
    app.tab = 6;
    app.tabNotifier.value = 6;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: SettingsPage(app: app)),
      ),
    );
    await tester.enterText(find.byType(TextField).first, 'ffmpeg.exe');
    await app.selectTab(0);
    expect(engine.stored['ffmpeg_path'], 'ffmpeg.exe');
    await tester.pumpWidget(const SizedBox.shrink());
    app.dispose();
  });
}
