import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../l10n/strings.dart';
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
      if (!await File(path).exists()) {
        throw FileSystemException(appL10n.fileNotFound);
      }
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
      ).showSnackBar(SnackBar(content: Text(appL10n.openFileFailed(error))));
    }
  }

  Future<void> _deleteCache(Map<String, dynamic> entry) async {
    final id = entry['job_id']?.toString() ?? '';
    if (id.isEmpty || _deleting != null) return;
    final approved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(dialogContext.l10n.deleteTranslationCacheTitle),
        content: Text(dialogContext.l10n.deleteTranslationCacheDescription),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(dialogContext.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(dialogContext.l10n.deleteCache),
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
      ).showSnackBar(SnackBar(content: Text(appL10n.cacheFreed(_size(freed)))));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(appL10n.cleanupFailed(error))));
    } finally {
      if (mounted) setState(() => _deleting = null);
    }
  }

  Future<void> _deleteEntry(Map<String, dynamic> entry) async {
    final id = entry['job_id']?.toString() ?? '';
    if (id.isEmpty || _deleting != null) return;
    final approved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(dialogContext.l10n.deleteRecentTitle),
        content: Text(dialogContext.l10n.deleteRecentDescription),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(dialogContext.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(dialogContext.l10n.deleteRecord),
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
      ).showSnackBar(SnackBar(content: Text(appL10n.recordDeleted)));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(appL10n.deleteFailed(error))));
    } finally {
      if (mounted) setState(() => _deleting = null);
    }
  }

  Future<void> _deleteAllEntries() async {
    if (_entries.isEmpty || _deleting != null) return;
    final count = _entries.length;
    final approved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(dialogContext.l10n.deleteAllRecentTitle),
        content: Text(dialogContext.l10n.deleteAllRecentDescription(count)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(dialogContext.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(dialogContext.l10n.deleteAll),
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
      ).showSnackBar(SnackBar(content: Text(appL10n.recordsDeleted(deleted))));
    } catch (error) {
      if (mounted) await _refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(appL10n.deleteFailed(error))));
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
    if (parsed == null) return context.l10n.legacyTask;
    final local = parsed.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final colors = paletteOf(context);
    return KtPage(
      title: context.l10n.recent,
      description: context.l10n.recentDescription,
      columns: false,
      actions: [
        IconButton(
          tooltip: context.l10n.deleteAllRecords,
          onPressed: _loading || _entries.isEmpty || _deleting != null
              ? null
              : _deleteAllEntries,
          icon: const Icon(Icons.delete_sweep_outlined, size: 20),
        ),
        IconButton(
          tooltip: context.l10n.refresh,
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
            title: context.l10n.loadFailed,
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
            title: context.l10n.translationHistory,
            icon: Icons.history,
            children: [
              Text(
                context.l10n.noTranslationCache,
                style: TextStyle(fontSize: 12, color: colors.dim),
              ),
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
    final source = entry['source'] == 'kikoeta'
        ? context.l10n.kikoetaSourceSuffix
        : '';
    final status = switch (entry['status']) {
      'completed' => context.l10n.statusCompleted,
      'failed' => context.l10n.statusFailed,
      'cancelled' => context.l10n.statusCancelled,
      _ => context.l10n.legacyTask,
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
          context.l10n.recentTaskDetails(
            _time('${entry['finished_at'] ?? entry['created_at'] ?? ''}'),
            id,
            source,
            _size(bytes),
          ),
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
                label: Text(
                  _deleting == id
                      ? context.l10n.clearing
                      : context.l10n.deleteCache,
                ),
              ),
              IconButton(
                tooltip: context.l10n.deleteRecordKeepOutput,
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
              context.l10n.noLyricsOutput,
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
              outputs[i]['exists'] == true
                  ? context.l10n.open
                  : context.l10n.fileMoved,
              style: TextStyle(fontSize: 11, color: colors.dim),
            ),
          ),
      ],
    );
  }
}
