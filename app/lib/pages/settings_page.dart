import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../app_state.dart';
import '../widgets.dart';

class SettingsPage extends StatefulWidget {
  final AppState app;
  const SettingsPage({super.key, required this.app});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  static const _repositoryUrl = 'https://github.com/chenflxs/kikoeta-transl';
  static const _currentVersion = '0.1.1';
  late final TextEditingController ffmpeg;
  late final TextEditingController crispasr;
  late final TextEditingController proxy;
  late final TextEditingController remoteUsername;
  late final TextEditingController remotePassword;
  String? _themeSelection;
  late bool remoteAccess;
  bool _settingsSynced = false;
  late String _savedDraft;
  late final VoidCallback _unregisterPageSaver;
  Future<void>? _saving;

  @override
  void initState() {
    super.initState();
    final s = widget.app.settings;
    ffmpeg = TextEditingController(text: '${s['ffmpeg_path'] ?? ''}');
    crispasr = TextEditingController(text: '${s['crispasr_dir'] ?? ''}');
    proxy = TextEditingController(text: '${s['proxy'] ?? ''}');
    remoteUsername = TextEditingController(
      text: '${s['remote_username'] ?? 'admin'}',
    );
    remotePassword = TextEditingController(
      text: '${s['remote_password'] ?? 'kikoeta'}',
    );
    remoteAccess = s['remote_access'] == true;
    _savedDraft = _draft();
    _settingsSynced = s.isNotEmpty;
    _unregisterPageSaver = widget.app.registerPageSaver(
      6,
      () => _save(auto: true),
    );
    widget.app.addListener(_syncSettings);
  }

  String _draft() => jsonEncode([
    ffmpeg.text,
    crispasr.text,
    proxy.text,
    remoteUsername.text,
    remotePassword.text,
    remoteAccess,
  ]);

  void _syncSettings() {
    if (!mounted || _settingsSynced || widget.app.settings.isEmpty) return;
    _settingsSynced = true;
    if (_draft() != _savedDraft) return;
    final settings = widget.app.settings;
    ffmpeg.text = '${settings['ffmpeg_path'] ?? ''}';
    crispasr.text = '${settings['crispasr_dir'] ?? ''}';
    proxy.text = '${settings['proxy'] ?? ''}';
    remoteUsername.text = '${settings['remote_username'] ?? 'admin'}';
    remotePassword.text = '${settings['remote_password'] ?? 'kikoeta'}';
    setState(() => remoteAccess = settings['remote_access'] == true);
    _savedDraft = _draft();
  }

  @override
  void dispose() {
    _unregisterPageSaver();
    widget.app.removeListener(_syncSettings);
    ffmpeg.dispose();
    crispasr.dispose();
    proxy.dispose();
    remoteUsername.dispose();
    remotePassword.dispose();
    super.dispose();
  }

  Future<void> _persistPaths() async {
    final ffmpegPath = ffmpeg.text.trim();
    final crispasrPath = crispasr.text.trim();
    final proxyUrl = proxy.text.trim();
    final selectedTheme = themeMode;
    final allowRemote = remoteAccess;
    final username = remoteUsername.text.trim();
    final password = remotePassword.text;
    await widget.app.updateSettings((next) {
      next['ffmpeg_path'] = ffmpegPath;
      next['crispasr_dir'] = crispasrPath;
      next['proxy'] = proxyUrl;
      next['theme'] = selectedTheme;
      next['remote_access'] = allowRemote;
      next['remote_username'] = username;
      next['remote_password'] = password;
    });
  }

  String get themeMode {
    final value =
        _themeSelection ?? widget.app.settings['theme']?.toString() ?? 'system';
    return const ['system', 'light', 'dark'].contains(value) ? value : 'system';
  }

  Future<void> _changeTheme(String value) async {
    setState(() => _themeSelection = value);
    widget.app.previewTheme(value);
    await widget.app.updateSettings((next) => next['theme'] = value);
  }

  Future<void> _save({bool auto = false}) async {
    final running = _saving;
    if (running != null) {
      await running;
      if (auto) return _save(auto: true);
      return;
    }
    final pending = _saveNow(auto: auto);
    _saving = pending;
    try {
      await pending;
    } finally {
      if (identical(_saving, pending)) _saving = null;
    }
  }

