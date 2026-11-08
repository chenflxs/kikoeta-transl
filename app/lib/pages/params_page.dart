import 'dart:convert';

import 'package:flutter/material.dart';

import '../app_state.dart';
import '../l10n/strings.dart';
import '../settings_draft.dart';
import '../widgets.dart';
import '../widgets/asr_preset_name_dialog.dart';

class ParamsPage extends StatefulWidget {
  final AppState app;
  const ParamsPage({super.key, required this.app});

  @override
  State<ParamsPage> createState() => _ParamsPageState();
}

class _ParamsPageState extends State<ParamsPage> {
  final Map<String, TextEditingController> _fields = {};
  late bool enableVad, splitOnPunct, forceAligner, splitOnWord;
  late bool noFallback, noPunctuation, noGpu, flashAttn;
  bool _syncing = false;
  bool _templateEdited = false;
  bool _settingsSynced = false;
  bool _busy = false;
  bool _presetsNeedSave = false;
  Future<void>? _pendingAction;
  String _selectedPreset = 'qwen3';
  final Map<String, Map<String, dynamic>> _presets = {};
  static const _basePresets = {'qwen3', 'moss'};
  late String _savedDraft;
  late final VoidCallback _unregisterPageSaver;

  TextEditingController field(String name) => _fields[name]!;
  TextEditingController get template => field('template');

  @override
  void initState() {
    super.initState();
    final asr = (widget.app.settings['asr'] as Map?) ?? {};
    final values = _values(asr);
    for (final entry in values.entries) {
      _fields[entry.key] = TextEditingController(text: entry.value)
        ..addListener(_onStructuredChanged);
    }
    _fields['template'] = TextEditingController(
      text: '${asr['extra_args'] ?? ''}'.trim(),
    );
    template.addListener(_onTemplateChanged);
    _loadFlags(asr);
    if (template.text.isEmpty) _setGeneratedTemplate();
    _loadPresets(widget.app.settings, _draftValues());
    _savedDraft = _draft();
    _settingsSynced = widget.app.settings.isNotEmpty;
    _unregisterPageSaver = widget.app.registerPageSaver(
      2,
      () => _save(auto: true),
    );
    widget.app.addListener(_syncSettings);
  }

  Map<String, String> _values(Map asr) => <String, String>{
    'threads': _text(asr['threads'], '4'),
    'processors': _text(asr['processors'], '1'),
    'offset_t': _text(asr['offset_t'], '0'),
    'offset_n': _text(asr['offset_n'], '0'),
    'duration': _text(asr['duration'], '0'),
    'max_context': _text(asr['max_context'], '-1'),
    'max_len': _text(asr['max_len'], '0'),
    'hotwords': _text(asr['hotwords'], ''),
    'best_of': _text(asr['best_of'], '5'),
    'beam_size': _text(asr['beam_size'], 'greedy'),
    'audio_ctx': _text(asr['audio_ctx'], '0'),
    'word_thold': _text(asr['word_thold'], '0.01'),
    'entropy_thold': _text(asr['entropy_thold'], '2.4'),
    'logprob_thold': _text(asr['logprob_thold'], '-1.0'),
    'no_speech_thold': _text(asr['no_speech_thold'], '0.6'),
    'sensitivity': _text(asr['sensitivity'], 'balanced'),
    'seed': _text(asr['seed'], '0'),
    'temperature_inc': _text(asr['temperature_inc'], '0.2'),
    'vad_max_speech': _text(asr['vad_max_speech_duration_s'], '6'),
    'vad_min_silence': _text(asr['vad_min_silence_duration_ms'], '300'),
    'vad_model': _text(asr['vad_model'], 'firered'),
    'vad_threshold': _text(asr['vad_threshold'], '0.5'),
    'max_new_tokens': _text(asr['max_new_tokens'], '512'),
    'frequency_penalty': _text(asr['frequency_penalty'], '0.0'),
    'temperature': _text(asr['temperature'], '0.0'),
    'punc_model': _text(asr['punc_model'], ''),
    'truecase_model': _text(asr['truecase_model'], ''),
    'flush_after': _text(asr['flush_after'], '1'),
    'chunk_seconds': _text(asr['chunk_seconds'], '30'),
    'chunk_overlap': _text(asr['chunk_overlap'], '3.0'),
    'device': _text(asr['device'], '0'),
    'gpu_backend': _text(asr['gpu_backend'], 'auto'),
  };

