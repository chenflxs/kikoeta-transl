import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../app_state.dart';
import '../settings_draft.dart';
import '../widgets.dart';

const _presets = [
  ('target_lrc', '目标 LRC', '单语歌词，kikoeta 优先匹配'),
  ('target_srt', '目标 SRT', '单语字幕'),
  ('bilingual_lrc', '双语 LRC', '同一文件内译文 + 原文'),
  ('bilingual_srt', '双语 SRT', '同一文件内译文 + 原文'),
  ('source_target_lrc', '原文 + 目标 LRC', '同一文件内原文 + 译文'),
  ('source_target_srt', '原文 + 目标 SRT', '同一文件内原文 + 译文'),
];

class OutputPage extends StatefulWidget {
  final AppState app;
  const OutputPage({super.key, required this.app});

  @override
  State<OutputPage> createState() => _OutputPageState();
}

class _OutputPageState extends State<OutputPage> {
  late final TextEditingController directory;
  late final TextEditingController llsUrl;
  late final TextEditingController llsUsername;
  late final TextEditingController llsPassword;
  late final TextEditingController llsKey;
  late String preset;
  late bool llsSync;
  late String llsAuthMode;
  late String _savedDraft;
  late final VoidCallback _unregisterPageSaver;
  bool _settingsSynced = false;
  bool _pushingCache = false;
  String _cachePushStatus = '';
  List<String> _cachePushErrors = [];

  @override
  void initState() {
    super.initState();
    final output = (widget.app.settings['output'] as Map?) ?? {};
    directory = TextEditingController(text: '${output['directory'] ?? ''}');
    preset = _presetOf(output);
    llsSync = output['lls_sync'] == true;
    llsAuthMode = output['lls_auth_mode'] == 'basic' ? 'basic' : 'key';
    llsUrl = TextEditingController(text: '${output['lls_url'] ?? ''}');
    llsUsername = TextEditingController(
      text: '${output['lls_username'] ?? ''}',
    );
    llsPassword = TextEditingController(
      text: '${output['lls_password'] ?? ''}',
    );
    llsKey = TextEditingController(text: '${output['lls_key'] ?? ''}');
    _savedDraft = _draft();
    _settingsSynced = widget.app.settings.isNotEmpty;
    _unregisterPageSaver = widget.app.registerPageSaver(
      5,
      () => _save(auto: true),
    );
    widget.app.addListener(_syncSettings);
  }

  Map<String, dynamic> _draftValues() => {
    'directory': directory.text,
    'preset': preset,
    'lls_sync': llsSync,
    'lls_auth_mode': llsAuthMode,
    'lls_url': llsUrl.text,
    'lls_username': llsUsername.text,
    'lls_password': llsPassword.text,
    'lls_key': llsKey.text,
  };

  String _draft() => jsonEncode(_draftValues());

  void _syncSettings() {
    if (!mounted || _settingsSynced || widget.app.settings.isEmpty) return;
    _settingsSynced = true;
    final output = (widget.app.settings['output'] as Map?) ?? {};
    final merged = mergeLoadedSettingsDraft(_savedDraft, _draftValues(), {
      'directory': '${output['directory'] ?? ''}',
      'preset': _presetOf(output),
      'lls_sync': output['lls_sync'] == true,
      'lls_auth_mode': output['lls_auth_mode'] == 'basic' ? 'basic' : 'key',
      'lls_url': '${output['lls_url'] ?? ''}',
      'lls_username': '${output['lls_username'] ?? ''}',
      'lls_password': '${output['lls_password'] ?? ''}',
      'lls_key': '${output['lls_key'] ?? ''}',
    });
    directory.text = merged.values['directory'] as String;
    llsUrl.text = merged.values['lls_url'] as String;
    llsUsername.text = merged.values['lls_username'] as String;
    llsPassword.text = merged.values['lls_password'] as String;
    llsKey.text = merged.values['lls_key'] as String;
    setState(() {
      preset = merged.values['preset'] as String;
      llsSync = merged.values['lls_sync'] as bool;
      llsAuthMode = merged.values['lls_auth_mode'] as String;
    });
    _savedDraft = merged.baseline;
  }

