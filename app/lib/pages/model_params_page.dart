import 'dart:convert';

import 'package:flutter/material.dart';

import '../app_state.dart';
import '../widgets.dart';

class ModelParamsPage extends StatefulWidget {
  final AppState app;
  const ModelParamsPage({super.key, required this.app});

  @override
  State<ModelParamsPage> createState() => _ModelParamsPageState();
}

class _ModelParamsPageState extends State<ModelParamsPage> {
  late final TextEditingController correctPrompt;
  late final TextEditingController correctTemperature;
  late final TextEditingController correctMaxTokens;
  late final TextEditingController translatePrompt;
  late final TextEditingController contextNum;
  late final TextEditingController batchSize;
  late final TextEditingController tokenLimit;
  bool correctThinkingEnabled = false;
  bool translateThinkingEnabled = true;
  late String promptMode;
  bool settingsSynced = false;
  late String _savedDraft;
  late final VoidCallback _unregisterPageSaver;

  @override
  void initState() {
    super.initState();
    final settings = widget.app.settings;
    final correct = (settings['correct'] as Map?) ?? {};
    final translate = (settings['translate'] as Map?) ?? {};
    correctPrompt = TextEditingController(text: '${correct['prompt'] ?? ''}');
    correctTemperature = TextEditingController(
      text: _text(correct['temperature'], '0.2'),
    );
    correctMaxTokens = TextEditingController(
      text: _text(correct['max_tokens'], '4096'),
    );
    correctThinkingEnabled = _boolValue(correct['enable_thinking'], false);
    translatePrompt = TextEditingController(
      text: '${translate['prompt'] ?? ''}',
    );
    contextNum = TextEditingController(
      text: _text(translate['context_num'], '10'),
    );
    batchSize = TextEditingController(
      text: _text(translate['batch_size'], '10'),
    );
    tokenLimit = TextEditingController(
      text: _text(translate['token_limit'], '1024'),
    );
    translateThinkingEnabled = _boolValue(translate['enable_thinking'], true);
    promptMode = '${translate['prompt_mode'] ?? 'append'}' == 'overwrite'
        ? 'overwrite'
        : 'append';
    _savedDraft = _draft();
    _unregisterPageSaver = widget.app.registerPageSaver(
      3,
      () => _save(auto: true),
    );
    widget.app.addListener(_syncSettings);
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncSettings());
  }

  void _syncSettings() {
    if (!mounted || settingsSynced || widget.app.settings.isEmpty) return;
    if (_draft() != _savedDraft) {
      settingsSynced = true;
      return;
    }
    final settings = widget.app.settings;
    final correct = (settings['correct'] as Map?) ?? {};
    final translate = (settings['translate'] as Map?) ?? {};
    settingsSynced = true;
    setState(() {
      correctPrompt.text = '${correct['prompt'] ?? ''}';
      correctTemperature.text = _text(correct['temperature'], '0.2');
      correctMaxTokens.text = _text(correct['max_tokens'], '4096');
      correctThinkingEnabled = _boolValue(correct['enable_thinking'], false);
      translatePrompt.text = '${translate['prompt'] ?? ''}';
      contextNum.text = _text(translate['context_num'], '10');
      batchSize.text = _text(translate['batch_size'], '10');
      tokenLimit.text = _text(translate['token_limit'], '1024');
      translateThinkingEnabled = _boolValue(translate['enable_thinking'], true);
      promptMode = '${translate['prompt_mode'] ?? 'append'}' == 'overwrite'
          ? 'overwrite'
          : 'append';
    });
    _savedDraft = _draft();
  }

  String _draft() => jsonEncode([
    correctPrompt.text,
    correctTemperature.text,
    correctMaxTokens.text,
    correctThinkingEnabled,
    translatePrompt.text,
    contextNum.text,
    batchSize.text,
    tokenLimit.text,
    translateThinkingEnabled,
    promptMode,
  ]);

  @override
  void dispose() {
    _unregisterPageSaver();
    widget.app.removeListener(_syncSettings);
    correctPrompt.dispose();
    correctTemperature.dispose();
    correctMaxTokens.dispose();
    translatePrompt.dispose();
    contextNum.dispose();
    batchSize.dispose();
    tokenLimit.dispose();
    super.dispose();
  }

  String _text(Object? value, String fallback) {
    final text = '${value ?? ''}'.trim();
    return text.isEmpty ? fallback : text;
  }

  double _double(String raw, double fallback) =>
      double.tryParse(raw.trim()) ?? fallback;

  int _int(String raw, int fallback) => int.tryParse(raw.trim()) ?? fallback;

  bool _boolValue(Object? value, bool fallback) {
    if (value is bool) return value;
    final text = '${value ?? ''}'.trim().toLowerCase();
    if (text == 'true' || text == '1' || text == 'yes' || text == 'on') {
      return true;
    }
    if (text == 'false' || text == '0' || text == 'no' || text == 'off') {
      return false;
    }
    return fallback;
  }

  Future<void> _save({bool auto = false}) async {
    final draft = _draft();
    if (auto && draft == _savedDraft) return;
    final correctPromptValue = correctPrompt.text;
    final temperature = _double(correctTemperature.text, 0.2);
    final maxTokens = _int(correctMaxTokens.text, 4096);
    final correctThinking = correctThinkingEnabled;
    final translatePromptValue = translatePrompt.text;
    final contextCount = _int(contextNum.text, 10);
    final batch = _int(batchSize.text, 10);
    final tokens = _int(tokenLimit.text, 1024);
    final translateThinking = translateThinkingEnabled;
    final mode = promptMode;
    await widget.app.updateSettings((next) {
      next['correct'] = {
        ...(next['correct'] as Map? ?? {}),
        'prompt': correctPromptValue,
        'temperature': temperature,
        'max_tokens': maxTokens,
        'enable_thinking': correctThinking,
      };
      next['translate'] = {
        ...(next['translate'] as Map? ?? {}),
        'prompt_mode': mode,
        'prompt': translatePromptValue,
        'context_num': contextCount,
        'batch_size': batch,
        'token_limit': tokens,
        'enable_thinking': translateThinking,
      };
    });
    _savedDraft = draft;
    if (!auto && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('模型参数已保存')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = paletteOf(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 24),
      children: [
        const Text(
          '模型参数',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          '配置矫正模型与翻译模型的提示词及请求参数。',
          style: TextStyle(fontSize: 12, color: p.muted),
        ),
        const SectionTitle('矫正'),
        KtGroup(
          children: [
            KtField(
              controller: correctPrompt,
              label: '校对系统 Prompt',
              hint: '留空则使用内置 ASR 校对提示词',
              maxLines: 6,
            ),
            KtField(
              controller: correctTemperature,
              label: 'temperature',
              hint: '0.2',
            ),
            KtField(
              controller: correctMaxTokens,
              label: 'max_tokens',
              hint: '4096',
              maxLines: 1,
            ),
            KtSwitchRow(
              icon: Icons.psychology,
              title: '启用思考/推理',
              sub: '关闭后请求会发送 thinking.type=disabled（接口支持时生效）',
              value: correctThinkingEnabled,
              onChanged: (value) =>
                  setState(() => correctThinkingEnabled = value),
            ),
          ],
        ),
        const SectionTitle('翻译'),
        KtGroup(
          children: [
            KtSelectField<String>(
              label: 'Prompt 工作模式',
              value: promptMode,
              values: const ['append', 'overwrite'],
              labelOf: (value) =>
                  value == 'append' ? '衔接到默认提示词尾部' : '直接覆盖默认提示词',
              onChanged: (value) => setState(() => promptMode = value),
            ),
            KtField(
              controller: translatePrompt,
              label: '翻译 Prompt',
              hint: '留空则不修改默认提示词',
              maxLines: 8,
            ),
            KtField(controller: contextNum, label: '上下文句数', hint: '10'),
            KtField(controller: batchSize, label: '单次翻译句数', hint: '10'),
            KtField(controller: tokenLimit, label: 'Token 上限', hint: '1024'),
            KtSwitchRow(
              icon: Icons.psychology,
              title: '启用思考/推理',
              sub: '关闭后请求会发送 thinking.type=disabled（接口支持时生效）',
              value: translateThinkingEnabled,
              onChanged: (value) =>
                  setState(() => translateThinkingEnabled = value),
              showDivider: false,
            ),
          ],
        ),
        const SizedBox(height: 14),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton(
            onPressed: () => _save(),
            child: const Text('保存'),
          ),
        ),
      ],
    );
  }
}