  void _loadFlags(Map asr) {
    enableVad = asr['enable_vad'] != false;
    splitOnPunct = asr['split_on_punct'] != false;
    forceAligner = asr['force_aligner'] != false;
    splitOnWord = asr['split_on_word'] == true;
    noFallback = asr['no_fallback'] == true;
    noPunctuation = asr['no_punctuation'] == true;
    noGpu = asr['no_gpu'] == true;
    flashAttn = asr['flash_attn'] != false;
  }

  Map<String, dynamic> _draftValues() => {
    for (final entry in _fields.entries) entry.key: entry.value.text,
    'enable_vad': enableVad,
    'split_on_punct': splitOnPunct,
    'force_aligner': forceAligner,
    'split_on_word': splitOnWord,
    'no_fallback': noFallback,
    'no_punctuation': noPunctuation,
    'no_gpu': noGpu,
    'flash_attn': flashAttn,
  };

  String _draft() => jsonEncode(_draftValues());

  Map<String, dynamic> _loadedValues(Map asr) {
    final values = <String, dynamic>{
      ..._values(asr),
      'template': '${asr['extra_args'] ?? ''}'.trim(),
      'enable_vad': asr['enable_vad'] != false,
      'split_on_punct': asr['split_on_punct'] != false,
      'force_aligner': asr['force_aligner'] != false,
      'split_on_word': asr['split_on_word'] == true,
      'no_fallback': asr['no_fallback'] == true,
      'no_punctuation': asr['no_punctuation'] == true,
      'no_gpu': asr['no_gpu'] == true,
      'flash_attn': asr['flash_attn'] != false,
    };
    if (values['template'] == '') {
      values['template'] = _generatedTemplate(values);
    }
    return values;
  }

  void _loadPresets(Map settings, Map<String, dynamic> current) {
    _presets.clear();
    final stored = settings['asr_presets'];
    final defaults = _loadedValues({});
    if (stored is Map) {
      for (final entry in stored.entries) {
        if (entry.key is! String || entry.value is! Map) continue;
        final raw = entry.value as Map;
        _presets[entry.key as String] = {
          for (final item in defaults.entries)
            item.key: item.value is bool
                ? (raw[item.key] is bool ? raw[item.key] : item.value)
                : '${raw[item.key] ?? item.value}',
        };
      }
    }
    // Capture existing parameters once so upgrading does not discard tuning.
    _presetsNeedSave = !_basePresets.every(_presets.containsKey);
    _presets.putIfAbsent('qwen3', () => Map.of(current));
    _presets.putIfAbsent('moss', () {
      final moss = {
        ..._presets['qwen3']!,
        'force_aligner': false,
        'vad_max_speech': '30',
        'max_new_tokens': '2048',
      };
      moss['template'] = _generatedTemplate(moss);
      return moss;
    });
    final selected = settings['asr_preset'];
    _selectedPreset = selected is String && _presets.containsKey(selected)
        ? selected
        : 'qwen3';
  }

  void _applyDraft(Map<String, dynamic> values) {
    _syncing = true;
    for (final entry in _fields.entries) {
      entry.value.text = values[entry.key] as String;
    }
    _loadFlags(values);
    _syncing = false;
    // A saved template may contain options not represented by form fields.
    _templateEdited = template.text.trim() != _generatedTemplate();
  }

