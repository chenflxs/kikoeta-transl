import 'dart:convert';

import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../app_state.dart';
import '../settings_draft.dart';
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
  bool indexModelCompat = false;
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
    indexModelCompat = _boolValue(translate['index_compat'], false);
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
    final settings = widget.app.settings;
    final correct = (settings['correct'] as Map?) ?? {};
    final translate = (settings['translate'] as Map?) ?? {};
    final merged = mergeLoadedSettingsDraft(_savedDraft, _draftValues(), {
      'correctPrompt': '${correct['prompt'] ?? ''}',
      'correctTemperature': _text(correct['temperature'], '0.2'),
      'correctMaxTokens': _text(correct['max_tokens'], '4096'),
      'correctThinking': _boolValue(correct['enable_thinking'], false),
      'translatePrompt': '${translate['prompt'] ?? ''}',
      'contextNum': _text(translate['context_num'], '10'),
      'batchSize': _text(translate['batch_size'], '10'),
      'tokenLimit': _text(translate['token_limit'], '1024'),
      'translateThinking': _boolValue(translate['enable_thinking'], true),
      'indexModelCompat': _boolValue(translate['index_compat'], false),
      'promptMode': '${translate['prompt_mode'] ?? 'append'}' == 'overwrite'
          ? 'overwrite'
          : 'append',
    });
    settingsSynced = true;
    setState(() {
      correctPrompt.text = merged.values['correctPrompt'] as String;
      correctTemperature.text = merged.values['correctTemperature'] as String;
      correctMaxTokens.text = merged.values['correctMaxTokens'] as String;
      correctThinkingEnabled = merged.values['correctThinking'] as bool;
      translatePrompt.text = merged.values['translatePrompt'] as String;
      contextNum.text = merged.values['contextNum'] as String;
      batchSize.text = merged.values['batchSize'] as String;
      tokenLimit.text = merged.values['tokenLimit'] as String;
      translateThinkingEnabled = merged.values['translateThinking'] as bool;
      indexModelCompat = merged.values['indexModelCompat'] as bool;
      promptMode = merged.values['promptMode'] as String;
    });
    _savedDraft = merged.baseline;
  }

  Map<String, dynamic> _draftValues() => {
    'correctPrompt': correctPrompt.text,
    'correctTemperature': correctTemperature.text,
    'correctMaxTokens': correctMaxTokens.text,
    'correctThinking': correctThinkingEnabled,
    'translatePrompt': translatePrompt.text,
    'contextNum': contextNum.text,
    'batchSize': batchSize.text,
    'tokenLimit': tokenLimit.text,
    'translateThinking': translateThinkingEnabled,
    'indexModelCompat': indexModelCompat,
    'promptMode': promptMode,
  };

  String _draft() => jsonEncode(_draftValues());

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
    final indexCompat = indexModelCompat;
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
        'index_compat': indexCompat,
      };
    });
    _savedDraft = draft;
    if (!auto && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(appL10n.modelParametersSaved)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return KtPage(
      title: context.l10n.modelParameters,
      description: context.l10n.modelParametersDescription,
      footer: Align(
        alignment: Alignment.centerRight,
        child: FilledButton(
          onPressed: () => _save(),
          child: Text(context.l10n.save),
        ),
      ),
      children: [
        KtSection(
          title: context.l10n.correction,
          icon: Icons.auto_fix_high,
          children: [
            KtField(
              controller: correctPrompt,
              label: context.l10n.correctionPrompt,
              hint: context.l10n.correctionPromptHint,
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
              title: context.l10n.enableThinking,
              sub: context.l10n.thinkingDisabledDescription,
              value: correctThinkingEnabled,
              showDivider: false,
              onChanged: (value) =>
                  setState(() => correctThinkingEnabled = value),
            ),
          ],
        ),
        KtSection(
          title: context.l10n.translation,
          icon: Icons.translate_outlined,
          children: [
            KtSelectField<String>(
              label: context.l10n.promptMode,
              value: promptMode,
              values: const ['append', 'overwrite'],
              labelOf: (value) => value == 'append'
                  ? context.l10n.appendPrompt
                  : context.l10n.overwritePrompt,
              onChanged: (value) => setState(() => promptMode = value),
            ),
            KtField(
              controller: translatePrompt,
              label: context.l10n.translationPrompt,
              hint: context.l10n.translationPromptHint,
              maxLines: 8,
            ),
            KtField(
              controller: contextNum,
              label: context.l10n.contextSentences,
              hint: '10',
            ),
            KtField(
              controller: batchSize,
              label: context.l10n.batchSentences,
              hint: '10',
            ),
            KtField(
              controller: tokenLimit,
              label: context.l10n.tokenLimit,
              hint: '1024',
            ),
            KtSwitchRow(
              icon: Icons.psychology,
              title: context.l10n.enableThinking,
              sub: indexModelCompat
                  ? context.l10n.indexThinkingDisabled
                  : context.l10n.thinkingDisabledDescription,
              value: indexModelCompat ? false : translateThinkingEnabled,
              enabled: !indexModelCompat,
              onChanged: (value) =>
                  setState(() => translateThinkingEnabled = value),
              showDivider: false,
            ),
          ],
        ),
      ],
    );
  }
}
