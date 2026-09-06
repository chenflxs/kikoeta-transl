import 'package:flutter/material.dart';

import '../app_state.dart';
import '../widgets.dart';

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

  TextEditingController field(String name) => _fields[name]!;
  TextEditingController get template => field('template');

  @override
  void initState() {
    super.initState();
    final asr = (widget.app.settings['asr'] as Map?) ?? {};
    final values = <String, String>{
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
      'max_new_tokens': _text(asr['max_new_tokens'], '224'),
      'frequency_penalty': _text(asr['frequency_penalty'], '0.0'),
      'repetition_penalty': _text(asr['repetition_penalty'], '1.0'),
      'temperature': _text(asr['temperature'], '0.0'),
      'punc_model': _text(asr['punc_model'], ''),
      'truecase_model': _text(asr['truecase_model'], ''),
      'flush_after': _text(asr['flush_after'], '0'),
      'chunk_seconds': _text(asr['chunk_seconds'], '30'),
      'chunk_overlap': _text(asr['chunk_overlap'], '3.0'),
      'device': _text(asr['device'], '0'),
      'gpu_backend': _text(asr['gpu_backend'], 'auto'),
    };
    for (final entry in values.entries) {
      _fields[entry.key] = TextEditingController(text: entry.value)
        ..addListener(_onStructuredChanged);
    }
    _fields['template'] = TextEditingController(
      text: '${asr['extra_args'] ?? ''}'.trim(),
    );
    template.addListener(_onTemplateChanged);
    enableVad = asr['enable_vad'] != false;
    splitOnPunct = asr['split_on_punct'] == true;
    forceAligner = asr['force_aligner'] != false;
    splitOnWord = asr['split_on_word'] == true;
    noFallback = asr['no_fallback'] == true;
    noPunctuation = asr['no_punctuation'] == true;
    noGpu = asr['no_gpu'] == true;
    flashAttn = asr['flash_attn'] != false;
    if (template.text.isEmpty) _setGeneratedTemplate();
  }

  @override
  void dispose() {
    for (final controller in _fields.values) controller.dispose();
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
    if (!_syncing && mounted) setState(() {});
  }

  void _setGeneratedTemplate() {
    _syncing = true;
    template.text = _generatedTemplate();
    _syncing = false;
  }

  String _generatedTemplate() {
    final args = <String>[
      r'$crispasr_executable',
      '--backend',
      r'$backend',
      '--model',
      r'$model_file',
      '--aligner-model',
      r'$aligner_file',
      if (forceAligner) '--force-aligner',
      '--language',
      r'$language',
      '--output-srt',
      '--output-file',
      r'$output_file',
      '--file',
      r'$input_file',
      if (enableVad) ...[
        '--vad',
        '--vad-model', field('vad_model').text.trim(),
        '--vad-threshold', field('vad_threshold').text.trim(),
        '--vad-max-speech-duration-s', field('vad_max_speech').text.trim(),
        '--vad-min-silence-duration-ms', field('vad_min_silence').text.trim(),
      ],
      '--max-new-tokens', field('max_new_tokens').text.trim(),
      '--frequency-penalty', field('frequency_penalty').text.trim(),
      '--repetition-penalty', field('repetition_penalty').text.trim(),
      '--condition-on-previous-text', 'True',
      '--temperature', field('temperature').text.trim(),
      if (splitOnPunct) '--split-on-punct',
    ];
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
            (value.startsWith("'") && value.endsWith("'"))))
      return value.substring(1, value.length - 1);
    return value;
  }

  String? _option(List<String> tokens, List<String> names) {
    for (var index = 0; index < tokens.length; index++) {
      for (final name in names) {
        if (tokens[index] == name && index + 1 < tokens.length)
          return tokens[index + 1];
        if (tokens[index].startsWith('$name=') &&
            tokens[index].length > name.length + 1)
          return tokens[index].substring(name.length + 1);
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
      'max_new_tokens': _option(tokens, ['--max-new-tokens', '-n']) ?? '224',
      'frequency_penalty': _option(tokens, ['--frequency-penalty']) ?? '0.0',
      'repetition_penalty':
          _option(tokens, ['--repetition-penalty']) ?? '1.0',
      'temperature': _option(tokens, ['--temperature', '-tp']) ?? '0.0',
      'punc_model': _option(tokens, ['--punc-model']) ?? '',
      'truecase_model': _option(tokens, ['--truecase-model']) ?? '',
      'flush_after': _option(tokens, ['--flush-after']) ?? '0',
      'chunk_seconds': _option(tokens, ['--chunk-seconds', '-ck']) ?? '30',
      'chunk_overlap': _option(tokens, ['--chunk-overlap']) ?? '3.0',
      'device': _option(tokens, ['--device', '-dev']) ?? '0',
      'gpu_backend': _option(tokens, ['--gpu-backend']) ?? 'auto',
    };
    for (final entry in values.entries) field(entry.key).text = entry.value;
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
    _syncing = true;
    enableVad = true;
    splitOnPunct = true;
    forceAligner = true;
    splitOnWord = false;
    noFallback = false;
    noPunctuation = false;
    noGpu = false;
    flashAttn = true;
    const defaults = <String, String>{
      'threads': '4',
      'processors': '1',
      'offset_t': '0',
      'offset_n': '0',
      'duration': '0',
      'max_context': '-1',
      'max_len': '0',
      'hotwords': '',
      'best_of': '5',
      'beam_size': 'greedy',
      'audio_ctx': '0',
      'word_thold': '0.01',
      'entropy_thold': '2.4',
      'logprob_thold': '-1.0',
      'no_speech_thold': '0.6',
      'sensitivity': 'balanced',
      'seed': '0',
      'temperature_inc': '0.2',
      'vad_max_speech': '6',
      'vad_min_silence': '300',
      'vad_model': 'firered',
      'vad_threshold': '0.5',
      'max_new_tokens': '224',
      'frequency_penalty': '0.0',
      'repetition_penalty': '1.0',
      'temperature': '0.0',
      'punc_model': '',
      'truecase_model': '',
      'flush_after': '0',
      'chunk_seconds': '30',
      'chunk_overlap': '3.0',
      'device': '0',
      'gpu_backend': 'auto',
    };
    for (final entry in defaults.entries) field(entry.key).text = entry.value;
    _syncing = false;
    _setGeneratedTemplate();
    setState(() {});
  }

  Future<void> _save() async {
    _parseTemplateIntoFields();
    final next = Map<String, dynamic>.from(widget.app.settings);
    next['asr'] = {
      ...(next['asr'] as Map? ?? {}),
      'enable_vad': enableVad,
      'vad_max_speech_duration_s': _double('vad_max_speech', 6),
      'vad_min_silence_duration_ms': _int('vad_min_silence', 300),
      'vad_model': field('vad_model').text.trim(),
      'vad_threshold': _double('vad_threshold', 0.5),
      'max_new_tokens': _int('max_new_tokens', 224),
      'frequency_penalty': _double('frequency_penalty', 0),
      'repetition_penalty': _double('repetition_penalty', 1),
      'condition_on_previous_text': true,
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
    await widget.app.persistSettings(next);
    if (mounted)
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('听写参数已保存')));
  }

  Widget _field(String name, String label, {String? hint}) =>
      KtField(controller: field(name), label: label, hint: hint);
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
  Widget build(BuildContext context) {
    final p = paletteOf(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 24),
      children: [
        const Text(
          '听写参数',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          '媒体听写使用的 CrispASR 参数。字幕输入不会走到这一步。',
          style: TextStyle(fontSize: 12, color: p.muted),
        ),
        const SectionTitle('高级模板'),
        KtGroup(
          children: [
            KtField(
              controller: template,
              label: '完整命令模板',
              hint: '根据下方参数实时生成；可手动编辑后保存',
              maxLines: 7,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 4),
              child: Text(
                '保存时会从模板解析可编辑参数；未知参数会保留在模板中。',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              child: Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _restore,
                  icon: const Icon(Icons.restart_alt, size: 16),
                  label: const Text('恢复默认'),
                ),
              ),
            ),
          ],
        ),
        const SectionTitle('基础与分段'),
        KtGroup(
          children: [
            _field('threads', '线程数', hint: '4'),
            _field('processors', '处理器数', hint: '1'),
            _field('offset_t', '起始偏移（毫秒）', hint: '0'),
            _field('offset_n', '起始片段偏移', hint: '0'),
            _field('duration', '处理时长（毫秒）', hint: '0 表示全部'),
            _field('max_context', '最大文本上下文', hint: '-1'),
            _field('max_len', '最大片段长度', hint: '0'),
            _field('chunk_seconds', '无 VAD 时分段秒数', hint: '30'),
            _field('chunk_overlap', '分段重叠秒数', hint: '3.0'),
            KtSwitchRow(
              icon: Icons.graphic_eq_outlined,
              title: 'VAD',
              sub: '--vad',
              value: enableVad,
              onChanged: (v) => _boolChanged('vad', v),
            ),
            KtSwitchRow(
              icon: Icons.align_horizontal_left_outlined,
              title: '强制 Aligner',
              sub: '--force-aligner',
              value: forceAligner,
              onChanged: (v) => _boolChanged('align', v),
            ),
            KtSwitchRow(
              icon: Icons.space_bar_outlined,
              title: '按标点切分',
              sub: '--split-on-punct',
              value: splitOnPunct,
              onChanged: (v) => _boolChanged('punct', v),
            ),
            KtSwitchRow(
              icon: Icons.segment,
              title: '按单词切分',
              sub: '--split-on-word',
              value: splitOnWord,
              onChanged: (v) => _boolChanged('word', v),
              showDivider: false,
            ),
          ],
        ),
        const SectionTitle('VAD 与标点'),
        KtGroup(
          children: [
            _field('vad_max_speech', '最大语音时长（秒）', hint: '6'),
            _field('vad_min_silence', '最小静音（毫秒）', hint: '300'),
            KtComboField(
              controller: field('vad_model'),
              label: 'VAD 模型',
              hint: '可输入模型别名或路径',
              options: const [
                'auto',
                'silero',
                'firered',
                'marblenet',
                'webrtc',
                'whisper-vad',
              ],
            ),
            _field('vad_threshold', 'VAD 阈值', hint: '0.5'),
            _field('hotwords', '热词（逗号分隔）'),
            KtComboField(
              controller: field('sensitivity'),
              label: '识别敏感度',
              options: const ['conservative', 'balanced', 'aggressive'],
            ),
            KtComboField(
              controller: field('punc_model'),
              label: '标点模型',
              hint: '留空使用默认',
              options: const ['auto', 'firered', 'fullstop', 'punctuate-all'],
            ),
            _field('truecase_model', '大小写模型', hint: 'auto 或模型路径'),
            _field('flush_after', '每 N 段刷新 SRT', hint: '0 表示最后统一输出'),
          ],
        ),
        const SectionTitle('解码'),
        KtGroup(
          children: [
            _field('max_new_tokens', 'max-new-tokens', hint: '224'),
            _field('frequency_penalty', 'frequency-penalty', hint: '0.0'),
            _field('repetition_penalty', 'repetition-penalty', hint: '1.0'),
            _field('temperature', 'temperature', hint: '0.0'),
            _field('temperature_inc', 'temperature-inc', hint: '0.2'),
            _field('best_of', '候选数 best-of', hint: '5'),
            KtComboField(
              controller: field('beam_size'),
              label: 'beam-size',
              options: const ['greedy', '2', '5', '10'],
            ),
            _field('audio_ctx', '音频上下文', hint: '0'),
            _field('word_thold', '词时间戳阈值', hint: '0.01'),
            _field('entropy_thold', '熵阈值', hint: '2.4'),
            _field('logprob_thold', '对数概率阈值', hint: '-1.0'),
            _field('no_speech_thold', '无语音阈值', hint: '0.6'),
            _field('seed', '随机种子', hint: '0'),
            KtSwitchRow(
              icon: Icons.refresh_outlined,
              title: '禁用温度回退',
              sub: '--no-fallback',
              value: noFallback,
              onChanged: (v) => _boolChanged('fallback', v),
              showDivider: false,
            ),
          ],
        ),
        const SectionTitle('高级解码选项'),
        KtGroup(
          children: [
            KtSwitchRow(
              icon: Icons.text_format,
              title: '禁用标点',
              sub: '--no-punctuation',
              value: noPunctuation,
              onChanged: (v) => _boolChanged('nopunc', v),
              showDivider: false,
            ),
          ],
        ),
        const SectionTitle('设备'),
        KtGroup(
          children: [
            KtSwitchRow(
              icon: Icons.memory_outlined,
              title: '禁用 GPU',
              sub: '--no-gpu',
              value: noGpu,
              onChanged: (v) => _boolChanged('gpu', v),
            ),
            _field('device', 'GPU 设备编号', hint: '0'),
            KtComboField(
              controller: field('gpu_backend'),
              label: 'GPU 后端',
              options: const ['auto', 'cuda', 'vulkan', 'metal', 'cpu'],
            ),
            KtSwitchRow(
              icon: Icons.bolt,
              title: 'Flash Attention',
              sub: '--flash-attn / --no-flash-attn',
              value: flashAttn,
              onChanged: (v) => _boolChanged('flash', v),
              showDivider: false,
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
  }
}