  String _nextPresetName() {
    final base = _selectedPreset.replaceFirst(RegExp(r'-自定义预设\d+$'), '');
    var number = 1;
    while (_presets.containsKey('$base-自定义预设$number')) {
      number++;
    }
    return '$base-自定义预设$number';
  }

  void _syncSettings() {
    if (!mounted || _settingsSynced || widget.app.settings.isEmpty) return;
    _settingsSynced = true;
    final asr = (widget.app.settings['asr'] as Map?) ?? {};
    final regenerate = !_templateEdited && _draft() != _savedDraft;
    final loaded = _loadedValues(asr);
    _loadPresets(widget.app.settings, loaded);
    final merged = mergeLoadedSettingsDraft(
      _savedDraft,
      _draftValues(),
      loaded,
    );
    _applyDraft(merged.values);
    if (regenerate) _setGeneratedTemplate();
    _savedDraft = merged.baseline;
    setState(() {});
  }

  @override
  void dispose() {
    _unregisterPageSaver();
    widget.app.removeListener(_syncSettings);
    for (final controller in _fields.values) {
      controller.dispose();
    }
    super.dispose();
  }

  String _text(Object? value, String fallback) {
    final text = '${value ?? ''}'.trim();
    return text.isEmpty ? fallback : text;
  }

  void _onStructuredChanged() {
    if (_syncing || !mounted) return;
    _setGeneratedTemplate();
    setState(() {});
  }

  void _onTemplateChanged() {
    if (!_syncing && mounted) {
      _templateEdited = true;
      setState(() {});
    }
  }

  void _setGeneratedTemplate() {
    _syncing = true;
    template.text = _generatedTemplate();
    _syncing = false;
    _templateEdited = false;
  }

  String _generatedTemplate([Map<String, dynamic>? values]) {
    final draft = values ?? _draftValues();
    String value(String name) => (draft[name] as String).trim();
    String quote(String text) =>
        RegExp(r'\s').hasMatch(text) ? '"$text"' : text;
    final args = <String>[
      r'$crispasr_executable',
      '--backend',
      r'$backend',
      '--model',
      r'$model_file',
      if (draft['force_aligner'] as bool) ...[
        '--aligner-model',
        r'$aligner_file',
        '--force-aligner',
      ],
      '--language',
      r'$language',
      '--output-srt',
      '--output-file',
      r'$output_file',
      '--file',
      r'$input_file',
      if (draft['enable_vad'] as bool) ...[
        '--vad',
        '--vad-model',
        quote(value('vad_model')),
        '--vad-threshold',
        value('vad_threshold'),
        '--vad-max-speech-duration-s',
        value('vad_max_speech'),
        '--vad-min-silence-duration-ms',
        value('vad_min_silence'),
      ],
      '--max-new-tokens',
      value('max_new_tokens'),
      '--frequency-penalty',
      value('frequency_penalty'),
      '--temperature',
      value('temperature'),
      '--flush-after',
      value('flush_after'),
      if (draft['split_on_punct'] as bool) '--split-on-punct',
      if (draft['split_on_word'] as bool) '--split-on-word',
      if (draft['no_fallback'] as bool) '--no-fallback',
      if (draft['no_punctuation'] as bool) '--no-punctuation',
      if (draft['no_gpu'] as bool) '--no-gpu',
      if (!(draft['flash_attn'] as bool)) '--no-flash-attn',
    ];
    final defaults = _values({});
    // Keep the default command small, but include every customized parameter.
    for (final name in defaults.keys) {
      if (const {
        'vad_model',
        'vad_threshold',
        'vad_max_speech',
        'vad_min_silence',
        'max_new_tokens',
        'frequency_penalty',
        'temperature',
        'flush_after',
      }.contains(name)) {
        continue;
      }
      final text = value(name);
      if (text.isNotEmpty && text != defaults[name]) {
        args.addAll(['--${name.replaceAll('_', '-')}', quote(text)]);
      }
    }
    return args.join(' ');
  }

