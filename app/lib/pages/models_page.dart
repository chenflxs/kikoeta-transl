import 'dart:io';

import 'package:flutter/material.dart';

import '../app_state.dart';
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
  bool queryingCorrect = false;
  bool queryingTranslate = false;
  bool settingsSynced = false;

  @override
  void initState() {
    super.initState();
    final s = widget.app.settings;
    final asr = (s['asr'] as Map?) ?? {};
    final translate = (s['translate'] as Map?) ?? {};
    // 不从本地设置回填 API 地址、模型名或密钥。
    asrModel = TextEditingController(text: '${asr['model'] ?? ''}');
    asrAligner = TextEditingController(text: '${asr['aligner'] ?? ''}');
    asrBackend = TextEditingController(
      text: '${asr['backend'] ?? 'qwen3-1.7b'}',
    );
    asrLang = TextEditingController(text: '${s['source_lang'] ?? 'ja'}');
    correctBase = TextEditingController();
    correctModel = TextEditingController();
    correctKey = TextEditingController();
    transBase = TextEditingController();
    transModel = TextEditingController();
    transKey = TextEditingController();
    translator = TextEditingController(
      text: '${translate['translator'] ?? 'ForGal-json'}',
    );
    targetLang = TextEditingController(text: '${s['target_lang'] ?? 'zh-cn'}');
    widget.app.addListener(_syncAsrFromTools);
    widget.app.addListener(_syncSettings);
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncAsrFromTools());
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncSettings());
  }

  void _syncAsrFromTools() {
    if (!mounted) return;
    final models = _ids(_asr['models']);
    final aligners = _ids(_asr['aligners']);
    var changed = false;
    if (asrModel.text.trim().isEmpty && models.isNotEmpty) {
      asrModel.text = models.first;
      changed = true;
    }
    if (asrAligner.text.trim().isEmpty && aligners.isNotEmpty) {
      asrAligner.text = aligners.first;
      changed = true;
    }
    if (changed) setState(() {});
  }

  void _syncSettings() {
    if (!mounted || settingsSynced || widget.app.settings.isEmpty) return;
    final s = widget.app.settings;
    final asr = (s['asr'] as Map?) ?? {};
    final translate = (s['translate'] as Map?) ?? {};
    settingsSynced = true;
    setState(() {
      asrModel.text = '${asr['model'] ?? ''}';
      asrAligner.text = '${asr['aligner'] ?? ''}';
      asrBackend.text = '${asr['backend'] ?? 'qwen3-1.7b'}';
      asrLang.text = '${s['source_lang'] ?? asr['language'] ?? 'ja'}';
      correctBase.clear();
      correctModel.clear();
      correctKey.clear();
      transBase.clear();
      transModel.clear();
      transKey.clear();
      translator.text = '${translate['translator'] ?? 'ForGal-json'}';
      targetLang.text = '${s['target_lang'] ?? 'zh-cn'}';
    });
  }

  @override
  void dispose() {
    widget.app.removeListener(_syncAsrFromTools);
    widget.app.removeListener(_syncSettings);
    asrModel.dispose();
    asrAligner.dispose();
    asrBackend.dispose();
    asrLang.dispose();
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

  Map<String, String> _labels(dynamic raw) {
    if (raw is! List) return const {};
    final out = <String, String>{};
    for (final item in raw) {
      if (item is Map) {
        final id = '${item['id'] ?? ''}'.trim();
        final label = '${item['label'] ?? id}'.trim();
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

  Future<void> _save() async {
    final next = Map<String, dynamic>.from(widget.app.settings);
    next['source_lang'] = asrLang.text.trim();
    next['target_lang'] = targetLang.text.trim();
    next['asr'] = {
      ...(next['asr'] as Map? ?? {}),
      'model': asrModel.text.trim(),
      'aligner': asrAligner.text.trim(),
      'backend': asrBackend.text.trim(),
      'language': asrLang.text.trim(),
    };
    next['correct'] = {
      ...(next['correct'] as Map? ?? {}),
      'base_url': correctBase.text.trim(),
      'model': correctModel.text.trim(),
      'api_key': correctKey.text.trim(),
    };
    next['translate'] = {
      ...(next['translate'] as Map? ?? {}),
      'translator': translator.text.trim(),
      'openai': {
        'base_url': transBase.text.trim(),
        'model': transModel.text.trim(),
        'api_key': transKey.text.trim(),
      },
    };
    await widget.app.persistSettings(next);
    _toast('模型设置已保存');
  }

  Future<void> _queryAsr() async {
    setState(() => queryingAsr = true);
    try {
      await widget.app.refreshTools();
      final models = _ids(_asr['models']);
      final aligners = _ids(_asr['aligners']);
      if (asrModel.text.trim().isEmpty && models.isNotEmpty) {
        asrModel.text = models.first;
      }
      if (asrAligner.text.trim().isEmpty && aligners.isNotEmpty) {
        asrAligner.text = aligners.first;
      }
      final dir = '${_asr['dir'] ?? ''}';
      if (models.isEmpty) {
        _toast(dir.isEmpty ? '未扫描到 ASR 模型' : '未扫描到 ASR 模型：$dir');
      } else {
        _toast('已扫描到 ${models.length} 个 ASR 模型');
      }
    } catch (e) {
      _toast('ASR 模型刷新失败：$e');
    } finally {
      if (mounted) setState(() => queryingAsr = false);
    }
  }

  Future<void> _openAsrDirectory() async {
    final path = '${_asr['dir'] ?? ''}'.trim();
    if (path.isEmpty || !Directory(path).existsSync()) {
      _toast(path.isEmpty ? '未获取到 ASR 模型路径' : 'ASR 模型路径不存在：$path');
      return;
    }
    try {
      if (Platform.isWindows) {
        await Process.start(
          'explorer.exe',
          [path],
          mode: ProcessStartMode.detached,
        );
      } else if (Platform.isMacOS) {
        await Process.start('open', [path], mode: ProcessStartMode.detached);
      } else {
        await Process.start(
          'xdg-open',
          [path],
          mode: ProcessStartMode.detached,
        );
      }
    } catch (e) {
      _toast('无法打开 ASR 模型路径：$e');
    }
  }

  Future<void> _queryOpenAi({required bool correct}) async {
    final base = (correct ? correctBase : transBase).text.trim();
    final key = (correct ? correctKey : transKey).text.trim();
    if (base.isEmpty) {
      _toast('请先填写 API 地址');
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
      _toast('已获取 ${models.length} 个模型');
    } catch (e) {
      _toast('模型列表获取失败：$e');
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
        return ListView(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 24),
          children: [
            const Text(
              '模型',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SectionTitle('ASR'),
            KtGroup(
              children: [
                KtComboField(
                  controller: asrModel,
                  label: '模型文件',
                  hint: 'bin/crispasr 下的 gguf 文件名',
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
                  label: '源语言',
                  hint: 'ja',
                  options: sourceLangs.isEmpty
                      ? const ['ja', 'en', 'zh', 'ko', 'ru', 'fr', 'auto']
                      : sourceLangs,
                  labels: _labels(widget.app.tools['source_langs']),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
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
                          label: Text(queryingAsr ? '正在扫描…' : '查询模型列表'),
                        ),
                        const SizedBox(width: 8),
                        TextButton.icon(
                          onPressed: _openAsrDirectory,
                          icon: const Icon(Icons.folder_open, size: 16),
                          label: const Text('打开模型路径'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SectionTitle('小模型矫正'),
            KtGroup(
              children: [
                KtField(
                  controller: correctBase,
                  label: 'API 地址',
                  hint: 'http://127.0.0.1:11434/v1',
                ),
                KtComboField(
                  controller: correctModel,
                  label: '模型名',
                  options: correctModels,
                ),
                KtField(
                  controller: correctKey,
                  label: 'API Key',
                  obscure: true,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
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
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.travel_explore, size: 16),
                      label: Text(queryingCorrect ? '正在查询…' : '查询模型列表'),
                    ),
                  ),
                ),
              ],
            ),
            const SectionTitle('翻译'),
            KtGroup(
              children: [
                KtComboField(
                  controller: translator,
                  label: '翻译器',
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
                  labels: _labels(widget.app.tools['translators']),
                ),
                KtField(controller: transBase, label: 'OpenAI 兼容地址'),
                KtComboField(
                  controller: transModel,
                  label: '模型名',
                  options: translateModels,
                ),
                KtField(controller: transKey, label: 'API Key', obscure: true),
                KtComboField(
                  controller: targetLang,
                  label: '目标语言',
                  hint: 'zh-cn',
                  options: targetLangs.isEmpty
                      ? const ['zh-cn', 'zh-tw', 'en', 'ja', 'ko', 'ru', 'fr']
                      : targetLangs,
                  labels: _labels(widget.app.tools['target_langs']),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
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
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.travel_explore, size: 16),
                      label: Text(queryingTranslate ? '正在查询…' : '查询模型列表'),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton(onPressed: _save, child: const Text('保存')),
            ),
          ],
        );
      },
    );
  }
}
