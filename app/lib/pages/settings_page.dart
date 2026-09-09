import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../app_state.dart';
import '../widgets.dart';

class SettingsPage extends StatefulWidget {
  final AppState app;
  const SettingsPage({super.key, required this.app});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final TextEditingController ffmpeg;
  late final TextEditingController crispasr;
  late final TextEditingController proxy;
  String? _themeSelection;
  late bool remoteAccess;

  @override
  void initState() {
    super.initState();
    final s = widget.app.settings;
    ffmpeg = TextEditingController(text: '${s['ffmpeg_path'] ?? ''}');
    crispasr = TextEditingController(text: '${s['crispasr_dir'] ?? ''}');
    proxy = TextEditingController(text: '${s['proxy'] ?? ''}');
    remoteAccess = s['remote_access'] == true;
  }

  @override
  void dispose() {
    ffmpeg.dispose();
    crispasr.dispose();
    proxy.dispose();
    super.dispose();
  }

  Future<void> _persistPaths() async {
    final next = Map<String, dynamic>.from(widget.app.settings);
    next['ffmpeg_path'] = ffmpeg.text.trim();
    next['crispasr_dir'] = crispasr.text.trim();
    next['proxy'] = proxy.text.trim();
    next['theme'] = themeMode;
    next['remote_access'] = remoteAccess;
    await widget.app.persistSettings(next);
  }

  String get themeMode {
    final value =
        _themeSelection ?? widget.app.settings['theme']?.toString() ?? 'system';
    return const ['system', 'light', 'dark'].contains(value) ? value : 'system';
  }

  Future<void> _changeTheme(String value) async {
    setState(() => _themeSelection = value);
    widget.app.previewTheme(value);
    final next = Map<String, dynamic>.from(widget.app.settings);
    next['theme'] = value;
    await widget.app.persistSettings(next);
  }

  Future<void> _save() async {
    final previousRemoteAccess = widget.app.settings['remote_access'] == true;
    await _persistPaths();
    await widget.app.reload();
    if (previousRemoteAccess != remoteAccess) {
      await widget.app.restartEngine();
    }
    if (mounted) {
      setState(() {});
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('设置已保存')));
    }
  }

  Future<void> _refreshTools() async {
    await _persistPaths();
    await widget.app.refreshTools();
    if (mounted) {
      setState(() {});
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已刷新工具检测')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final tools = widget.app.tools;
    return ListView(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 24),
      children: [
        const Text(
          '设置',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        ),
        const SectionTitle('工具'),
        KtGroup(
          children: [
            KtRow(
              icon: Icons.movie_outlined,
              title: 'ffmpeg',
              sub:
                  '${(tools['ffmpeg'] as String?)?.isNotEmpty == true ? tools['ffmpeg'] : (tools['ffmpeg_error'] ?? '未检测')}',
              trailing: TextButton(
                onPressed: _refreshTools,
                child: const Text('刷新'),
              ),
              showDivider: true,
            ),
            KtRow(
              icon: Icons.mic_none,
              title: 'CrispASR',
              sub:
                  ((tools['asr'] as Map?)?['executable'] as String?)
                          ?.isNotEmpty ==
                      true
                  ? (tools['asr'] as Map)['executable'].toString()
                  : ((tools['asr'] as Map?)?['dir']?.toString() ?? '未找到可执行文件'),
              trailing: TextButton(
                onPressed: _refreshTools,
                child: const Text('刷新'),
              ),
              showDivider: false,
            ),
          ],
        ),
        const SectionTitle('路径'),
        KtGroup(
          children: [
            KtField(controller: ffmpeg, label: 'ffmpeg 路径'),
            KtField(controller: crispasr, label: 'CrispASR 目录'),
            KtField(
              controller: proxy,
              label: 'HTTP 代理',
              hint: 'http://127.0.0.1:7890',
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              child: Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () async {
                    final dir = await FilePicker.platform.getDirectoryPath();
                    if (dir != null) setState(() => crispasr.text = dir);
                  },
                  child: const Text('选择 CrispASR 目录'),
                ),
              ),
            ),
          ],
        ),
        const SectionTitle('界面与服务'),
        KtGroup(
          children: [
            KtSelectField<String>(
              label: '主题',
              value: themeMode,
              values: const ['system', 'light', 'dark'],
              labelOf: (value) => switch (value) {
                'system' => '跟随系统',
                'light' => '浅色',
                _ => '深色',
              },
              onChanged: _changeTheme,
            ),
            KtSwitchRow(
              icon: Icons.lan_outlined,
              title: '允许远程访问',
              sub: remoteAccess ? '服务监听 0.0.0.0:2370' : '服务仅监听 127.0.0.1:2370',
              value: remoteAccess,
              onChanged: (value) => setState(() => remoteAccess = value),
              showDivider: false,
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