  int _int(String name, int fallback) =>
      int.tryParse(field(name).text.trim()) ?? fallback;
  double _double(String name, double fallback) =>
      double.tryParse(field(name).text.trim()) ?? fallback;

  List<String> _tokens(String text) {
    final matches = RegExp(
      r'''(?:[^\s"']+|"[^"]*"|'[^']*')+''',
    ).allMatches(text);
    return [for (final match in matches) _unquote(match.group(0)!)];
  }

  String _unquote(String value) {
    if (value.length >= 2 &&
        ((value.startsWith('"') && value.endsWith('"')) ||
            (value.startsWith("'") && value.endsWith("'")))) {
      return value.substring(1, value.length - 1);
    }
    return value;
  }

  String? _option(List<String> tokens, List<String> names) {
    for (var index = 0; index < tokens.length; index++) {
      for (final name in names) {
        if (tokens[index] == name && index + 1 < tokens.length) {
          return tokens[index + 1];
        }
        if (tokens[index].startsWith('$name=') &&
            tokens[index].length > name.length + 1) {
          return tokens[index].substring(name.length + 1);
        }
      }
    }
    return null;
  }

  bool _has(List<String> tokens, List<String> names) =>
      names.any(tokens.contains);

  void _parseTemplateIntoFields() {
    final tokens = _tokens(template.text);
    _syncing = true;
    final values = <String, String>{
      'threads': _option(tokens, ['--threads', '-t']) ?? '4',
      'processors': _option(tokens, ['--processors', '-p']) ?? '1',
      'offset_t': _option(tokens, ['--offset-t', '-ot']) ?? '0',
      'offset_n': _option(tokens, ['--offset-n', '-on']) ?? '0',
      'duration': _option(tokens, ['--duration', '-d']) ?? '0',
      'max_context': _option(tokens, ['--max-context', '-mc']) ?? '-1',
      'max_len': _option(tokens, ['--max-len', '-ml']) ?? '0',
      'hotwords': _option(tokens, ['--hotwords']) ?? '',
      'best_of': _option(tokens, ['--best-of', '-bo']) ?? '5',
      'beam_size': _option(tokens, ['--beam-size', '-bs']) ?? 'greedy',
      'audio_ctx': _option(tokens, ['--audio-ctx', '-ac']) ?? '0',
      'word_thold': _option(tokens, ['--word-thold', '-wt']) ?? '0.01',
      'entropy_thold': _option(tokens, ['--entropy-thold', '-et']) ?? '2.4',
      'logprob_thold': _option(tokens, ['--logprob-thold', '-lpt']) ?? '-1.0',
      'no_speech_thold':
          _option(tokens, ['--no-speech-thold', '-nth']) ?? '0.6',
      'sensitivity': _option(tokens, ['--sensitivity']) ?? 'balanced',
      'seed': _option(tokens, ['--seed']) ?? '0',
      'temperature_inc':
          _option(tokens, ['--temperature-inc', '-tpi']) ?? '0.2',
      'vad_model': _option(tokens, ['--vad-model']) ?? 'firered',
      'vad_threshold': _option(tokens, ['--vad-threshold']) ?? '0.5',
      'vad_max_speech': _option(tokens, ['--vad-max-speech-duration-s']) ?? '6',
      'vad_min_silence':
          _option(tokens, ['--vad-min-silence-duration-ms']) ?? '300',
      'max_new_tokens': _option(tokens, ['--max-new-tokens', '-n']) ?? '512',
      'frequency_penalty': _option(tokens, ['--frequency-penalty']) ?? '0.0',
      'temperature': _option(tokens, ['--temperature', '-tp']) ?? '0.0',
      'punc_model': _option(tokens, ['--punc-model']) ?? '',
      'truecase_model': _option(tokens, ['--truecase-model']) ?? '',
      'flush_after': _option(tokens, ['--flush-after']) ?? '1',
      'chunk_seconds': _option(tokens, ['--chunk-seconds', '-ck']) ?? '30',
      'chunk_overlap': _option(tokens, ['--chunk-overlap']) ?? '3.0',
      'device': _option(tokens, ['--device', '-dev']) ?? '0',
      'gpu_backend': _option(tokens, ['--gpu-backend']) ?? 'auto',
    };
    for (final entry in values.entries) {
      field(entry.key).text = entry.value;
    }
    enableVad = _has(tokens, ['--vad']);
    forceAligner = _has(tokens, ['--force-aligner', '-falign']);
    splitOnPunct = _has(tokens, ['--split-on-punct', '-sp']);
    splitOnWord = _has(tokens, ['--split-on-word', '-sow']);
    noFallback = _has(tokens, ['--no-fallback', '-nf']);
    noPunctuation = _has(tokens, ['--no-punctuation']);
    noGpu = _has(tokens, ['--no-gpu', '-ng']);
    flashAttn = !_has(tokens, ['--no-flash-attn', '-nfa']);
    _syncing = false;
  }

