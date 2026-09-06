import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

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

  String _title(String category) {
    switch (category) {
      case 'gpt':
        return 'GPT 字典';
      case 'post':
        return '译后';
      default:
        return '译前';
    }
  }

  Future<void> _openInEditor(BuildContext context, Map<String, dynamic> item) async {
    final path = '${item['path'] ?? ''}'.trim();
    if (path.isEmpty) return;
    final file = File(path);
    String content;
    try {
      content = await file.readAsString(encoding: utf8);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('无法读取字典：$e')),
        );
      }
      return;
    }

    final controller = TextEditingController(text: content);
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => _DictionaryEditorDialog(
        name: '${item['name'] ?? file.path}',
        path: file.path,
        controller: controller,
        onSave: () async {
          await file.writeAsString(controller.text, encoding: utf8);
          if (dialogContext.mounted) Navigator.of(dialogContext).pop(true);
        },
      ),
    );
    controller.dispose();
    if (saved == true) {
      try {
        await app.refreshTools();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('字典已保存')));
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('字典已保存，但刷新失败：$e')));
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
          'pre': [for (final item in dicts) if (item['category'] == 'pre') item],
          'gpt': [for (final item in dicts) if (item['category'] == 'gpt') item],
          'post': [for (final item in dicts) if (item['category'] == 'post') item],
        };
        return ListView(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 24),
          children: [
            const Text('字典', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(
              '直接使用 GalTransl 内置 Dict。点击条目会在 kt 内置编辑器中打开。',
              style: TextStyle(fontSize: 12, color: p.muted),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () async {
                  try {
                    await app.refreshTools();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('已刷新，发现 ${_dicts().length} 个字典')),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('刷新失败：$e')),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('刷新字典'),
              ),
            ),
            if (dicts.isEmpty) ...[
              const SectionTitle('GalTransl Dict'),
              KtGroup(children: [
                KtRow(
                  icon: Icons.menu_book_outlined,
                  title: '未找到字典文件',
                  sub: dictDir,
                  showDivider: false,
                ),
              ]),
            ],
            for (final category in ['pre', 'gpt', 'post'])
              if ((groups[category] ?? const []).isNotEmpty) ...[
                SectionTitle(_title(category)),
                KtGroup(children: [
                  for (var i = 0; i < groups[category]!.length; i++)
                    KtRow(
                      icon: Icons.menu_book_outlined,
                      title: '${groups[category]![i]['name'] ?? ''}',
                      sub: '${groups[category]![i]['count'] ?? 0} 条 · 点击编辑',
                      trailing: Icon(Icons.edit_outlined, size: 18, color: p.dim),
                      onTap: () => _openInEditor(context, groups[category]![i]),
                      showDivider: i != groups[category]!.length - 1,
                    ),
                ]),
              ],
          ],
        );
      },
    );
  }
}

class _DictionaryEditorDialog extends StatefulWidget {
  final String name;
  final String path;
  final TextEditingController controller;
  final Future<void> Function() onSave;

  const _DictionaryEditorDialog({
    required this.name,
    required this.path,
    required this.controller,
    required this.onSave,
  });

  @override
  State<_DictionaryEditorDialog> createState() => _DictionaryEditorDialogState();
}

class _DictionaryEditorDialogState extends State<_DictionaryEditorDialog> {
  bool saving = false;
  String? error;

  Future<void> _save() async {
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await widget.onSave();
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
      child: SizedBox(
        width: 900,
        height: 680,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              const SizedBox(height: 3),
              Text(widget.path, style: TextStyle(fontSize: 11, color: p.dim), overflow: TextOverflow.ellipsis),
              const SizedBox(height: 12),
              Expanded(
                child: TextField(
                  controller: widget.controller,
                  expands: true,
                  maxLines: null,
                  minLines: null,
                  textAlignVertical: TextAlignVertical.top,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 13, height: 1.35),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: p.surface2,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.all(14),
                  ),
                ),
              ),
              if (error != null) ...[
                const SizedBox(height: 8),
                Text('保存失败：$error', style: TextStyle(color: p.red, fontSize: 12)),
              ],
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: saving ? null : () => Navigator.of(context).pop(false), child: const Text('取消')),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: saving ? null : _save,
                    icon: saving
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.save_outlined, size: 17),
                    label: Text(saving ? '保存中…' : '保存'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
