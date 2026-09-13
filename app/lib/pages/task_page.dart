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
      await File(path).writeAsString('${app.logs.join('\n')}\n');
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

  @override
  Widget build(BuildContext context) {
    final app = widget.app;
    final p = paletteOf(context);
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        _scheduleLogScroll(app);
        return ListView(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 24),
          children: [
            const Text(
              '任务',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              app.engineMessage,
              style: TextStyle(fontSize: 12, color: p.muted),
            ),
            const SectionTitle('阶段'),
            KtGroup(
              children: [
                KtRow(
                  icon: Icons.sync,
                  title: '转码 + ASR',
                  sub: '音频 / 视频必做；字幕输入自动跳过',
                  trailing: Text(
                    '固定',
                    style: TextStyle(fontSize: 12, color: p.dim),
                  ),
                ),
                KtSwitchRow(
                  icon: Icons.auto_fix_high,
                  title: '小模型矫正',
                  sub: '只修听写，不翻译',
                  value: app.enableCorrect,
                  onChanged: (v) {
                    app.setStageFlag('correct', v);
                  },
                ),
                KtSwitchRow(
                  icon: Icons.translate,
                  title: '翻译',
                  sub: '使用已配置的翻译器',
                  value: app.enableTranslate,
                  showDivider: false,
                  onChanged: (v) {
                    app.setStageFlag('translate', v);
                  },
                ),
              ],
            ),
            const SectionTitle('文件'),
            DropTarget(
              onDragDone: (detail) {
                app.addFiles(detail.files.map((f) => f.path));
              },
              child: KtGroup(
                children: [
                  InkWell(
                    onTap: () async {
                      final result = await FilePicker.platform.pickFiles(
                        allowMultiple: true,
                      );
                      if (result != null) {
                        app.addFiles(result.paths.whereType<String>());
                      }
                    },
                    child: Container(
                      height: 92,
                      alignment: Alignment.center,
                      child: Text(
                        app.files.isEmpty
                            ? '拖入音视频或字幕，或点击选择'
                            : '已选择 ${app.files.length} 个文件，点击继续添加',
                        style: TextStyle(color: p.muted, fontSize: 13),
                      ),
                    ),
                  ),
                  for (var i = 0; i < app.files.length; i++)
                    KtRow(
                      icon: Icons.insert_drive_file_outlined,
                      title: app.files[i].split(RegExp(r'[\\/]')).last,
                      sub: app.files[i],
                      showDivider: i != app.files.length - 1,
                      trailing: IconButton(
                        onPressed: () => app.removeFile(app.files[i]),
                        icon: Icon(Icons.close, size: 16, color: p.dim),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                FilledButton(
                  onPressed: app.engineOnline && !app.hasActiveJob
                      ? app.startJob
                      : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: p.accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('开始'),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: app.hasActiveJob ? app.cancelJob : null,
                  child: const Text('停止'),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: app.clearFiles,
                  child: const Text('清空列表'),
                ),
                const Spacer(),
                Text(
                  app.jobSource == 'kikoeta'
                      ? '${app.jobStatus} · 来自 kikoeta'
                      : app.jobStatus,
                  style: TextStyle(color: p.dim, fontSize: 12),
                ),
              ],
            ),
            Row(
              children: [
                const Expanded(child: SectionTitle('日志')),
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: TextButton.icon(
                    onPressed: app.logs.isEmpty ? null : () => _exportLogs(app),
                    icon: const Icon(Icons.download_outlined, size: 16),
                    label: const Text('导出日志'),
                  ),
                ),
              ],
            ),
            Container(
              constraints: const BoxConstraints(minHeight: 180, maxHeight: 280),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: p.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: p.line),
              ),
              child: app.logs.isEmpty
                  ? Text('尚无日志', style: TextStyle(color: p.dim, fontSize: 12))
                  : ListView.builder(
                      controller: _logController,
                      primary: false,
                      itemCount: app.logs.length,
                      itemBuilder: (context, index) => Text(
                        app.logs[index],
                        style: TextStyle(
                          fontSize: 12,
                          color: p.muted,
                          height: 1.45,
                        ),
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }
}