  void _restore() {
    _applyDraft(_presets[_selectedPreset]!);
    setState(() {});
  }

  Future<void> _runAction(Future<void> Function() action) async {
    while (_pendingAction != null) {
      await _pendingAction;
    }
    if (!mounted) return;
    setState(() => _busy = true);
    final pending = action();
    _pendingAction = pending;
    try {
      await pending;
    } finally {
      _pendingAction = null;
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save({bool auto = false, bool saveAs = false}) async {
    try {
      await _runAction(() => _savePreset(auto: auto, saveAs: saveAs));
    } catch (error) {
      if (auto) rethrow;
      _showMessage(appL10n.saveFailed(error));
    }
  }

  Future<void> _savePreset({bool auto = false, bool saveAs = false}) async {
    final changed = _draft() != _savedDraft;
    if (auto && !changed && !_presetsNeedSave) return;
    var name = _selectedPreset;
    if (!auto && (saveAs || _basePresets.contains(name))) {
      final selectedName = await showDialog<String>(
        context: context,
        builder: (_) => AsrPresetNameDialog(
          suggestedName: _nextPresetName(),
          existingNames: _presets.keys.toSet(),
        ),
      );
      if (selectedName == null || !mounted) return;
      name = selectedName;
    } else if (auto && changed && _basePresets.contains(name)) {
      name = _nextPresetName();
    }
    if (_templateEdited) _parseTemplateIntoFields();
    await _persistPreset(name);
    if (!auto) _showMessage(appL10n.asrPresetSaved);
  }

  Future<void> _switchPreset(String? name) async {
    if (name == null || name == _selectedPreset) return;
    try {
      await _runAction(() async {
        await _savePreset(auto: true);
        if (!mounted) return;
        final previous = _draftValues();
        _applyDraft(_presets[name]!);
        try {
          await _persistPreset(name);
        } catch (_) {
          _applyDraft(previous);
          rethrow;
        }
      });
    } catch (error) {
      _showMessage(appL10n.presetSwitchFailed(error));
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Map<String, dynamic> _asrValues() => <String, dynamic>{
    'enable_vad': enableVad,
    'vad_max_speech_duration_s': _double('vad_max_speech', 6),
    'vad_min_silence_duration_ms': _int('vad_min_silence', 300),
    'vad_model': field('vad_model').text.trim(),
    'vad_threshold': _double('vad_threshold', 0.5),
    'max_new_tokens': _int('max_new_tokens', 512),
    'frequency_penalty': _double('frequency_penalty', 0),
    'temperature': _double('temperature', 0),
    'split_on_punct': splitOnPunct,
    'force_aligner': forceAligner,
    'extra_args': template.text.trim(),
    for (final name in [
      'threads',
      'processors',
      'offset_t',
      'offset_n',
      'duration',
      'max_context',
      'max_len',
      'best_of',
      'audio_ctx',
      'seed',
      'flush_after',
      'chunk_seconds',
      'device',
    ])
      name: _int(name, 0),
    for (final name in [
      'word_thold',
      'entropy_thold',
      'logprob_thold',
      'no_speech_thold',
      'temperature_inc',
      'chunk_overlap',
    ])
      name: _double(name, 0),
    'hotwords': field('hotwords').text.trim(),
    'beam_size': field('beam_size').text.trim(),
    'sensitivity': field('sensitivity').text.trim(),
    'split_on_word': splitOnWord,
    'no_fallback': noFallback,
    'no_punctuation': noPunctuation,
    'punc_model': field('punc_model').text.trim(),
    'truecase_model': field('truecase_model').text.trim(),
    'no_gpu': noGpu,
    'gpu_backend': field('gpu_backend').text.trim(),
    'flash_attn': flashAttn,
  };

  Future<void> _persistPreset(String name) async {
    final draft = _draftValues();
    final asrValues = _asrValues();
    final presets = {
      ..._presets,
      if (!_basePresets.contains(name)) name: draft,
    };
    await widget.app.updateSettings((next) {
      next['asr'] = {...(next['asr'] as Map? ?? {}), ...asrValues};
      next['asr_preset'] = name;
      next['asr_presets'] = presets;
    });
    _presets
      ..clear()
      ..addAll(presets);
    _selectedPreset = name;
    _savedDraft = jsonEncode(draft);
    _presetsNeedSave = false;
  }

  Widget _field(String name, String label, {String? hint}) =>
      KtField(controller: field(name), label: label, hint: hint);

  Widget _parameterGrid(
    List<Widget> children, {
    int maxColumns = 3,
  }) => LayoutBuilder(
    builder: (context, constraints) {
      const spacing = 16.0;
      final minWidth = 240 * MediaQuery.textScalerOf(context).scale(1);
      final columns = ((constraints.maxWidth + spacing) / (minWidth + spacing))
          .floor()
          .clamp(1, maxColumns);
      final width = (constraints.maxWidth - spacing * (columns - 1)) / columns;
      return Wrap(
        spacing: spacing,
        children: [
          for (final child in children) SizedBox(width: width, child: child),
        ],
      );
    },
  );

  void _boolChanged(String name, bool value) {
    setState(() {
      if (name == 'vad') enableVad = value;
      if (name == 'punct') splitOnPunct = value;
      if (name == 'align') forceAligner = value;
      if (name == 'word') splitOnWord = value;
      if (name == 'fallback') noFallback = value;
      if (name == 'nopunc') noPunctuation = value;
      if (name == 'gpu') noGpu = value;
      if (name == 'flash') flashAttn = value;
      _setGeneratedTemplate();
    });
  }

  @override
  Widget build(BuildContext context) =>
      AbsorbPointer(absorbing: _busy, child: _buildPage(context));

  Widget _buildPage(BuildContext context) {
    final p = paletteOf(context);
    return KtPage(
      title: context.l10n.asrParameters,
      description: context.l10n.asrParametersDescription,
      columns: false,
      actions: [
        if (!_basePresets.contains(_selectedPreset))
          TextButton.icon(
            onPressed: () => _save(saveAs: true),
            icon: const Icon(Icons.save_as_outlined, size: 18),
            label: Text(context.l10n.saveAs),
          ),
        FilledButton.icon(
          onPressed: () => _save(),
          icon: const Icon(Icons.save_outlined, size: 18),
          label: Text(context.l10n.save),
        ),
      ],
      children: [
        KtSection(
          title: context.l10n.presets,
          icon: Icons.tune,
          children: [
            KtSelectField<String>(
              label: context.l10n.asrPreset,
              value: _selectedPreset,
              values: [
                ..._basePresets,
                ..._presets.keys.where((name) => !_basePresets.contains(name)),
              ],
              labelOf: (name) => _basePresets.contains(name)
                  ? context.l10n.basePresetLabel(name)
                  : name,
              onChanged: _switchPreset,
            ),
            if (_basePresets.contains(_selectedPreset))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  context.l10n.basePresetDescription,
                  style: TextStyle(fontSize: 12, color: p.muted),
                ),
              ),
          ],
        ),
        KtSection(
          title: context.l10n.basicSegmentation,
          icon: Icons.graphic_eq,
          children: [
            _parameterGrid([
              _field('offset_t', context.l10n.startOffsetMs, hint: '0'),
              _field('offset_n', context.l10n.segmentOffset, hint: '0'),
              _field(
                'duration',
                context.l10n.processingDurationMs,
                hint: context.l10n.zeroMeansAll,
              ),
              _field('max_context', context.l10n.maxTextContext, hint: '-1'),
              _field('max_len', context.l10n.maxSegmentLength, hint: '0'),
              _field(
                'chunk_seconds',
                context.l10n.chunkSecondsWithoutVad,
                hint: '30',
              ),
              _field(
                'chunk_overlap',
                context.l10n.chunkOverlapSeconds,
                hint: '3.0',
              ),
            ]),
            _parameterGrid([
              KtSwitchRow(
                icon: Icons.align_horizontal_left_outlined,
                title: context.l10n.forceAligner,
                sub: '--force-aligner',
                value: forceAligner,
                onChanged: (v) => _boolChanged('align', v),
                showDivider: false,
              ),
              KtSwitchRow(
                icon: Icons.space_bar_outlined,
                title: context.l10n.splitOnPunctuation,
                sub: '--split-on-punct',
                value: splitOnPunct,
                onChanged: (v) => _boolChanged('punct', v),
                showDivider: false,
              ),
              KtSwitchRow(
                icon: Icons.segment,
                title: context.l10n.splitOnWord,
                sub: '--split-on-word',
                value: splitOnWord,
                onChanged: (v) => _boolChanged('word', v),
                showDivider: false,
              ),
            ], maxColumns: 2),
          ],
        ),
        KtSection(
          title: context.l10n.vadAndPunctuation,
          icon: Icons.multitrack_audio,
          children: [
            _parameterGrid([
              KtSwitchRow(
                icon: Icons.graphic_eq_outlined,
                title: 'VAD',
                sub: '--vad',
                value: enableVad,
                onChanged: (v) => _boolChanged('vad', v),
                showDivider: false,
              ),
              KtSwitchRow(
                icon: Icons.text_format,
                title: context.l10n.disablePunctuation,
                sub: '--no-punctuation',
                value: noPunctuation,
                onChanged: (v) => _boolChanged('nopunc', v),
                showDivider: false,
              ),
            ], maxColumns: 2),
            _parameterGrid([
              _field(
                'vad_max_speech',
                context.l10n.maxSpeechSeconds,
                hint: '6',
              ),
              _field('vad_min_silence', context.l10n.minSilenceMs, hint: '300'),
              KtComboField(
                controller: field('vad_model'),
                label: context.l10n.vadModel,
                hint: context.l10n.vadModelHint,
                options: const [
                  'auto',
                  'silero',
                  'firered',
                  'marblenet',
                  'webrtc',
                  'whisper-vad',
                ],
              ),
              _field('vad_threshold', context.l10n.vadThreshold, hint: '0.5'),
              _field('hotwords', context.l10n.hotwords),
              KtComboField(
                controller: field('sensitivity'),
                label: context.l10n.recognitionSensitivity,
                options: const ['conservative', 'balanced', 'aggressive'],
              ),
              KtComboField(
                controller: field('punc_model'),
                label: context.l10n.punctuationModel,
                hint: context.l10n.leaveEmptyForDefault,
                options: const ['auto', 'firered', 'fullstop', 'punctuate-all'],
              ),
              _field(
                'truecase_model',
                context.l10n.truecaseModel,
                hint: context.l10n.truecaseModelHint,
              ),
              _field(
                'flush_after',
                context.l10n.flushSrtEveryN,
                hint: context.l10n.flushSrtHint,
              ),
            ]),
          ],
        ),
        KtSection(
          title: context.l10n.decoding,
          icon: Icons.tune_outlined,
          children: [
            _parameterGrid([
              _field('max_new_tokens', 'max-new-tokens', hint: '512'),
              _field('frequency_penalty', 'frequency-penalty', hint: '0.0'),
              _field('temperature', 'temperature', hint: '0.0'),
              _field('temperature_inc', 'temperature-inc', hint: '0.2'),
              _field('best_of', context.l10n.bestOf, hint: '5'),
              KtComboField(
                controller: field('beam_size'),
                label: 'beam-size',
                options: const ['greedy', '2', '5', '10'],
              ),
              _field('audio_ctx', context.l10n.audioContext, hint: '0'),
              _field(
                'word_thold',
                context.l10n.wordTimestampThreshold,
                hint: '0.01',
              ),
              _field(
                'entropy_thold',
                context.l10n.entropyThreshold,
                hint: '2.4',
              ),
              _field(
                'logprob_thold',
                context.l10n.logProbabilityThreshold,
                hint: '-1.0',
              ),
              _field(
                'no_speech_thold',
                context.l10n.noSpeechThreshold,
                hint: '0.6',
              ),
              _field('seed', context.l10n.randomSeed, hint: '0'),
            ]),
            KtSwitchRow(
              icon: Icons.refresh_outlined,
              title: context.l10n.disableTemperatureFallback,
              sub: '--no-fallback',
              value: noFallback,
              onChanged: (v) => _boolChanged('fallback', v),
              showDivider: false,
            ),
          ],
        ),
        KtSection(
          title: context.l10n.device,
          icon: Icons.memory_outlined,
          children: [
            _parameterGrid([
              KtSwitchRow(
                icon: Icons.memory_outlined,
                title: context.l10n.disableGpu,
                sub: '--no-gpu',
                value: noGpu,
                onChanged: (v) => _boolChanged('gpu', v),
                showDivider: false,
              ),
              KtSwitchRow(
                icon: Icons.bolt,
                title: 'Flash Attention',
                sub: '--flash-attn / --no-flash-attn',
                value: flashAttn,
                onChanged: (v) => _boolChanged('flash', v),
                showDivider: false,
              ),
            ], maxColumns: 2),
            _parameterGrid([
              _field('threads', context.l10n.threads, hint: '4'),
              _field('processors', context.l10n.processors, hint: '1'),
              _field('device', context.l10n.gpuDeviceIndex, hint: '0'),
              KtComboField(
                controller: field('gpu_backend'),
                label: context.l10n.gpuBackend,
                options: const ['auto', 'cuda', 'vulkan', 'metal', 'cpu'],
              ),
            ], maxColumns: 2),
          ],
        ),
        KtSection(
          title: context.l10n.advancedTemplate,
          icon: Icons.terminal,
          action: TextButton.icon(
            onPressed: _restore,
            icon: const Icon(Icons.restart_alt, size: 16),
            label: Text(context.l10n.restorePreset),
          ),
          children: [
            ExpansionTile(
              key: const PageStorageKey('asr-command-template'),
              tilePadding: EdgeInsets.zero,
              maintainState: true,
              shape: const Border(),
              collapsedShape: const Border(),
              title: Text(
                context.l10n.editCommandTemplate,
                style: TextStyle(
                  fontSize: 13,
                  color: p.text,
                  fontWeight: FontWeight.w600,
                ),
              ),
              children: [
                KtField(
                  // Separate the editor's scroll offset from the tile's bool state.
                  key: const PageStorageKey('asr-command-template-editor'),
                  controller: template,
                  label: context.l10n.fullCommandTemplate,
                  hint: context.l10n.commandTemplateHint,
                  maxLines: 5,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    context.l10n.commandTemplateDescription,
                    style: TextStyle(fontSize: 12, color: p.muted),
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
