import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kikoeta_transl/app_state.dart';
import 'package:kikoeta_transl/pages/dict_page.dart';
import 'package:kikoeta_transl/pages/model_params_page.dart';
import 'package:kikoeta_transl/pages/output_page.dart';
import 'package:kikoeta_transl/pages/params_page.dart';
import 'package:kikoeta_transl/pages/settings_page.dart';
import 'package:kikoeta_transl/services/engine.dart';

class SettingsEngine extends EngineClient {
  Map<String, dynamic> stored = settingsFixture();
  Completer<Map<String, dynamic>>? delayed;
  int saves = 0;
  bool fail = false;

  @override
  Future<Map<String, dynamic>> settings() async =>
      delayed == null ? stored : delayed!.future;

  @override
  Future<Map<String, dynamic>> saveSettings(Map<String, dynamic> body) async {
    if (fail) throw StateError('save failed');
    saves++;
    stored = jsonDecode(jsonEncode(body)) as Map<String, dynamic>;
    return stored;
  }

  @override
  Future<Map<String, dynamic>> tools() async => {};
}

class OverlappingSettingsEngine extends SettingsEngine {
  final saveStarted = Completer<void>();
  final savedResponse = Completer<Map<String, dynamic>>();
  final loadedResponse = Completer<Map<String, dynamic>>();

  @override
  Future<Map<String, dynamic>> saveSettings(Map<String, dynamic> body) {
    saveStarted.complete();
    return savedResponse.future;
  }

  @override
  Future<Map<String, dynamic>> settings() => loadedResponse.future;
}

Map<String, dynamic> settingsFixture() => {
  'ffmpeg_path': 'saved-ffmpeg.exe',
  'crispasr_dir': 'saved-asr-dir',
  'proxy': 'http://proxy.example:7890',
  'theme': 'dark',
  'remote_username': 'saved-user',
  'remote_password': 'saved-test-password',
  'remote_access': false,
  'flags': {'enable_correct': true, 'enable_translate': false},
  'asr': {
    'model': 'saved.gguf',
    'threads': 9,
    'processors': 2,
    'hotwords': 'hello world',
    'extra_args': '',
    'max_new_tokens': 700,
    'force_aligner': false,
    'split_on_word': true,
    'no_gpu': true,
    'flash_attn': false,
  },
  'correct': {
    'prompt': 'saved correction prompt',
    'temperature': 0.6,
    'max_tokens': 2048,
    'enable_thinking': true,
    'api_key': 'keep-correction-key',
  },
  'translate': {
    'prompt': 'saved translation prompt',
    'prompt_mode': 'overwrite',
    'context_num': 5,
    'batch_size': 6,
    'token_limit': 2000,
    'enable_thinking': false,
    'openai': {'api_key': 'keep-translation-key'},
  },
  'output': {
    'directory': 'saved-output-dir',
    'preset': 'source_target_srt',
    'formats': ['srt'],
    'bilingual': true,
    'lls_sync': true,
    'lls_url': 'https://lls.example',
    'lls_auth_mode': 'basic',
    'lls_username': 'saved-lls-user',
    'lls_password': 'saved-lls-password',
    'lls_key': 'test-key-123',
    'keep_gt_cache': false,
  },
};

Finder field(String label) => find.byWidgetPredicate(
  (widget) => widget is TextField && widget.decoration?.labelText == label,
);

String textOf(WidgetTester tester, String label) =>
    tester.widget<TextField>(field(label)).controller!.text;

Future<void> pumpPage(
  WidgetTester tester,
  Widget page,
  AppState app,
  int tab,
) async {
  tester.view.physicalSize = const Size(1200, 6000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  app.tab = tab;
  app.tabNotifier.value = tab;
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: page)));
  await tester.pump();
}

Future<void> closePage(WidgetTester tester, AppState app) async {
  await tester.pumpWidget(const SizedBox.shrink());
  app.dispose();
}

