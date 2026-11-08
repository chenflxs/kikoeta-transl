import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../app_state.dart';
import '../settings_draft.dart';
import '../widgets.dart';

class ModelsPage extends StatefulWidget {
  final AppState app;
  const ModelsPage({super.key, required this.app});

  @override
  State<ModelsPage> createState() => _ModelsPageState();
}

class _ModelsPageState extends State<ModelsPage> {
  late final TextEditingController asrModel;
  late final TextEditingController asrAligner;
  late final TextEditingController asrBackend;
  late final TextEditingController asrLang;
  late final TextEditingController llamaModel;
  late final TextEditingController correctBase;
  late final TextEditingController correctModel;
  late final TextEditingController correctKey;
  late final TextEditingController transBase;
  late final TextEditingController transModel;
  late final TextEditingController transKey;
  late final TextEditingController translator;
  late final TextEditingController targetLang;
  List<String> correctModels = [];
  List<String> translateModels = [];
  bool queryingAsr = false;
  bool queryingLlama = false;
  bool queryingCorrect = false;
  bool queryingTranslate = false;
  bool settingsSynced = false;
  bool indexModelCompat = false;
  String correctProvider = 'online';
  String translateProvider = 'online';
  late String _savedDraft;
  late final VoidCallback _unregisterPageSaver;