  @override
  void dispose() {
    _unregisterPageSaver();
    widget.app.removeListener(_syncSettings);
    directory.dispose();
    llsUrl.dispose();
    llsUsername.dispose();
    llsPassword.dispose();
    llsKey.dispose();
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

  Future<void> _save({bool auto = false}) async {
    final draft = _draft();
    if (auto && draft == _savedDraft) return;
    final outputDirectory = directory.text.trim();
    final outputPreset = preset;
    final bilingual =
        outputPreset.startsWith('bilingual_') ||
        outputPreset.startsWith('source_target_');
    final fmt = outputPreset.endsWith('srt') ? 'srt' : 'lrc';
    final sync = llsSync;
    final authMode = llsAuthMode;
    final url = llsUrl.text.trim();
    final username = llsUsername.text.trim();
    final password = llsPassword.text;
    final key = llsKey.text.trim();
    await widget.app.updateSettings((next) {
      next['output'] = {
        ...(next['output'] as Map? ?? {}),
        'directory': outputDirectory,
        'preset': outputPreset,
        'formats': [fmt],
        'bilingual': bilingual,
        'lls_sync': sync,
        'lls_url': url,
        'lls_auth_mode': authMode,
        'lls_username': username,
        'lls_password': password,
        'lls_key': key,
      };
    });
    _savedDraft = draft;
    if (!auto && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('输出设置已保存')));
    }
  }

  Future<void> _pushCache() async {
    if (_pushingCache) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _pushingCache = true;
      _cachePushStatus = '正在读取歌词缓存…';
      _cachePushErrors = [];
    });
    var uploaded = 0;
    final errors = <String>[];
    try {
      await _save(auto: true);
      final entries = await widget.app.engine.llsCache();
      final total = entries.fold<int>(
        0,
        (count, entry) => count + (entry['files'] as List).length,
      );
      var processed = 0;
      // Upload older results first so the latest cached translation wins.
      for (final entry in entries.reversed) {
        final files = entry['files'] as List;
        for (var index = 0; index < files.length; index++) {
          if (!mounted) return;
          final file = files[index] as Map;
          final label = '${entry['work_id']} / ${file['track_path']}';
          setState(
            () => _cachePushStatus = '正在推送 ${processed + 1}/$total：$label',
          );
          try {
            await widget.app.engine.pushLlsCachedFile(
              entry['job_id'] as String,
              index,
            );
            uploaded++;
          } catch (e) {
            errors.add('$label：$e');
          }
          processed++;
        }
      }
      if (!mounted) return;
      setState(() {
        _cachePushStatus = total == 0
            ? '暂无可推送的 Kikoeta 歌词缓存'
            : '推送完成：成功 $uploaded 个，失败 ${errors.length} 个';
        _cachePushErrors = errors;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _cachePushStatus = '推送未完成：$e');
    } finally {
      if (mounted) setState(() => _pushingCache = false);
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
        const SectionTitle('Kikoeta-LLS'),
        KtGroup(
          children: [
            KtSwitchRow(
              icon: Icons.cloud_upload_outlined,
              title: '来自 Kikoeta 的翻译请求，产物同步上传到 Kikoeta-LLS',
              sub: '任务成功完成后上传歌词；本地任务不受影响',
              value: llsSync,
              onChanged: (value) => setState(() => llsSync = value),
              showDivider: false,
            ),
          ],
        ),
        const SizedBox(height: 10),
        ExcludeFocus(
          excluding: _pushingCache,
          child: AbsorbPointer(
            absorbing: _pushingCache,
            child: KtGroup(
              children: [
                KtField(
                  controller: llsUrl,
                  label: 'Kikoeta-LLS 地址（HTTP/HTTPS）',
                  hint: '留空使用本机 http://127.0.0.1:2378',
                ),
                KtSelectField<String>(
                  label: '上传验证方式',
                  value: llsAuthMode,
                  values: const ['key', 'basic'],
                  labelOf: (value) => value == 'key' ? '12 位密钥' : '独立账号和密码',
                  onChanged: (value) => setState(() => llsAuthMode = value),
                ),
                if (llsAuthMode == 'key')
                  KtField(
                    controller: llsKey,
                    label: '上传密钥',
                    hint: '在 Kikoeta-LLS 设置页生成或手动设置 12 位密钥',
                    obscure: true,
                  )
                else ...[
                  KtField(controller: llsUsername, label: '上传账号'),
                  KtField(
                    controller: llsPassword,
                    label: '上传密码',
                    obscure: true,
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        KtGroup(
          children: [
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '将最近 5 次 Kikoeta 任务中保留的 LRC 缓存推送到 LLS。'
                    '使用上方地址和验证配置，无需开启自动同步。'
                    '同名歌词会覆盖，推送后保留本地缓存。',
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _pushingCache ? null : _pushCache,
                    icon: const Icon(Icons.cloud_upload_outlined),
                    label: Text(_pushingCache ? '正在推送…' : '将缓存推送到 LLS'),
                  ),
                  if (_pushingCache) ...[
                    const SizedBox(height: 10),
                    const LinearProgressIndicator(),
                  ],
                  if (_cachePushStatus.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(_cachePushStatus),
                  ],
                  if (_cachePushErrors.isNotEmpty)
                    Material(
                      type: MaterialType.transparency,
                      child: ExpansionTile(
                        tilePadding: EdgeInsets.zero,
                        title: const Text('查看失败详情'),
                        children: [
                          for (final error in _cachePushErrors)
                            ListTile(title: SelectableText(error)),
                        ],
                      ),
                    ),
                ],
              ),
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
