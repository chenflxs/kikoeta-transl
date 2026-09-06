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
  late String promptMode;
  bool settingsSynced = false;

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
      text: _text(correct['max_tokens'], '0'),
    );
    translatePrompt = TextEditingController(
      text: '${translate['prompt'] ?? ''}',
    );
    contextNum = TextEditingController(
      text: _text(translate['context_num'], '8'),
    );
    batchSize = TextEditingController(
      text: _text(translate['batch_size'], '16'),
    );
    tokenLimit = TextEditingController(
      text: _text(translate['token_limit'], '0'),
    );
    promptMode = '${translate['prompt_mode'] ?? 'append'}' == 'overwrite'
        ? 'overwrite'
        : 'append';
    widget.app.addListener(_syncSettings);
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncSettings());
  }

  void _syncSettings() {
    if (!mounted || settingsSynced || widget.app.settings.isEmpty) return;
    final settings = widget.app.settings;
    final correct = (settings['correct'] as Map?) ?? {};
    final translate = (settings['translate'] as Map?) ?? {};
    settingsSynced = true;
    setState(() {
      correctPrompt.text = '${correct['prompt'] ?? ''}';
      correctTemperature.text = _text(correct['temperature'], '0.2');
      correctMaxTokens.text = _text(correct['max_tokens'], '0');
      translatePrompt.text = '${translate['prompt'] ?? ''}';
      contextNum.text = _text(translate['context_num'], '8');
      batchSize.text = _text(translate['batch_size'], '16');
      tokenLimit.text = _text(translate['token_limit'], '0');
      promptMode = '${translate['prompt_mode'] ?? 'append'}' == 'overwrite'
          ? 'overwrite'
          : 'append';
    });
  }

  @override
  void dispose() {
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

  Future<void> _save() async {
    final next = Map<String, dynamic>.from(widget.app.settings);
    next['correct'] = {
      ...(next['correct'] as Map? ?? {}),
      'prompt': correctPrompt.text,
      'temperature': _double(correctTemperature.text, 0.2),
      'max_tokens': _int(correctMaxTokens.text, 0),
    };
    next['translate'] = {
      ...(next['translate'] as Map? ?? {}),
      'prompt_mode': promptMode,
      'prompt': translatePrompt.text,
      'context_num': _int(contextNum.text, 8),
      'batch_size': _int(batchSize.text, 16),
      'token_limit': _int(tokenLimit.text, 0),
    };
    await widget.app.persistSettings(next);
    if (mounted) {
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
              hint: '0 表示不限制',
              maxLines: 1,
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
            KtField(controller: contextNum, label: '上下文句数', hint: '8'),
            KtField(controller: batchSize, label: '单次翻译句数', hint: '16'),
            KtField(controller: tokenLimit, label: 'Token 上限', hint: '0 表示不限制'),
          ],
        ),
        const SizedBox(height: 14),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton(onPressed: _save, child: const Text('保存')),
        ),
      ],
    );
  }
}