  @override
  void initState() {
    super.initState();
    final s = widget.app.settings;
    final asr = (s['asr'] as Map?) ?? {};
    final correct = (s['correct'] as Map?) ?? {};
    final translate = (s['translate'] as Map?) ?? {};
    final openai = (translate['openai'] as Map?) ?? {};
    asrModel = TextEditingController(text: '${asr['model'] ?? ''}');
    asrAligner = TextEditingController(text: '${asr['aligner'] ?? ''}');
    asrBackend = TextEditingController(
      text: '${asr['backend'] ?? 'qwen3-1.7b'}',
    );
    asrLang = TextEditingController(
      text: '${s['source_lang'] ?? asr['language'] ?? 'ja'}',
    );
    llamaModel = TextEditingController(text: '${s['llama_model'] ?? ''}');
    correctProvider = _provider('${correct['provider'] ?? 'online'}');
    translateProvider = _provider('${translate['provider'] ?? 'online'}');
    indexModelCompat = translate['index_compat'] == true;
    correctBase = TextEditingController(text: '${correct['base_url'] ?? ''}');
    correctModel = TextEditingController(text: '${correct['model'] ?? ''}');
    correctKey = TextEditingController(text: '${correct['api_key'] ?? ''}');
    transBase = TextEditingController(text: '${openai['base_url'] ?? ''}');
    transModel = TextEditingController(text: '${openai['model'] ?? ''}');
    transKey = TextEditingController(text: '${openai['api_key'] ?? ''}');
    translator = TextEditingController(
      text: '${translate['translator'] ?? 'ForGal-json'}',
    );
    targetLang = TextEditingController(text: '${s['target_lang'] ?? 'zh-cn'}');
    _savedDraft = _draft();
    _unregisterPageSaver = widget.app.registerPageSaver(
      1,
      () => _save(auto: true),
    );
    widget.app.addListener(_syncSettings);
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncSettings());
  }

  void _syncSettings() {
    if (!mounted || settingsSynced || widget.app.settings.isEmpty) return;
    final s = widget.app.settings;
    final asr = (s['asr'] as Map?) ?? {};
    final correct = (s['correct'] as Map?) ?? {};
    final translate = (s['translate'] as Map?) ?? {};
    final openai = (translate['openai'] as Map?) ?? {};
    final merged = mergeLoadedSettingsDraft(_savedDraft, _draftValues(), {
      'asrModel': '${asr['model'] ?? ''}',
      'asrAligner': '${asr['aligner'] ?? ''}',
      'asrBackend': '${asr['backend'] ?? 'qwen3-1.7b'}',
      'asrLang': '${s['source_lang'] ?? asr['language'] ?? 'ja'}',
      'llamaModel': '${s['llama_model'] ?? ''}',
      'correctProvider': _provider('${correct['provider'] ?? 'online'}'),
      'correctBase': '${correct['base_url'] ?? ''}',
      'correctModel': '${correct['model'] ?? ''}',
      'correctKey': '${correct['api_key'] ?? ''}',
      'translateProvider': _provider('${translate['provider'] ?? 'online'}'),
      'indexModelCompat': translate['index_compat'] == true,
      'transBase': '${openai['base_url'] ?? ''}',
      'transModel': '${openai['model'] ?? ''}',
      'transKey': '${openai['api_key'] ?? ''}',
      'translator': '${translate['translator'] ?? 'ForGal-json'}',
      'targetLang': '${s['target_lang'] ?? 'zh-cn'}',
    });
    settingsSynced = true;
    setState(() {
      asrModel.text = merged.values['asrModel'] as String;
      asrAligner.text = merged.values['asrAligner'] as String;
      asrBackend.text = merged.values['asrBackend'] as String;
      asrLang.text = merged.values['asrLang'] as String;
      llamaModel.text = merged.values['llamaModel'] as String;
      correctProvider = merged.values['correctProvider'] as String;
      correctBase.text = merged.values['correctBase'] as String;
      correctModel.text = merged.values['correctModel'] as String;
      correctKey.text = merged.values['correctKey'] as String;
      translateProvider = merged.values['translateProvider'] as String;
      indexModelCompat = merged.values['indexModelCompat'] as bool;
      transBase.text = merged.values['transBase'] as String;
      transModel.text = merged.values['transModel'] as String;
      transKey.text = merged.values['transKey'] as String;
      translator.text = merged.values['translator'] as String;
      targetLang.text = merged.values['targetLang'] as String;
    });
    _savedDraft = merged.baseline;
  }

  Map<String, dynamic> _draftValues() => {
    'asrModel': asrModel.text,
    'asrAligner': asrAligner.text,
    'asrBackend': asrBackend.text,
    'asrLang': asrLang.text,
    'llamaModel': llamaModel.text,
    'correctProvider': correctProvider,
    'correctBase': correctBase.text,
    'correctModel': correctModel.text,
    'correctKey': correctKey.text,
    'translateProvider': translateProvider,
    'indexModelCompat': indexModelCompat,
    'transBase': transBase.text,
    'transModel': transModel.text,
    'transKey': transKey.text,
    'translator': translator.text,
    'targetLang': targetLang.text,
  };

  String _draft() => jsonEncode(_draftValues());

  @override
  void dispose() {
    _unregisterPageSaver();
    widget.app.removeListener(_syncSettings);
    asrModel.dispose();
    asrAligner.dispose();
    asrBackend.dispose();
    asrLang.dispose();
    llamaModel.dispose();
    correctBase.dispose();
    correctModel.dispose();
    correctKey.dispose();
    transBase.dispose();
    transModel.dispose();
    transKey.dispose();
    translator.dispose();
    targetLang.dispose();
    super.dispose();
  }

  Map<String, dynamic> get _asr {
    final raw = widget.app.tools['asr'];
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return <String, dynamic>{};
  }

  Map<String, dynamic> get _llama {
    final raw = widget.app.tools['llama'];
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return <String, dynamic>{};
  }

  String _provider(String value) => value == 'local_llama' ? value : 'online';

  List<String> _ids(dynamic raw) {
    if (raw is! List) return const [];
    return [
      for (final item in raw)
        if (item is Map && '${item['id'] ?? ''}'.trim().isNotEmpty)
          '${item['id']}'.trim()
        else if ('$item'.trim().isNotEmpty)
          '$item'.trim(),
    ];
  }

  Map<String, String> _labels(dynamic raw, {bool catalog = false}) {
    if (raw is! List) return const {};
    final out = <String, String>{};
    for (final item in raw) {
      if (item is Map) {
        final id = '${item['id'] ?? ''}'.trim();
        final label = catalog
            ? switch (id) {
                'auto' => appL10n.autoDetectLanguage,
                'ForNovel' => appL10n.forNovelTranslator,
                'galtransl-v3' => appL10n.galtranslSakuraTranslator,
                'sakura-v1.0' => appL10n.sakuraTranslator,
                _ => '${item['label'] ?? id}'.trim(),
              }
            : '${item['label'] ?? id}'.trim();
        if (id.isNotEmpty) out[id] = label;
      }
    }
    return out;
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _save({bool auto = false}) async {
    final draft = _draft();
    if (auto && draft == _savedDraft) return;
    final sourceLanguage = asrLang.text.trim();
    final targetLanguage = targetLang.text.trim();
    final llama = llamaModel.text.trim();
    final model = asrModel.text.trim();
    final aligner = asrAligner.text.trim();
    final backend = asrBackend.text.trim();
    final correctionProvider = correctProvider;
    final correctionBase = correctBase.text.trim();
    final correctionModel = correctModel.text.trim();
    final correctionKey = correctKey.text.trim();
    final translationProvider = translateProvider;
    final indexCompat = indexModelCompat;
    final translationBackend = translator.text.trim();
    final translationBase = transBase.text.trim();
    final translationModel = transModel.text.trim();
    final translationKey = transKey.text.trim();
    await widget.app.updateSettings((next) {
      next['source_lang'] = sourceLanguage;
      next['target_lang'] = targetLanguage;
      next['llama_model'] = llama;
      next['asr'] = {
        ...(next['asr'] as Map? ?? {}),
        'model': model,
        'aligner': aligner,
        'backend': backend,
        'language': sourceLanguage,
      };
      final correct = Map<String, dynamic>.from(next['correct'] as Map? ?? {});
      correct['provider'] = correctionProvider;
      correct['base_url'] = correctionBase;
      correct['model'] = correctionModel;
      correct['api_key'] = correctionKey;
      next['correct'] = correct;
      final translate = Map<String, dynamic>.from(
        next['translate'] as Map? ?? {},
      );
      translate['provider'] = translationProvider;
      translate['translator'] = translationBackend;
      translate['index_compat'] = indexCompat;
      translate['openai'] = {
        ...(translate['openai'] as Map? ?? {}),
        'base_url': translationBase,
        'model': translationModel,
        'api_key': translationKey,
      };
      next['translate'] = translate;
    });
    _savedDraft = draft;
    if (!auto) _toast(appL10n.modelSettingsSaved);
  }

  Future<void> _queryAsr() async {
    setState(() => queryingAsr = true);
    try {
      await widget.app.refreshTools();
      final models = _ids(_asr['models']);
      final dir = '${_asr['dir'] ?? ''}';
      if (models.isEmpty) {
        _toast(dir.isEmpty ? appL10n.noAsrModels : appL10n.noAsrModelsIn(dir));
      } else {
        _toast(appL10n.asrModelsFound(models.length));
      }
    } catch (e) {
      _toast(appL10n.asrScanFailed(e));
    } finally {
      if (mounted) setState(() => queryingAsr = false);
    }
  }

  Future<void> _openAsrDirectory() async {
    await _openModelDirectory('${_asr['dir'] ?? ''}', 'ASR');
  }

  Future<void> _queryLlama() async {
    setState(() => queryingLlama = true);
    try {
      await widget.app.refreshTools();
      final models = _ids(_llama['models']);
      final dir = '${_llama['dir'] ?? ''}';
      if (models.isEmpty) {
        _toast(
          dir.isEmpty ? appL10n.noLlamaModels : appL10n.noLlamaModelsIn(dir),
        );
      } else {
        _toast(appL10n.llamaModelsFound(models.length));
      }
    } catch (e) {
      _toast(appL10n.llamaScanFailed(e));
    } finally {
      if (mounted) setState(() => queryingLlama = false);
    }
  }

  Future<void> _openLlamaDirectory() async {
    await _openModelDirectory('${_llama['dir'] ?? ''}', 'Llama');
  }

  Future<void> _openModelDirectory(String rawPath, String name) async {
    final path = rawPath.trim();
    if (path.isEmpty || !Directory(path).existsSync()) {
      _toast(
        path.isEmpty
            ? appL10n.modelPathMissing(name)
            : appL10n.modelPathNotFound(name, path),
      );
      return;
    }
    try {
      if (Platform.isWindows) {
        await Process.start('explorer.exe', [
          path,
        ], mode: ProcessStartMode.detached);
      } else if (Platform.isMacOS) {
        await Process.start('open', [path], mode: ProcessStartMode.detached);
      } else {
        await Process.start('xdg-open', [
          path,
        ], mode: ProcessStartMode.detached);
      }
    } catch (e) {
      _toast(appL10n.modelPathOpenFailed(name, e));
    }
  }

  Future<void> _queryOpenAi({required bool correct}) async {
    final base = (correct ? correctBase : transBase).text.trim();
    final key = (correct ? correctKey : transKey).text.trim();
    if (base.isEmpty) {
      _toast(appL10n.apiUrlRequired);
      return;
    }
    setState(() {
      if (correct) {
        queryingCorrect = true;
      } else {
        queryingTranslate = true;
      }
    });
    try {
      final models = await widget.app.engine.listOpenAiModels(
        baseUrl: base,
        apiKey: key,
        kind: correct ? 'correct' : 'translate',
      );
      setState(() {
        if (correct) {
          correctModels = models;
          if (correctModel.text.trim().isEmpty && models.isNotEmpty) {
            correctModel.text = models.first;
          }
        } else {
          translateModels = models;
          if (transModel.text.trim().isEmpty && models.isNotEmpty) {
            transModel.text = models.first;
          }
        }
      });
      _toast(appL10n.modelsFetched(models.length));
    } catch (e) {
      _toast(appL10n.modelListFailed(e));
    } finally {
      if (mounted) {
        setState(() {
          queryingCorrect = false;
          queryingTranslate = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.app,
      builder: (context, _) {
        final asrModels = _ids(_asr['models']);
        final asrAligners = _ids(_asr['aligners']);
        final backends = _ids(_asr['backends']);
        final llamaModels = _ids(_llama['models']);
        final llamaLabels = _labels(_llama['models']);
        const fallbackBackends = [
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
        ];
        final sourceLangs = _ids(widget.app.tools['source_langs']);
        final targetLangs = _ids(widget.app.tools['target_langs']);
        final translators = _ids(widget.app.tools['translators']);
        return KtPage(
          title: context.l10n.models,
          footer: Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: () => _save(),
              child: Text(context.l10n.save),
            ),
          ),
          children: [
            KtSection(
              title: 'ASR',
              icon: Icons.graphic_eq,
              children: [
                KtComboField(
                  controller: asrModel,
                  label: context.l10n.modelFile,
                  hint: context.l10n.asrModelHint,
                  options: asrModels,
                ),
                KtComboField(
                  controller: asrAligner,
                  label: 'Aligner',
                  hint: 'forced-aligner gguf',
                  options: asrAligners,
                ),
                KtComboField(
                  controller: asrBackend,
                  label: 'backend',
                  hint: 'qwen3-1.7b',
                  options: backends.isEmpty ? fallbackBackends : backends,
                ),
                KtComboField(
                  controller: asrLang,
                  label: context.l10n.sourceLanguage,
                  hint: 'ja',
                  options: sourceLangs.isEmpty
                      ? const ['ja', 'en', 'zh', 'ko', 'ru', 'fr', 'auto']
                      : sourceLangs,
                  labels: _labels(
                    widget.app.tools['source_langs'],
                    catalog: true,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        TextButton.icon(
                          onPressed: queryingAsr ? null : _queryAsr,
                          icon: queryingAsr
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.refresh, size: 16),
                          label: Text(
                            queryingAsr
                                ? context.l10n.scanning
                                : context.l10n.queryModels,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _openAsrDirectory,
                          icon: const Icon(Icons.folder_open, size: 16),
                          label: Text(context.l10n.openModelPath),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            KtSection(
              title: context.l10n.localLlama,
              icon: Icons.memory_outlined,
              action: Tooltip(
                message: context.l10n.localLlamaDescription,
                child: Icon(
                  Icons.info_outline,
                  size: 18,
                  color: paletteOf(context).muted,
                ),
              ),
              children: [
                KtComboField(
                  controller: llamaModel,
                  label: context.l10n.modelFile,
                  hint: context.l10n.llamaModelHint,
                  options: llamaModels,
                  labels: llamaLabels,
                  onChanged: (_) => setState(() {}),
                ),
                KtRow(
                  icon: Icons.lan_outlined,
                  title: context.l10n.fixedPort,
                  sub: '127.0.0.1:${_llama['port'] ?? 18766}',
                  trailing: Text(switch (_llama['status'] ?? 'stopped') {
                    'stopped' => context.l10n.llamaStopped,
                    'starting' => context.l10n.llamaStarting,
                    'ready' => context.l10n.llamaReady,
                    'busy' => context.l10n.statusRunning,
                    'error' => context.l10n.statusFailed,
                    final value => '$value',
                  }),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        TextButton.icon(
                          onPressed: queryingLlama ? null : _queryLlama,
                          icon: queryingLlama
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.refresh, size: 16),
                          label: Text(
                            queryingLlama
                                ? context.l10n.scanning
                                : context.l10n.queryModels,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _openLlamaDirectory,
                          icon: const Icon(Icons.folder_open, size: 16),
                          label: Text(context.l10n.openModelPath),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            KtSection(
              title: context.l10n.correction,
              icon: Icons.auto_fix_high,
              children: [
                KtSelectField<String>(
                  label: context.l10n.connectionMode,
                  value: correctProvider,
                  values: const ['online', 'local_llama'],
                  labelOf: (value) => value == 'local_llama'
                      ? context.l10n.localLlama
                      : context.l10n.online,
                  onChanged: (value) => setState(() => correctProvider = value),
                ),
                if (correctProvider == 'local_llama') ...[
                  KtRow(
                    icon: Icons.memory,
                    title: context.l10n.sharedModel,
                    sub: llamaModel.text.trim().isEmpty
                        ? context.l10n.noModelSelected
                        : llamaModel.text.trim(),
                    trailing: Text('127.0.0.1:${_llama['port'] ?? 18766}'),
                    showDivider: false,
                  ),
                ] else ...[
                  KtField(
                    controller: correctBase,
                    label: context.l10n.apiUrl,
                    hint: 'https://example.com/v1',
                  ),
                  KtComboField(
                    controller: correctModel,
                    label: context.l10n.modelName,
                    options: correctModels,
                  ),
                  KtField(
                    controller: correctKey,
                    label: 'API Key',
                    obscure: true,
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: queryingCorrect
                            ? null
                            : () => _queryOpenAi(correct: true),
                        icon: queryingCorrect
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.travel_explore, size: 16),
                        label: Text(
                          queryingCorrect
                              ? context.l10n.querying
                              : context.l10n.queryModels,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            KtSection(
              title: context.l10n.translation,
              icon: Icons.translate_outlined,
              children: [
                KtSelectField<String>(
                  label: context.l10n.connectionMode,
                  value: translateProvider,
                  values: const ['online', 'local_llama'],
                  labelOf: (value) => value == 'local_llama'
                      ? context.l10n.localLlama
                      : context.l10n.online,
                  onChanged: (value) =>
                      setState(() => translateProvider = value),
                ),
                KtComboField(
                  controller: translator,
                  label: context.l10n.translator,
                  hint: 'ForGal-json',
                  options: translators.isEmpty
                      ? const [
                          'ForGal-json',
                          'ForNovel',
                          'ForGal-tsv',
                          'galtransl-v3',
                          'sakura-v1.0',
                        ]
                      : translators,
                  labels: _labels(
                    widget.app.tools['translators'],
                    catalog: true,
                  ),
                ),
                if (translateProvider == 'local_llama')
                  KtRow(
                    icon: Icons.memory,
                    title: context.l10n.sharedModel,
                    sub: llamaModel.text.trim().isEmpty
                        ? context.l10n.noModelSelected
                        : llamaModel.text.trim(),
                    trailing: Text('127.0.0.1:${_llama['port'] ?? 18766}'),
                  )
                else ...[
                  KtSwitchRow(
                    icon: Icons.hub_outlined,
                    title: context.l10n.indexCompatibility,
                    sub: context.l10n.indexCompatibilityDescription,
                    value: indexModelCompat,
                    onChanged: (value) =>
                        setState(() => indexModelCompat = value),
                  ),
                  KtField(controller: transBase, label: context.l10n.openAiUrl),
                  KtComboField(
                    controller: transModel,
                    label: context.l10n.modelName,
                    options: translateModels,
                  ),
                  KtField(
                    controller: transKey,
                    label: 'API Key',
                    obscure: true,
                  ),
                ],
                KtComboField(
                  controller: targetLang,
                  label: context.l10n.targetLanguage,
                  hint: 'zh-cn',
                  options: targetLangs.isEmpty
                      ? const ['zh-cn', 'zh-tw', 'en', 'ja', 'ko', 'ru', 'fr']
                      : targetLangs,
                  labels: _labels(
                    widget.app.tools['target_langs'],
                    catalog: true,
                  ),
                ),
                if (translateProvider == 'online')
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: queryingTranslate
                            ? null
                            : () => _queryOpenAi(correct: false),
                        icon: queryingTranslate
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.travel_explore, size: 16),
                        label: Text(
                          queryingTranslate
                              ? context.l10n.querying
                              : context.l10n.queryModels,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}
