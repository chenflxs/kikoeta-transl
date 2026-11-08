import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../app_state.dart';
import '../settings_draft.dart';
import '../widgets.dart';

const _presets = [
  'target_lrc',
  'target_srt',
  'bilingual_lrc',
  'bilingual_srt',
  'source_target_lrc',
  'source_target_srt',
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
  String Function() _cachePushMessage = () => '';
  String get _cachePushStatus => _cachePushMessage();
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
    if (_presets.contains(raw)) return raw;
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
    final l10n = context.l10n;
    final (label, description) = switch (id) {
      'target_lrc' => (l10n.targetLrc, l10n.targetLrcDescription),
      'target_srt' => (l10n.targetSrt, l10n.targetSrtDescription),
      'bilingual_lrc' => (l10n.bilingualLrc, l10n.translationFirstDescription),
      'bilingual_srt' => (l10n.bilingualSrt, l10n.translationFirstDescription),
      'source_target_lrc' => (
        l10n.sourceTargetLrc,
        l10n.sourceFirstDescription,
      ),
      'source_target_srt' => (
        l10n.sourceTargetSrt,
        l10n.sourceFirstDescription,
      ),
      _ => (id, ''),
    };
    return description.isEmpty ? label : '$label  ·  $description';
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
      ).showSnackBar(SnackBar(content: Text(appL10n.outputSettingsSaved)));
    }
  }

  Future<void> _pushCache() async {
    if (_pushingCache) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _pushingCache = true;
      _cachePushMessage = () => appL10n.readingLyricsCache;
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
          final current = processed + 1;
          final label = '${entry['work_id']} / ${file['track_path']}';
          setState(
            () =>
                _cachePushMessage = () =>
                    appL10n.pushingCacheProgress(current, total, label),
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
        _cachePushMessage = () => total == 0
            ? appL10n.noLyricsCacheToPush
            : appL10n.cachePushCompleted(uploaded, errors.length);
        _cachePushErrors = errors;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _cachePushMessage = () => appL10n.cachePushFailed(e));
    } finally {
      if (mounted) setState(() => _pushingCache = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_presets.contains(preset)) {
      preset = 'target_lrc';
    }
    final p = paletteOf(context);
    return KtPage(
      title: context.l10n.output,
      footer: Align(
        alignment: Alignment.centerRight,
        child: FilledButton.icon(
          onPressed: () => _save(),
          icon: const Icon(Icons.save_outlined, size: 18),
          label: Text(context.l10n.save),
        ),
      ),
      children: [
        KtSection(
          title: context.l10n.files,
          icon: Icons.folder_outlined,
          children: [
            KtField(
              controller: directory,
              label: context.l10n.outputDirectory,
              hint: context.l10n.outputDirectoryHint,
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                TextButton.icon(
                  onPressed: () async {
                    final dir = await FilePicker.platform.getDirectoryPath();
                    if (dir != null) setState(() => directory.text = dir);
                  },
                  icon: const Icon(Icons.folder_open_outlined, size: 18),
                  label: Text(context.l10n.chooseDirectory),
                ),
                TextButton(
                  onPressed: () => setState(() => directory.text = ''),
                  child: Text(context.l10n.useSourceDirectory),
                ),
              ],
            ),
          ],
        ),
        KtSection(
          title: context.l10n.format,
          icon: Icons.subtitles_outlined,
          children: [
            KtSelectField<String>(
              label: context.l10n.outputFormat,
              value: preset,
              values: _presets,
              labelOf: _labelOf,
              onChanged: (value) => setState(() => preset = value),
            ),
          ],
        ),
        KtSection(
          title: 'Kikoeta-LLS',
          icon: Icons.cloud_upload_outlined,
          children: [
            KtSwitchRow(
              icon: Icons.cloud_upload_outlined,
              title: context.l10n.llsSyncTitle,
              sub: context.l10n.llsSyncDescription,
              value: llsSync,
              onChanged: (value) => setState(() => llsSync = value),
              showDivider: false,
            ),
            const SizedBox(height: 6),
            ExcludeFocus(
              excluding: _pushingCache,
              child: AbsorbPointer(
                absorbing: _pushingCache,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    KtField(
                      controller: llsUrl,
                      label: context.l10n.llsUrl,
                      hint: context.l10n.llsUrlHint,
                    ),
                    KtSelectField<String>(
                      label: context.l10n.uploadAuthentication,
                      value: llsAuthMode,
                      values: const ['key', 'basic'],
                      labelOf: (value) => value == 'key'
                          ? context.l10n.twelveCharacterKey
                          : context.l10n.separateCredentials,
                      onChanged: (value) => setState(() => llsAuthMode = value),
                    ),
                    if (llsAuthMode == 'key')
                      KtField(
                        controller: llsKey,
                        label: context.l10n.uploadKey,
                        hint: context.l10n.uploadKeyHint,
                        obscure: true,
                      )
                    else ...[
                      KtField(
                        controller: llsUsername,
                        label: context.l10n.uploadUsername,
                      ),
                      KtField(
                        controller: llsPassword,
                        label: context.l10n.uploadPassword,
                        obscure: true,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
        KtSection(
          title: context.l10n.lyricsCache,
          icon: Icons.cached_outlined,
          children: [
            Text(
              context.l10n.lyricsCacheDescription,
              style: TextStyle(fontSize: 12, color: p.muted, height: 1.4),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _pushingCache ? null : _pushCache,
              icon: const Icon(Icons.cloud_upload_outlined, size: 18),
              label: Text(
                _pushingCache
                    ? context.l10n.pushingCache
                    : context.l10n.pushCacheToLls,
              ),
            ),
            if (_pushingCache) ...[
              const SizedBox(height: 10),
              LinearProgressIndicator(
                minHeight: 6,
                borderRadius: BorderRadius.circular(999),
              ),
            ],
            if (_cachePushStatus.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                _cachePushStatus,
                style: TextStyle(fontSize: 12, color: p.text, height: 1.4),
              ),
            ],
            if (_cachePushErrors.isNotEmpty)
              Material(
                type: MaterialType.transparency,
                child: ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: Text(
                    context.l10n.viewFailureDetails,
                    style: TextStyle(
                      fontSize: 13,
                      color: p.text,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  children: [
                    for (final error in _cachePushErrors)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: SelectableText(
                          error,
                          style: TextStyle(
                            fontSize: 12,
                            color: p.muted,
                            height: 1.65,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }
}
