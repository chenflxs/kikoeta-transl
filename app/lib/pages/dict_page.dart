import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../app_state.dart';
import '../widgets.dart';

class DictPage extends StatelessWidget {
  final AppState app;
  const DictPage({super.key, required this.app});

  List<Map<String, dynamic>> _dicts() {
    final raw = app.tools['gt_dicts'];
    if (raw is! List) return const [];
    return [
      for (final item in raw)
        if (item is Map) Map<String, dynamic>.from(item),
    ];
  }

  String _title(BuildContext context, String category) {
    switch (category) {
      case 'gpt':
        return context.l10n.gptDictionary;
      case 'post':
        return context.l10n.postTranslation;
      default:
        return context.l10n.preTranslation;
    }
  }

  Future<void> _openInEditor(
    BuildContext context,
    Map<String, dynamic> item,
  ) async {
    final path = '${item['path'] ?? ''}'.trim();
    if (path.isEmpty) return;
    final file = File(path);
    String content;
    try {
      content = await file.readAsString(encoding: utf8);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(appL10n.dictionaryReadFailed(e))),
        );
      }
      return;
    }

    if (!context.mounted) return;
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => _DictionaryEditorDialog(
        name: '${item['name'] ?? file.path}',
        path: file.path,
        content: content,
        onSave: (text) async {
          await file.writeAsString(text, encoding: utf8);
          if (dialogContext.mounted) Navigator.of(dialogContext).pop(true);
        },
      ),
    );
    if (saved == true) {
      try {
        await app.refreshTools();
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(appL10n.dictionarySaved)));
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(appL10n.dictionaryRefreshFailed(e))),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final p = paletteOf(context);
        final dicts = _dicts();
        final dictDir = '${app.tools['dict_dir'] ?? 'engine/GalTransl/Dict'}';
        final groups = {
          'pre': [
            for (final item in dicts)
              if (item['category'] == 'pre') item,
          ],
          'gpt': [
            for (final item in dicts)
              if (item['category'] == 'gpt') item,
          ],
          'post': [
            for (final item in dicts)
              if (item['category'] == 'post') item,
          ],
        };
        return KtPage(
          title: context.l10n.dictionaries,
          description: context.l10n.dictionaryDescription,
          actions: [
            TextButton.icon(
              onPressed: () async {
                try {
                  await app.refreshTools();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          context.l10n.dictionariesFound(_dicts().length),
                        ),
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(context.l10n.refreshFailed(e))),
                    );
                  }
                }
              },
              icon: const Icon(Icons.refresh, size: 18),
              label: Text(context.l10n.refreshDictionaries),
            ),
          ],
          children: [
            if (dicts.isEmpty)
              KtSection(
                title: 'GalTransl Dict',
                icon: Icons.menu_book_outlined,
                children: [
                  KtRow(
                    icon: Icons.menu_book_outlined,
                    title: context.l10n.noDictionaries,
                    sub: dictDir,
                    showDivider: false,
                  ),
                ],
              ),
            for (final category in ['pre', 'gpt', 'post'])
              if ((groups[category] ?? const []).isNotEmpty)
                KtSection(
                  title: _title(context, category),
                  icon: Icons.menu_book_outlined,
                  children: [
                    for (var i = 0; i < groups[category]!.length; i++)
                      KtRow(
                        icon: Icons.menu_book_outlined,
                        title: '${groups[category]![i]['name'] ?? ''}',
                        sub: context.l10n.dictionaryEntryCount(
                          groups[category]![i]['count'] ?? 0,
                        ),
                        trailing: Icon(
                          Icons.edit_outlined,
                          size: 18,
                          color: p.dim,
                        ),
                        onTap: () =>
                            _openInEditor(context, groups[category]![i]),
                        showDivider: i != groups[category]!.length - 1,
                      ),
                  ],
                ),
          ],
        );
      },
    );
  }
}

class _DictionaryEditorDialog extends StatefulWidget {
  final String name;
  final String path;
  final String content;
  final Future<void> Function(String) onSave;

  const _DictionaryEditorDialog({
    required this.name,
    required this.path,
    required this.content,
    required this.onSave,
  });

  @override
  State<_DictionaryEditorDialog> createState() =>
      _DictionaryEditorDialogState();
}

class _DictionaryEditorDialogState extends State<_DictionaryEditorDialog> {
  late final TextEditingController controller;
  bool saving = false;
  String? error;

  @override
  void initState() {
    super.initState();
    controller = TextEditingController(text: widget.content);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await widget.onSave(controller.text);
    } catch (e) {
      if (mounted) {
        setState(() {
          saving = false;
          error = '$e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = paletteOf(context);
    return Dialog(
      backgroundColor: p.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        width: 900,
        height: 680,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                widget.path,
                style: TextStyle(fontSize: 11, color: p.dim),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              Expanded(
                child: TextField(
                  controller: controller,
                  expands: true,
                  maxLines: null,
                  minLines: null,
                  textAlignVertical: TextAlignVertical.top,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 13,
                    height: 1.65,
                  ),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: p.surface2,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(11),
                      borderSide: BorderSide(color: p.line),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(11),
                      borderSide: BorderSide(color: p.line),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(11),
                      borderSide: BorderSide(color: p.accent),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 14,
                    ),
                  ),
                ),
              ),
              if (error != null) ...[
                const SizedBox(height: 8),
                Text(
                  context.l10n.saveFailed(error!),
                  style: TextStyle(color: p.red, fontSize: 12),
                ),
              ],
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    TextButton(
                      onPressed: saving
                          ? null
                          : () => Navigator.of(context).pop(false),
                      child: Text(context.l10n.cancel),
                    ),
                    FilledButton.icon(
                      onPressed: saving ? null : _save,
                      icon: saving
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save_outlined, size: 17),
                      label: Text(
                        saving ? context.l10n.saving : context.l10n.save,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