void main() {
  test('reload started during a save cannot restore an older value', () async {
    final engine = OverlappingSettingsEngine();
    final app = AppState(engine: engine)..settings = settingsFixture();
    final saving = app.updateSettings((next) => next['proxy'] = '');
    await engine.saveStarted.future;
    final loading = app.reload();
    engine.savedResponse.complete({...settingsFixture(), 'proxy': ''});
    await saving;
    engine.loadedResponse.complete(settingsFixture());
    await loading;
    expect(app.settings['proxy'], '');
    app.dispose();
  });

  final pages = <(String, int, Widget Function(AppState), String, String)>[
    (
      'model parameters',
      3,
      (app) => ModelParamsPage(app: app),
      '校对系统 Prompt',
      'edited prompt',
    ),
    ('output', 5, (app) => OutputPage(app: app), '输出目录', 'edited-output'),
    (
      'settings',
      6,
      (app) => SettingsPage(app: app),
      'ffmpeg 路径',
      'edited-ffmpeg.exe',
    ),
  ];

  for (final (name, tab, makePage, label, edited) in pages) {
    testWidgets('$name saves cleared fields and retains unrelated settings', (
      tester,
    ) async {
      final engine = SettingsEngine();
      final app = AppState(engine: engine)..settings = engine.stored;
      await pumpPage(tester, makePage(app), app, tab);
      await tester.enterText(field(label), '');
      await tester.tap(find.widgetWithText(FilledButton, '保存'));
      await tester.pumpAndSettle();
      expect(engine.saves, 1);
      if (tab == 3) {
        expect(engine.stored['correct']['prompt'], '');
      } else if (tab == 5) {
        expect(engine.stored['output']['directory'], '');
        expect(engine.stored['output']['keep_gt_cache'], false);
      } else {
        expect(engine.stored['ffmpeg_path'], '');
        expect(engine.stored['remote_password'], 'saved-test-password');
      }
      expect(engine.stored['correct']['api_key'], 'keep-correction-key');
      expect(
        engine.stored['translate']['openai']['api_key'],
        'keep-translation-key',
      );
      await app.selectTab(0);
      expect(engine.saves, 1);
      await closePage(tester, app);
    });

    testWidgets('$name retains edits after a failed save and can retry', (
      tester,
    ) async {
      final engine = SettingsEngine()..fail = true;
      final app = AppState(engine: engine)..settings = engine.stored;
      await pumpPage(tester, makePage(app), app, tab);
      await tester.enterText(field(label), edited);
      await expectLater(app.selectTab(0), throwsStateError);
      expect(app.tab, tab);
      expect(textOf(tester, label), edited);
      engine.fail = false;
      await app.selectTab(0);
      expect(engine.saves, 1);
      expect(app.tab, 0);
      await closePage(tester, app);
    });

    testWidgets('$name restores settings without an unnecessary save', (
      tester,
    ) async {
      final engine = SettingsEngine();
      final app = AppState(engine: engine);
      await app.reload();
      await pumpPage(tester, makePage(app), app, tab);
      if (tab == 3) {
        expect(textOf(tester, '翻译 Prompt'), 'saved translation prompt');
        expect(textOf(tester, 'max_tokens'), '2048');
        expect(textOf(tester, 'Token 上限'), '2000');
      } else if (tab == 5) {
        expect(textOf(tester, '上传密码'), 'saved-lls-password');
      } else {
        expect(textOf(tester, 'HTTP 代理'), 'http://proxy.example:7890');
        expect(textOf(tester, '密码'), 'saved-test-password');
      }
      await app.selectTab(0);
      expect(engine.saves, 0);
      await closePage(tester, app);
    });

    testWidgets(
      '$name merges late settings without overwriting edits or stored values',
      (tester) async {
        final engine = SettingsEngine()..delayed = Completer();
        final app = AppState(engine: engine);
        final loading = app.reload();
        await pumpPage(tester, makePage(app), app, tab);
        await tester.enterText(field(label), edited);
        engine.delayed!.complete(settingsFixture());
        await loading;
        engine.delayed = null;
        await tester.pump();
        expect(textOf(tester, label), edited);
        if (tab == 3) {
          expect(textOf(tester, '翻译 Prompt'), 'saved translation prompt');
        } else if (tab == 5) {
          expect(textOf(tester, '上传密码'), 'saved-lls-password');
        } else {
          expect(textOf(tester, '密码'), 'saved-test-password');
        }
        await app.selectTab(0);
        expect(engine.saves, 1);
        if (tab == 3) {
          expect(engine.stored['correct']['prompt'], edited);
          expect(engine.stored['translate']['batch_size'], 6);
        } else if (tab == 5) {
          expect(engine.stored['output']['directory'], edited);
          expect(engine.stored['output']['preset'], 'source_target_srt');
        } else {
          expect(engine.stored['ffmpeg_path'], edited);
          expect(engine.stored['crispasr_dir'], 'saved-asr-dir');
        }
        await closePage(tester, app);
        final reopened = AppState(engine: engine);
        await reopened.reload();
        await pumpPage(tester, makePage(reopened), reopened, tab);
        expect(textOf(tester, label), edited);
        await closePage(tester, reopened);
      },
    );
  }

  testWidgets(
    'ASR structured parameters and switches survive save and reopening',
    (tester) async {
      final engine = SettingsEngine();
      final app = AppState(engine: engine)..settings = engine.stored;
      await pumpPage(tester, ParamsPage(app: app), app, 2);
      await tester.enterText(field('线程数'), '12');
      await app.selectTab(0);
      expect(engine.stored['asr']['threads'], 12);
      expect(engine.stored['asr']['processors'], 2);
      expect(engine.stored['asr']['hotwords'], 'hello world');
      expect(engine.stored['asr']['split_on_word'], true);
      expect(engine.stored['asr']['no_gpu'], true);
      expect(engine.stored['asr']['flash_attn'], false);
      expect(engine.stored['asr']['model'], 'saved.gguf');
      final command = engine.stored['asr']['extra_args'] as String;
      expect(command, contains('--threads 12'));
      expect(command, contains('--processors 2'));
      expect(command, contains('--hotwords "hello world"'));
      expect(command, contains('--split-on-word'));
      expect(command, contains('--no-gpu'));
      expect(command, contains('--no-flash-attn'));
      await closePage(tester, app);
      final reopened = AppState(engine: engine)..settings = engine.stored;
      await pumpPage(tester, ParamsPage(app: reopened), reopened, 2);
      expect(textOf(tester, '线程数'), '12');
      expect(textOf(tester, '热词（逗号分隔）'), 'hello world');
      await closePage(tester, reopened);
    },
  );

  testWidgets(
    'ASR custom template keeps unknown options and clears optional values',
    (tester) async {
      final engine = SettingsEngine();
      final app = AppState(engine: engine)..settings = engine.stored;
      await pumpPage(tester, ParamsPage(app: app), app, 2);
      const command =
          r'$crispasr_executable --threads 8 --custom-option keep --flush-after 0';
      await tester.enterText(field('完整命令模板'), command);
      await app.selectTab(0);
      expect(engine.stored['asr']['extra_args'], command);
      expect(engine.stored['asr']['threads'], 8);
      expect(engine.stored['asr']['hotwords'], '');
      expect(engine.stored['asr']['flush_after'], 0);
      expect(engine.stored['asr']['no_gpu'], false);
      await closePage(tester, app);
    },
  );

  testWidgets(
    'ASR late load preserves structured edits and remaining parameters',
    (tester) async {
      final engine = SettingsEngine()..delayed = Completer();
      final app = AppState(engine: engine);
      final loading = app.reload();
      await pumpPage(tester, ParamsPage(app: app), app, 2);
      await tester.enterText(field('线程数'), '12');
      engine.delayed!.complete(settingsFixture());
      await loading;
      await tester.pump();
      expect(textOf(tester, '线程数'), '12');
      expect(textOf(tester, '处理器数'), '2');
      await app.selectTab(0);
      expect(engine.stored['asr']['threads'], 12);
      expect(engine.stored['asr']['max_new_tokens'], 700);
      await closePage(tester, app);
    },
  );

  test('stage flags and theme survive settings reload', () async {
    final engine = SettingsEngine();
    final app = AppState(engine: engine);
    await app.reload();
    expect(app.enableCorrect, true);
    expect(app.enableTranslate, false);
    expect(app.themeNotifier.value, 'dark');
    app.setStageFlag('correct', false);
    await app.selectTab(1);
    await app.reload();
    expect(app.enableCorrect, false);
    expect(app.enableTranslate, false);
    expect(engine.stored['flags'], {
      'enable_correct': false,
      'enable_translate': false,
    });
    app.dispose();
  });

  testWidgets('dictionary editor persists content to a real file', (
    tester,
  ) async {
    final directory = (await tester.runAsync(
      () => Directory.systemTemp.createTemp('kt_dict_test_'),
    ))!;
    final file = File('${directory.path}/dictionary.txt');
    await tester.runAsync(() => file.writeAsString('old\t旧'));
    final app = AppState(engine: SettingsEngine())
      ..tools = {
        'gt_dicts': [
          {
            'name': 'test dictionary',
            'path': file.path,
            'category': 'pre',
            'count': 1,
          },
        ],
      };
    await pumpPage(tester, DictPage(app: app), app, 4);
    await tester.runAsync(() async {
      await tester.tap(find.text('test dictionary'));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'new\t新');
    await tester.runAsync(() async {
      await tester.tap(find.widgetWithText(FilledButton, '保存'));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();
    expect(await tester.runAsync(file.readAsString), 'new\t新');
    await closePage(tester, app);
    await tester.runAsync(() async {
      await file.delete();
      await directory.delete();
    });
  });
}
