import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../app_state.dart';
import '../widgets.dart';

class RecentPage extends StatefulWidget {
  final AppState app;
  const RecentPage({super.key, required this.app});

  @override
  State<RecentPage> createState() => _RecentPageState();
}

class _RecentPageState extends State<RecentPage> {
  List<Map<String, dynamic>> _entries = const [];
  bool _loading = false;
  String? _error;
  String? _deleting;

  @override
  void initState() {
    super.initState();
    widget.app.tabNotifier.addListener(_onTabChanged);
    if (widget.app.tab == 7) _refresh();
  }

  @override
  void dispose() {
    widget.app.tabNotifier.removeListener(_onTabChanged);
    super.dispose();
  }

  void _onTabChanged() {
    if (widget.app.tab == 7) _refresh();
  }

  Future<void> _refresh() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final entries = await widget.app.engine.recentJobs();
      if (mounted) setState(() => _entries = entries);
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openFile(String path) async {
    try {
      if (!await File(path).exists()) throw const FileSystemException('文件不存在');
      if (Platform.isWindows) {
        await Process.start('explorer.exe', [
          path,
        ], mode: ProcessStartMode.detached);
      } else if (Platform.isMacOS) {
        await Process.start('open', [path], mode: ProcessStartMode.detached);
      } else {
        await Process.start('xdg-open', [
          path,
        ], mode: ProcessStartMode.detached);
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('打开文件失败：$error')));
    }
  }

  Future<void> _deleteCache(Map<String, dynamic> entry) async {
    final id = entry['job_id']?.toString() ?? '';
    if (id.isEmpty || _deleting != null) return;
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除翻译缓存？'),
        content: const Text(
          '仅删除此任务的 GalTransl 工作缓存；已导出的成果文件和 Kikoeta 歌词同步缓存不会删除。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除缓存'),
          ),
        ],
      ),
    );
    if (approved != true || !mounted) return;
    setState(() => _deleting = id);
    try {
      final freed = await widget.app.engine.deleteRecentCache(id);
      await _refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('已清理 ${_size(freed)} 翻译缓存')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('清理失败：$error')));
    } finally {
      if (mounted) setState(() => _deleting = null);
    }
  }

  String _size(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  String _time(String value) {
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return '旧任务';
    final local = parsed.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final colors = paletteOf(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 24),
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                '最近',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
            ),
            IconButton(
              tooltip: '刷新',
              onPressed: _loading ? null : _refresh,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        Text(
          '最近的翻译任务与 GalTransl 工作缓存。清理缓存不会删除导出的文件。',
          style: TextStyle(fontSize: 12, color: colors.muted),
        ),
        if (_loading) const LinearProgressIndicator(),
        if (_error != null) ...[
          const SizedBox(height: 16),
          Text('加载失败：$_error', style: TextStyle(color: colors.muted)),
        ],
        if (!_loading && _error == null && _entries.isEmpty) ...[
          const SizedBox(height: 24),
          Text('暂无翻译缓存', style: TextStyle(color: colors.dim)),
        ],
        for (final entry in _entries) _entryCard(entry),
      ],
    );
  }

  Widget _entryCard(Map<String, dynamic> entry) {
    final colors = paletteOf(context);
    final id = entry['job_id']?.toString() ?? '';
    final files =
        (entry['files'] as List?)?.map((item) => '$item').toList() ??
        const <String>[];
    final outputs = (entry['outputs'] as List?) ?? const [];
    final bytes = (entry['cache_bytes'] as num?)?.toInt() ?? 0;
    final cacheCount = (entry['cache_dir_count'] as num?)?.toInt() ?? 0;
    final source = entry['source'] == 'kikoeta' ? ' · 来自 Kikoeta' : '';
    final status = switch (entry['status']) {
      'completed' => '已完成',
      'failed' => '失败',
      'cancelled' => '已取消',
      _ => '旧任务',
    };
    final title = files.isEmpty ? id : files.join('、');
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: KtGroup(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_time('${entry['finished_at'] ?? entry['created_at'] ?? ''}')} '
                        '· $status · $id$source · 缓存 ${_size(bytes)}',
                        style: TextStyle(fontSize: 11, color: colors.dim),
                      ),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: cacheCount == 0 || _deleting != null
                      ? null
                      : () => _deleteCache(entry),
                  icon: const Icon(Icons.delete_outline, size: 17),
                  label: Text(_deleting == id ? '清理中' : '删除缓存'),
                ),
              ],
            ),
          ),
          if (outputs.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '未记录成果文件（旧任务可能只保留缓存）',
                  style: TextStyle(fontSize: 12, color: colors.dim),
                ),
              ),
            ),
          for (var i = 0; i < outputs.length; i++)
            if (outputs[i] is Map)
              KtRow(
                icon: Icons.description_outlined,
                title: p.basename('${outputs[i]['path'] ?? ''}'),
                sub: '${outputs[i]['path'] ?? ''}',
                showDivider: i != outputs.length - 1,
                onTap: outputs[i]['exists'] == true
                    ? () => _openFile('${outputs[i]['path']}')
                    : null,
                trailing: Text(
                  outputs[i]['exists'] == true ? '打开' : '文件已移走',
                  style: TextStyle(fontSize: 11, color: colors.dim),
                ),
              ),
        ],
      ),
    );
  }
}
