import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../app_state.dart';
import '../widgets.dart';

const _presets = [
  ('target_lrc', '目标 LRC', '单语歌词，kikoeta 优先匹配'),
  ('target_srt', '目标 SRT', '单语字幕'),
  ('bilingual_lrc', '双语 LRC', '同一文件内译文 + 原文'),
  ('bilingual_srt', '双语 SRT', '同一文件内译文 + 原文'),
];

class OutputPage extends StatefulWidget {
  final AppState app;
  const OutputPage({super.key, required this.app});

  @override
  State<OutputPage> createState() => _OutputPageState();
}

class _OutputPageState extends State<OutputPage> {
  late final TextEditingController directory;
  late bool writeKikoeta;
  late String preset;

  @override
  void initState() {
    super.initState();
    final output = (widget.app.settings['output'] as Map?) ?? {};
    directory = TextEditingController(text: '${output['directory'] ?? ''}');
    writeKikoeta = output['write_kikoeta_lyrics'] == true;
    preset = _presetOf(output);
  }

  @override
  void dispose() {
    directory.dispose();
    super.dispose();
  }

  String _presetOf(Map output) {
    final raw = '${output['preset'] ?? ''}'.trim();
    if (_presets.any((item) => item.$1 == raw)) return raw;
    final formats = {
      for (final item in (output['formats'] as List? ?? const ['lrc']))
        item.toString(),
    };
    final fmt = formats.contains('srt') && !formats.contains('lrc')
        ? 'srt'
        : 'lrc';
    final bilingual = output['bilingual'] == true;
    final prefix = bilingual ? 'bilingual' : 'target';
    return '${prefix}_$fmt';
  }

  String _labelOf(String id) {
    for (final item in _presets) {
      if (item.$1 == id) return '${item.$2}  ·  ${item.$3}';
    }
    return id;
  }

  Future<void> _save() async {
    final next = Map<String, dynamic>.from(widget.app.settings);
    final bilingual = preset.startsWith('bilingual_');
    final fmt = preset.endsWith('srt') ? 'srt' : 'lrc';
    next['output'] = {
      ...(next['output'] as Map? ?? {}),
      'directory': directory.text.trim(),
      'preset': preset,
      'formats': [fmt],
      'bilingual': bilingual,
      'write_kikoeta_lyrics': writeKikoeta,
    };
    await widget.app.persistSettings(next);
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('输出设置已保存')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_presets.any((item) => item.$1 == preset)) {
      preset = 'target_lrc';
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 24),
      children: [
        const Text(
          '输出',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        ),
        const SectionTitle('文件'),
        KtGroup(
          children: [
            KtField(
              controller: directory,
              label: '输出目录',
              hint: '留空则输出到源文件所在目录',
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: 8,
                  children: [
                    TextButton(
                      onPressed: () async {
                        final dir = await FilePicker.platform
                            .getDirectoryPath();
                        if (dir != null) setState(() => directory.text = dir);
                      },
                      child: const Text('选择目录'),
                    ),
                    TextButton(
                      onPressed: () => setState(() => directory.text = ''),
                      child: const Text('使用源文件目录'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SectionTitle('格式'),
        KtGroup(
          children: [
            KtSelectField<String>(
              label: '输出格式',
              value: preset,
              values: [for (final item in _presets) item.$1],
              labelOf: _labelOf,
              onChanged: (value) => setState(() => preset = value),
            ),
          ],
        ),
        const SectionTitle('kikoeta'),
        KtGroup(
          children: [
            KtSwitchRow(
              icon: Icons.folder_special_outlined,
              title: '写入 kikoeta 歌词库',
              sub: 'lyrics/RJ######/',
              value: writeKikoeta,
              onChanged: (v) => setState(() => writeKikoeta = v),
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