  Future<void> _saveNow({required bool auto}) async {
    final draft = _draft();
    if (auto && draft == _savedDraft) return;
    if (!_validRemoteCredentials(showMessage: !auto)) {
      if (auto) throw StateError('远程用户名或密码无效');
      return;
    }
    final previousRemoteAccess = widget.app.settings['remote_access'] == true;
    await _persistPaths();
    await widget.app.reload();
    if (previousRemoteAccess != remoteAccess) {
      await widget.app.restartEngine();
      if (!widget.app.engineOnline) throw StateError('远程服务重启失败');
    }
    _savedDraft = draft;
    if (!auto && mounted) {
      setState(() {});
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('设置已保存')));
    }
  }

  bool _validRemoteCredentials({bool showMessage = true}) {
    final username = remoteUsername.text.trim();
    if (username.isEmpty || remotePassword.text.isEmpty) {
      if (showMessage) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('远程用户名和密码不能为空')));
      }
      return false;
    }
    if (username.contains(':')) {
      if (showMessage) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('远程用户名不能包含冒号')));
      }
      return false;
    }
    return true;
  }

  Future<void> _resetRemoteCredentials() async {
    remoteUsername.text = 'admin';
    remotePassword.text = 'kikoeta';
    await widget.app.updateSettings((next) {
      next['remote_username'] = 'admin';
      next['remote_password'] = 'kikoeta';
    });
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('远程账密已重置为 admin / kikoeta')));
  }

  Future<void> _refreshTools() async {
    if (!_validRemoteCredentials()) return;
    await _save(auto: true);
    await widget.app.refreshTools();
    if (mounted) {
      setState(() {});
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已刷新工具检测')));
    }
  }

  bool _checkingUpdate = false;

  Future<void> _openRepository() async {
    await _openUrl(_repositoryUrl);
  }

  Future<void> _openUrl(String url) async {
    if (Platform.isWindows) {
      await Process.start('explorer.exe', [url]);
    } else if (Platform.isMacOS) {
      await Process.start('open', [url]);
    } else {
      await Process.start('xdg-open', [url]);
    }
  }

  Future<void> _checkForUpdate() async {
    if (_checkingUpdate) return;
    setState(() => _checkingUpdate = true);
    String message;
    try {
      final response = await http
          .get(
            Uri.parse(
              'https://api.github.com/repos/chenflxs/kikoeta-transl/releases/latest',
            ),
            headers: const {'Accept': 'application/vnd.github+json'},
          )
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) {
        throw HttpException('GitHub 返回 ${response.statusCode}');
      }
      final release = jsonDecode(response.body) as Map<String, dynamic>;
      final tag = (release['tag_name'] as String?)?.trim();
      final url =
          (release['html_url'] as String?)?.trim() ?? '$_repositoryUrl/releases';
      if (tag == null || tag.isEmpty) throw const FormatException('未找到版本号');
      final latest = tag.replaceFirst(RegExp(r'^[vV]'), '').split('+').first;
      final currentParts = _currentVersion.split('.').map(int.parse).toList();
      final latestParts = latest.split('.').map(int.tryParse).toList();
      var comparison = 0;
      for (var i = 0; i < 3; i++) {
        final current = i < currentParts.length ? currentParts[i] : 0;
        final newer = i < latestParts.length ? latestParts[i] : null;
        if (newer == null) throw const FormatException('版本号格式无效');
        if (newer != current) {
          comparison = newer.compareTo(current);
          break;
        }
      }
      if (comparison > 0) {
        message = '发现新版本 $tag（当前 $_currentVersion）';
        await _openUrl(url);
      } else {
        message = '当前已是最新版本（$_currentVersion）';
      }
    } catch (error) {
      message = '检查更新失败：$error';
    } finally {
      if (mounted) setState(() => _checkingUpdate = false);
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
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
        const SectionTitle('远程身份验证'),
        KtGroup(
          children: [
            KtField(controller: remoteUsername, label: '用户名'),
            KtField(controller: remotePassword, label: '密码', obscure: true),
            KtRow(
              icon: Icons.restore,
              title: '重置默认账密',
              sub: 'admin / kikoeta',
              trailing: TextButton(
                onPressed: _resetRemoteCredentials,
                child: const Text('重置'),
              ),
              showDivider: false,
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
        const SizedBox(height: 20),
        const Divider(),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Wrap(
            spacing: 10,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              TextButton.icon(
                onPressed: _openRepository,
                icon: const Icon(Icons.open_in_new),
                label: const Text('项目仓库'),
              ),
              OutlinedButton.icon(
                onPressed: _checkingUpdate ? null : _checkForUpdate,
                icon: _checkingUpdate
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.system_update_alt),
                label: Text(_checkingUpdate ? '正在检查…' : '检查更新'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
