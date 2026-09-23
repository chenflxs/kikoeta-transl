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
  String correctProvider = 'online';
  String translateProvider = 'online';

  @override
  void initState() {
    super.initState();
    final s = widget.app.settings;
    final asr = (s['asr'] as Map?) ?? {};
    final correct = (s['correct'] as Map?) ?? {};
    final translate = (s['translate'] as Map?) ?? {};
    // 不从本地设置回填 API 地址、模型名或密钥。
    asrModel = TextEditingController(text: '${asr['model'] ?? ''}');
    asrAligner = TextEditingController(text: '${asr['aligner'] ?? ''}');
    asrBackend = TextEditingController(
      text: '${asr['backend'] ?? 'qwen3-1.7b'}',
    );
    asrLang = TextEditingController(text: '${s['source_lang'] ?? 'ja'}');
    llamaModel = TextEditingController(text: '${s['llama_model'] ?? ''}');
    correctProvider = _provider('${correct['provider'] ?? 'online'}');
    translateProvider = _provider('${translate['provider'] ?? 'online'}');
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
    widget.app.addListener(_syncLocalModelsFromTools);
    widget.app.addListener(_syncSettings);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _syncLocalModelsFromTools(),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncSettings());
  }

  void _syncLocalModelsFromTools() {
    if (!mounted) return;
    final models = _ids(_asr['models']);
    final aligners = _ids(_asr['aligners']);
    final llamaModels = _ids(_llama['models']);
    var changed = false;
    if (asrModel.text.trim().isEmpty && models.isNotEmpty) {
      asrModel.text = models.first;
      changed = true;
    }
    if (asrAligner.text.trim().isEmpty && aligners.isNotEmpty) {
      asrAligner.text = aligners.first;
      changed = true;
    }
    if (llamaModel.text.trim().isEmpty && llamaModels.isNotEmpty) {
      llamaModel.text = llamaModels.first;
      changed = true;
    }
    if (changed) setState(() {});
  }

  void _syncSettings() {
    if (!mounted || settingsSynced || widget.app.settings.isEmpty) return;
    final s = widget.app.settings;
    final asr = (s['asr'] as Map?) ?? {};
    final correct = (s['correct'] as Map?) ?? {};
    final translate = (s['translate'] as Map?) ?? {};
    settingsSynced = true;
    setState(() {
      asrModel.text = '${asr['model'] ?? ''}';
      asrAligner.text = '${asr['aligner'] ?? ''}';
      asrBackend.text = '${asr['backend'] ?? 'qwen3-1.7b'}';
      asrLang.text = '${s['source_lang'] ?? asr['language'] ?? 'ja'}';
      llamaModel.text = '${s['llama_model'] ?? ''}';
      correctProvider = _provider('${correct['provider'] ?? 'online'}');
      translateProvider = _provider('${translate['provider'] ?? 'online'}');
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
    widget.app.removeListener(_syncLocalModelsFromTools);
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
    next['llama_model'] = llamaModel.text.trim();
    next['asr'] = {
      ...(next['asr'] as Map? ?? {}),
      'model': asrModel.text.trim(),
      'aligner': asrAligner.text.trim(),
      'backend': asrBackend.text.trim(),
      'language': asrLang.text.trim(),
    };
    final correct = Map<String, dynamic>.from(next['correct'] as Map? ?? {});
    correct['provider'] = correctProvider;
    if (correctProvider == 'online') {
      if (correctBase.text.trim().isNotEmpty) {
        correct['base_url'] = correctBase.text.trim();
      }
      if (correctModel.text.trim().isNotEmpty) {
        correct['model'] = correctModel.text.trim();
      }
      if (correctKey.text.trim().isNotEmpty) {
        correct['api_key'] = correctKey.text.trim();
      }
    }
    next['correct'] = correct;
    final translate = Map<String, dynamic>.from(
      next['translate'] as Map? ?? {},
    );
    translate['provider'] = translateProvider;
    translate['translator'] = translator.text.trim();
    if (translateProvider == 'online') {
      final openai = Map<String, dynamic>.from(
        translate['openai'] as Map? ?? {},
      );
      if (transBase.text.trim().isNotEmpty) {
        openai['base_url'] = transBase.text.trim();
      }
      if (transModel.text.trim().isNotEmpty) {
        openai['model'] = transModel.text.trim();
      }
      if (transKey.text.trim().isNotEmpty) {
        openai['api_key'] = transKey.text.trim();
      }
      translate['openai'] = openai;
    }
    next['translate'] = translate;
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
    await _openModelDirectory('${_asr['dir'] ?? ''}', 'ASR');
  }

  Future<void> _queryLlama() async {
    setState(() => queryingLlama = true);
    try {
      await widget.app.refreshTools();
      final models = _ids(_llama['models']);
      if (!models.contains(llamaModel.text.trim())) {
        llamaModel.text = models.isEmpty ? '' : models.first;
      }
      final dir = '${_llama['dir'] ?? ''}';
      if (models.isEmpty) {
        _toast(dir.isEmpty ? '未扫描到 Llama 模型' : '未扫描到 Llama 模型：$dir');
      } else {
        _toast('已扫描到 ${models.length} 个 Llama 模型');
      }
    } catch (e) {
      _toast('Llama 模型刷新失败：$e');
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
      _toast(path.isEmpty ? '未获取到 $name 模型路径' : '$name 模型路径不存在：$path');
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
      _toast('无法打开 $name 模型路径：$e');
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
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
              child: Row(
                children: [
                  Text(
                    '本地 Llama',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: .5,
                      color: paletteOf(context).muted,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Tooltip(
                    message:
                        '本项目以单模型模式运行 llama-server，同一时间只挂载一个 GGUF 模型。'
                        '矫正和翻译选择“本地”时，将共同使用此处选择的模型。切换模型后，'
                        'llama-server 会在下一次本地任务开始前重新启动。',
                    child: Icon(Icons.error_outline, size: 16),
                  ),
                ],
              ),
            ),
            KtGroup(
              children: [
                KtComboField(
                  controller: llamaModel,
                  label: '模型文件',
                  hint: 'bin/llama 下的 GGUF 文件名',
                  options: llamaModels,
                  labels: llamaLabels,
                  onChanged: (_) => setState(() {}),
                ),
                KtRow(
                  icon: Icons.lan_outlined,
                  title: '固定端口',
                  sub: '127.0.0.1:${_llama['port'] ?? 18766}',
                  trailing: Text('${_llama['status'] ?? 'stopped'}'),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
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
                          label: Text(queryingLlama ? '正在扫描…' : '查询模型列表'),
                        ),
                        const SizedBox(width: 8),
                        TextButton.icon(
                          onPressed: _openLlamaDirectory,
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
                KtSelectField<String>(
                  label: '连接方式',
                  value: correctProvider,
                  values: const ['online', 'local_llama'],
                  labelOf: (value) =>
                      value == 'local_llama' ? '本地 Llama' : '在线',
                  onChanged: (value) => setState(() => correctProvider = value),
                ),
                if (correctProvider == 'local_llama') ...[
                  KtRow(
                    icon: Icons.memory,
                    title: '共享模型',
                    sub: llamaModel.text.trim().isEmpty
                        ? '尚未选择模型'
                        : llamaModel.text.trim(),
                    trailing: Text('127.0.0.1:${_llama['port'] ?? 18766}'),
                    showDivider: false,
                  ),
                ] else ...[
                  KtField(
                    controller: correctBase,
                    label: 'API 地址',
                    hint: 'https://example.com/v1',
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
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.travel_explore, size: 16),
                        label: Text(queryingCorrect ? '正在查询…' : '查询模型列表'),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SectionTitle('翻译'),
            KtGroup(
              children: [
                KtSelectField<String>(
                  label: '连接方式',
                  value: translateProvider,
                  values: const ['online', 'local_llama'],
                  labelOf: (value) =>
                      value == 'local_llama' ? '本地 Llama' : '在线',
                  onChanged: (value) =>
                      setState(() => translateProvider = value),
                ),
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
                if (translateProvider == 'local_llama')
                  KtRow(
                    icon: Icons.memory,
                    title: '共享模型',
                    sub: llamaModel.text.trim().isEmpty
                        ? '尚未选择模型'
                        : llamaModel.text.trim(),
                    trailing: Text('127.0.0.1:${_llama['port'] ?? 18766}'),
                  )
                else ...[
                  KtField(controller: transBase, label: 'OpenAI 兼容地址'),
                  KtComboField(
                    controller: transModel,
                    label: '模型名',
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
                  label: '目标语言',
                  hint: 'zh-cn',
                  options: targetLangs.isEmpty
                      ? const ['zh-cn', 'zh-tw', 'en', 'ja', 'ko', 'ru', 'fr']
                      : targetLangs,
                  labels: _labels(widget.app.tools['target_langs']),
                ),
                if (translateProvider == 'online')
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
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
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
