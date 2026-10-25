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

  Future<void> _deleteEntry(Map<String, dynamic> entry) async {
    final id = entry['job_id']?.toString() ?? '';
    if (id.isEmpty || _deleting != null) return;
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除这条最近记录？'),
        content: const Text('将删除此任务的工作文件和缓存，并从最近列表移除记录。已导出的成果文件会保留。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除记录'),
          ),
        ],
      ),
    );
    if (approved != true || !mounted) return;
    setState(() => _deleting = id);
    try {
      await widget.app.engine.deleteRecentJob(id);
      await _refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('记录已删除，成果文件已保留')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('删除失败：$error')));
    } finally {
      if (mounted) setState(() => _deleting = null);
    }
  }

  Future<void> _deleteAllEntries() async {
    if (_entries.isEmpty || _deleting != null) return;
    final count = _entries.length;
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除全部最近记录？'),
        content: Text('将删除当前 $count 条记录对应的工作文件和缓存。已导出的成果文件会保留。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('全部删除'),
          ),
        ],
      ),
    );
    if (approved != true || !mounted) return;
    setState(() => _deleting = '*');
    try {
      final deleted = await widget.app.engine.deleteAllRecentJobs();
      await _refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('已删除 $deleted 条记录，成果文件已保留')));
    } catch (error) {
      if (mounted) await _refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('删除失败：$error')));
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
    return KtPage(
      title: '最近',
      description: '最近的翻译任务与 GalTransl 工作缓存。清理缓存不会删除导出的文件。',
      columns: false,
      actions: [
        IconButton(
          tooltip: '一键删除所有记录',
          onPressed: _loading || _entries.isEmpty || _deleting != null
              ? null
              : _deleteAllEntries,
          icon: const Icon(Icons.delete_sweep_outlined, size: 20),
        ),
        IconButton(
          tooltip: '刷新',
          onPressed: _loading ? null : _refresh,
          icon: const Icon(Icons.refresh, size: 20),
        ),
      ],
      children: [
        if (_loading)
          LinearProgressIndicator(
            minHeight: 6,
            borderRadius: BorderRadius.circular(999),
          ),
        if (_error != null)
          KtSection(
            title: '加载失败',
            icon: Icons.error_outline,
            children: [
              Text(
                '$_error',
                style: TextStyle(
                  fontSize: 12,
                  color: colors.muted,
                  height: 1.4,
                ),
              ),
            ],
          ),
        if (!_loading && _error == null && _entries.isEmpty)
          KtSection(
            title: '翻译记录',
            icon: Icons.history,
            children: [
              Text('暂无翻译缓存', style: TextStyle(fontSize: 12, color: colors.dim)),
            ],
          ),
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
    const lyricExtensions = {'.lrc', '.srt', '.vtt', '.ass', '.ssa'};
    final outputs = ((entry['outputs'] as List?) ?? const [])
        .whereType<Map>()
        .where(
          (output) => lyricExtensions.contains(
            p.extension('${output['path'] ?? ''}').toLowerCase(),
          ),
        )
        .toList();
    final bytes = (entry['cache_bytes'] as num?)?.toInt() ?? 0;
    final cacheCount = (entry['cache_dir_count'] as num?)?.toInt() ?? 0;
    final source = entry['source'] == 'kikoeta' ? ' · 来自 Kikoeta' : '';
    final status = switch (entry['status']) {
      'completed' => '已完成',
      'failed' => '失败',
      'cancelled' => '已取消',
      _ => '旧任务',
    };
    final statusColor = switch (entry['status']) {
      'completed' => colors.green,
      'failed' => colors.red,
      _ => colors.dim,
    };
    final title = files.isEmpty ? id : files.join('、');
    return KtSection(
      title: title,
      icon: Icons.history,
      action: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: statusColor.withValues(alpha: .10),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          status,
          style: TextStyle(
            fontSize: 10.5,
            color: statusColor,
            fontFamily: 'SarasaUI',
          ),
        ),
      ),
      children: [
        Text(
          '${_time('${entry['finished_at'] ?? entry['created_at'] ?? ''}')} '
          '· $id$source · 缓存 ${_size(bytes)}',
          style: TextStyle(fontSize: 11.5, color: colors.muted, height: 1.4),
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerRight,
          child: Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              TextButton.icon(
                onPressed: cacheCount == 0 || _deleting != null
                    ? null
                    : () => _deleteCache(entry),
                icon: const Icon(Icons.delete_outline, size: 18),
                label: Text(_deleting == id ? '清理中' : '删除缓存'),
              ),
              IconButton(
                tooltip: '删除记录（保留成果文件）',
                onPressed: _deleting != null ? null : () => _deleteEntry(entry),
                style: IconButton.styleFrom(foregroundColor: colors.red),
                icon: const Icon(Icons.delete_forever_outlined, size: 20),
              ),
            ],
          ),
        ),
        if (outputs.isEmpty)
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '暂无可显示的成品歌词',
              style: TextStyle(fontSize: 12, color: colors.dim),
            ),
          ),
        for (var i = 0; i < outputs.length; i++)
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
    );
  }
}
