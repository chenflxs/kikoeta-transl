import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../app_state.dart';
import '../widgets.dart';

class TaskPage extends StatefulWidget {
  final AppState app;
  const TaskPage({super.key, required this.app});

  @override
  State<TaskPage> createState() => _TaskPageState();
}

class _TaskPageState extends State<TaskPage> {
  final ScrollController _logController = ScrollController();
  var _stickLogsToBottom = true;
  var _lastLogCount = 0;
  String? _lastLog;

  @override
  void initState() {
    super.initState();
    _logController.addListener(_onLogScroll);
  }

  @override
  void dispose() {
    _logController
      ..removeListener(_onLogScroll)
      ..dispose();
    super.dispose();
  }

  void _onLogScroll() {
    if (!_logController.hasClients) return;
    final position = _logController.position;
    _stickLogsToBottom = position.maxScrollExtent - position.pixels <= 48;
  }

  void _scheduleLogScroll(AppState app) {
    final lastLog = app.logs.isEmpty ? null : app.logs.last;
    final changed = app.logs.length != _lastLogCount || lastLog != _lastLog;
    if (!changed) return;
    _lastLogCount = app.logs.length;
    _lastLog = lastLog;
    if (!_stickLogsToBottom) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_stickLogsToBottom || !_logController.hasClients) {
        return;
      }
      final position = _logController.position;
      if (position.hasContentDimensions) {
        _logController.jumpTo(position.maxScrollExtent);
      }
    });
  }

  Future<void> _exportLogs(AppState app) async {
    if (app.logs.isEmpty) return;
    final logSnapshot = List<String>.unmodifiable(app.logs);
    final now = DateTime.now();
    String twoDigits(int value) => value.toString().padLeft(2, '0');
    final fileName =
        'kikoeta-log-${now.year}${twoDigits(now.month)}${twoDigits(now.day)}-'
        '${twoDigits(now.hour)}${twoDigits(now.minute)}${twoDigits(now.second)}.txt';
    try {
      final path = await FilePicker.platform.saveFile(
        dialogTitle: '导出日志',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: ['txt'],
      );
      if (path == null || path.isEmpty) return;
      await File(path).writeAsString('${logSnapshot.join('\n')}\n');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('日志已导出')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('日志导出失败：$error')));
    }
  }

  String _statusLabel(String status) => switch (status) {
    'queued' => '待处理',
    'running' => '处理中',
    'pausing' => '正在暂存',
    'paused' => '已暂存',
    'cancelling' => '正在取消',
    'completed' || 'done' => '已完成',
    'failed' => '失败',
    'cancelled' => '已取消',
    _ => status,
  };

  ButtonStyle get _textActionStyle => TextButton.styleFrom(
    foregroundColor: paletteOf(context).muted,
    textStyle: const TextStyle(fontFamily: 'SarasaUI', fontSize: 12),
    padding: const EdgeInsets.symmetric(horizontal: 8),
    minimumSize: const Size(0, 36),
  );

  Widget _stageRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget trailing,
    VoidCallback? onTap,
  }) {
    final p = paletteOf(context);
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      minLeadingWidth: 24,
      horizontalTitleGap: 10,
      onTap: onTap,
      leading: Icon(icon, size: 18, color: p.muted),
      title: Text(
        title,
        style: TextStyle(
          color: p.text,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: p.muted, fontSize: 11.5),
      ),
      trailing: trailing,
    );
  }

  Widget _stageCard(AppState app) {
    final p = paletteOf(context);
    return KtSection(
      title: '处理阶段',
      icon: Icons.tune_outlined,
      children: [
        _stageRow(
          icon: Icons.graphic_eq,
          title: '转码 + ASR',
          subtitle: '音频 / 视频必做；字幕输入自动跳过',
          trailing: Text('固定', style: TextStyle(fontSize: 12, color: p.dim)),
        ),
        Divider(height: 1, color: p.line),
        _stageRow(
          icon: Icons.auto_fix_high,
          title: '矫正',
          subtitle: '只修听写，不翻译',
          onTap: () => app.setStageFlag('correct', !app.enableCorrect),
          trailing: Switch(
            value: app.enableCorrect,
            activeTrackColor: p.accent,
            onChanged: (value) => app.setStageFlag('correct', value),
          ),
        ),
        Divider(height: 1, color: p.line),
        _stageRow(
          icon: Icons.translate,
          title: '翻译',
          subtitle: '使用已配置的翻译器',
          onTap: () => app.setStageFlag('translate', !app.enableTranslate),
          trailing: Switch(
            value: app.enableTranslate,
            activeTrackColor: p.accent,
            onChanged: (value) => app.setStageFlag('translate', value),
          ),
        ),
      ],
    );
  }

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(allowMultiple: true);
    if (result != null && mounted) {
      widget.app.addFiles(result.paths.whereType<String>());
    }
  }

  Widget _inputCard(AppState app) {
    final p = paletteOf(context);
    final stopping = app.jobStatus == 'cancelling';
    return KtSection(
      title: '输入文件',
      icon: Icons.library_music_outlined,
      action: TextButton.icon(
        onPressed: app.files.isEmpty ? null : app.clearFiles,
        icon: const Icon(Icons.playlist_remove_outlined, size: 18),
        label: const Text('清空列表'),
        style: _textActionStyle,
      ),
      children: [
        DropTarget(
          onDragDone: (detail) =>
              app.addFiles(detail.files.map((file) => file.path)),
          child: Material(
            color: p.surface2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: p.line),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: _pickFiles,
              child: Container(
                width: double.infinity,
                constraints: const BoxConstraints(minHeight: 92),
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Icon(Icons.file_upload_outlined, color: p.accent, size: 24),
                    const SizedBox(height: 6),
                    Text(
                      app.files.isEmpty
                          ? '拖入音视频或字幕，或点击选择'
                          : '已选择 ${app.files.length} 个文件，点击继续添加',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: p.muted, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (app.files.isNotEmpty) ...[
          const SizedBox(height: 10),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 230),
            child: ListView.builder(
              primary: false,
              shrinkWrap: true,
              itemCount: app.files.length,
              itemBuilder: (context, index) {
                final file = app.files[index];
                return ListTile(
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                  minLeadingWidth: 24,
                  horizontalTitleGap: 10,
                  leading: Icon(
                    Icons.audio_file_outlined,
                    color: p.dim,
                    size: 17,
                  ),
                  title: Text(
                    file.split(RegExp(r'[\\/]')).last,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: p.text, fontSize: 12.5),
                  ),
                  subtitle: Text(
                    file,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: p.dim, fontSize: 11),
                  ),
                  trailing: IconButton(
                    tooltip: '移除文件',
                    onPressed: () => app.removeFile(file),
                    icon: Icon(Icons.close, size: 16, color: p.dim),
                  ),
                );
              },
            ),
          ),
        ],
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: app.hasActiveJob ? p.red : p.accent,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(44),
              textStyle: const TextStyle(
                fontFamily: 'SarasaUI',
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: app.submittingJob
                ? null
                : app.hasActiveJob
                ? (stopping ? null : app.cancelJob)
                : (app.engineOnline && app.files.isNotEmpty
                      ? app.startJob
                      : null),
            icon: Icon(
              app.submittingJob
                  ? Icons.hourglass_empty
                  : app.hasActiveJob
                  ? Icons.stop_circle_outlined
                  : Icons.graphic_eq,
            ),
            label: Text(
              app.submittingJob
                  ? '正在提交…'
                  : app.hasActiveJob
                  ? (stopping ? '正在停止…' : '停止工作流')
                  : '开始处理',
            ),
          ),
        ),
      ],
    );
  }

  Widget _workflowCard(AppState app) {
    final p = paletteOf(context);
    final color = switch (app.jobStatus) {
      'running' => p.accent,
      'completed' || 'done' => p.green,
      'failed' => p.red,
      'cancelled' || 'cancelling' => p.dim,
      _ => p.muted,
    };
    return KtSection(
      title: '当前工作流',
      icon: Icons.timeline,
      action: app.jobStatus.isEmpty
          ? null
          : Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                _statusLabel(app.jobStatus),
                style: TextStyle(
                  fontFamily: 'SarasaUI',
                  color: color,
                  fontSize: 10.5,
                ),
              ),
            ),
      children: [
        Text(
          app.engineMessage,
          style: TextStyle(
            color: p.text,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (app.jobId != null) ...[
          const SizedBox(height: 4),
          Text(
            app.jobSource == 'kikoeta' ? '来自 Kikoeta' : '本地任务',
            style: TextStyle(color: p.muted, fontSize: 12),
          ),
          const SizedBox(height: 4),
          SelectableText(
            app.jobId!,
            style: TextStyle(color: p.dim, fontSize: 12),
          ),
        ],
      ],
    );
  }

  Widget _logCard(AppState app) {
    final p = paletteOf(context);
    return KtSection(
      title: '日志',
      icon: Icons.terminal,
      action: TextButton.icon(
        onPressed: app.logs.isEmpty ? null : () => _exportLogs(app),
        icon: const Icon(Icons.download_outlined, size: 16),
        label: const Text('导出日志'),
        style: _textActionStyle,
      ),
      children: [
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 140, maxHeight: 280),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: p.surface2,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: p.line),
          ),
          child: app.logs.isEmpty
              ? Text(
                  '尚无日志',
                  style: TextStyle(color: p.dim, fontSize: 12, height: 1.65),
                )
              : ListView.builder(
                  controller: _logController,
                  primary: false,
                  itemCount: app.logs.length,
                  itemBuilder: (context, index) => Text(
                    app.logs[index],
                    style: TextStyle(fontSize: 12, color: p.text, height: 1.65),
                  ),
                ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = widget.app;
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        _scheduleLogScroll(app);
        return KtPage(
          title: '任务',
          secondaryChildren: [_workflowCard(app), _logCard(app)],
          children: [_stageCard(app), _inputCard(app)],
        );
      },
    );
  }
}
