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

Map<String, dynamic> modelSettings() => {
  'asr': {'model': 'asr.gguf', 'aligner': 'aligner.gguf'},
  'llama_model': 'llama.gguf',
  'correct': {
    'provider': 'online',
    'base_url': 'https://correct.example/v1',
    'model': 'correct-model',
    'api_key': 'correct-test-key',
    'prompt': 'keep correction prompt',
  },
  'translate': {
    'provider': 'online',
    'translator': 'ForGal-json',
    'openai': {
      'base_url': 'https://translate.example/v1',
      'model': 'translate-model',
      'api_key': 'translate-test-key',
    },
    'batch_size': 7,
  },
};

Finder modelField(String label, [int index = 0]) => find
    .byWidgetPredicate(
      (widget) => widget is TextField && widget.decoration?.labelText == label,
    )
    .at(index);

const endpointFields = [
  ('API 地址', 0, 'base_url'),
  ('模型名', 0, 'model'),
  ('API Key', 0, 'api_key'),
  ('OpenAI 兼容地址', 0, 'base_url'),
  ('模型名', 1, 'model'),
  ('API Key', 1, 'api_key'),
];

void expectModelEndpoints(WidgetTester tester, Map<String, dynamic> settings) {
  for (var i = 0; i < endpointFields.length; i++) {
    final (label, index, key) = endpointFields[i];
    final endpoint = i < 3
        ? settings['correct']
        : settings['translate']['openai'];
    expect(
      tester.widget<TextField>(modelField(label, index)).controller!.text,
      endpoint[key],
    );
  }
}

Future<void> pumpModelsPage(WidgetTester tester, AppState app) async {
  tester.view.physicalSize = const Size(1200, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  app.tab = 1;
  app.tabNotifier.value = 1;
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: ModelsPage(app: app)),
    ),
  );
  await tester.pump();
}

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

  testWidgets('output page saves LLS sync and reveals authentication fields', (
    tester,
  ) async {
    final engine = FakeEngine();
    final app = AppState(engine: engine)..settings = initialSettings();
    app.tab = 5;
    app.tabNotifier.value = 5;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: OutputPage(app: app)),
      ),
    );
    await tester.tap(find.text('来自 Kikoeta 的翻译请求，产物同步上传到 Kikoeta-LLS'));
    await tester.pumpAndSettle();
    expect(find.text('Kikoeta-LLS 地址（HTTP/HTTPS）'), findsOneWidget);
    await app.selectTab(0);
    expect(engine.stored['output']['lls_sync'], true);
    expect(engine.stored['output']['lls_auth_mode'], 'key');
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

  testWidgets('model page restores saved online endpoints without writing', (
    tester,
  ) async {
    final engine = FakeEngine()..stored = modelSettings();
    final app = AppState(engine: engine)..settings = await engine.settings();
    await pumpModelsPage(tester, app);
    expectModelEndpoints(tester, engine.stored);
    expect(tester.widget<TextField>(modelField('API Key')).obscureText, true);
    await app.selectTab(0);
    expect(engine.saves, 0);
    await tester.pumpWidget(const SizedBox.shrink());
    app.dispose();
  });

  testWidgets('model page restores endpoints after a delayed settings load', (
    tester,
  ) async {
    final engine = SlowSettingsEngine();
    final app = AppState(engine: engine);
    final loading = app.reload();
    await pumpModelsPage(tester, app);
    engine.response.complete(modelSettings());
    await loading;
    await tester.pump();
    expectModelEndpoints(tester, app.settings);
    await app.selectTab(0);
    expect(engine.saves, 0);
    await tester.pumpWidget(const SizedBox.shrink());
    app.dispose();
  });

  testWidgets('delayed settings load preserves model page edits', (
    tester,
  ) async {
    final engine = SlowSettingsEngine();
    final app = AppState(engine: engine);
    final loading = app.reload();
    await pumpModelsPage(tester, app);
    await tester.enterText(modelField('API 地址'), 'https://edited.example/v1');
    engine.response.complete(modelSettings());
    await loading;
    await tester.pump();
    expect(
      tester.widget<TextField>(modelField('API 地址')).controller!.text,
      'https://edited.example/v1',
    );
    await app.selectTab(0);
    expect(engine.saves, 1);
    expect(engine.stored['correct']['base_url'], 'https://edited.example/v1');
    expect(engine.stored['correct']['model'], 'correct-model');
    expect(engine.stored['correct']['api_key'], 'correct-test-key');
    expect(
      engine.stored['translate']['openai'],
      modelSettings()['translate']['openai'],
    );
    await tester.pumpWidget(const SizedBox.shrink());
    app.dispose();
  });

  testWidgets('changed endpoints survive navigation and a new app state', (
    tester,
  ) async {
    final engine = FakeEngine()..stored = modelSettings();
    final app = AppState(engine: engine)..settings = await engine.settings();
    await pumpModelsPage(tester, app);
    for (final (label, index, _) in endpointFields) {
      await tester.enterText(modelField(label, index), 'updated-$label-$index');
    }
    await app.selectTab(0);
    expect(engine.saves, 1);
    for (var i = 0; i < endpointFields.length; i++) {
      final (label, index, key) = endpointFields[i];
      final endpoint = i < 3
          ? engine.stored['correct']
          : engine.stored['translate']['openai'];
      expect(endpoint[key], 'updated-$label-$index');
    }
    expect(engine.stored['correct']['prompt'], 'keep correction prompt');
    expect(engine.stored['translate']['batch_size'], 7);
    await tester.pumpWidget(const SizedBox.shrink());
    app.dispose();
    final reopened = AppState(engine: engine);
    await reopened.reload();
    await pumpModelsPage(tester, reopened);
    expectModelEndpoints(tester, engine.stored);
    await tester.pumpWidget(const SizedBox.shrink());
    reopened.dispose();
  });

  testWidgets('manual save persists cleared endpoint fields', (tester) async {
    final engine = FakeEngine()..stored = modelSettings();
    final app = AppState(engine: engine)..settings = await engine.settings();
    await pumpModelsPage(tester, app);
    for (final (label, index, _) in endpointFields) {
      await tester.enterText(modelField(label, index), '');
    }
    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await tester.pumpAndSettle();
    expect(engine.saves, 1);
    for (final key in ['base_url', 'model', 'api_key']) {
      expect(engine.stored['correct'][key], '');
      expect(engine.stored['translate']['openai'][key], '');
    }
    await app.selectTab(0);
    expect(engine.saves, 1);
    await tester.pumpWidget(const SizedBox.shrink());
    app.dispose();
  });

  testWidgets('switching to local models retains edited online endpoints', (
    tester,
  ) async {
    final engine = FakeEngine()..stored = modelSettings();
    final app = AppState(engine: engine)..settings = await engine.settings();
    await pumpModelsPage(tester, app);
    await tester.enterText(modelField('API 地址'), 'https://edited.example/v1');
    for (var index = 0; index < 2; index++) {
      await tester.tap(find.byType(DropdownButton<String>).at(index));
      await tester.pumpAndSettle();
      await tester.tap(find.text('本地 Llama').last);
      await tester.pumpAndSettle();
    }
    await app.selectTab(0);
    expect(engine.stored['correct']['provider'], 'local_llama');
    expect(engine.stored['translate']['provider'], 'local_llama');
    expect(engine.stored['correct']['base_url'], 'https://edited.example/v1');
    expect(engine.stored['correct']['api_key'], 'correct-test-key');
    expect(
      engine.stored['translate']['openai'],
      modelSettings()['translate']['openai'],
    );
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
