import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

import '../app_state.dart';
import '../services/theme_reveal.dart';
import '../settings_draft.dart';
import '../widgets.dart';

class SettingsPage extends StatefulWidget {
  final AppState app;
  const SettingsPage({super.key, required this.app});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  static const _repositoryUrl = 'https://github.com/chenflxs/kikoeta-transl';
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

  Map<String, dynamic> _draftValues() => {
    'ffmpeg_path': ffmpeg.text,
    'crispasr_dir': crispasr.text,
    'proxy': proxy.text,
    'remote_username': remoteUsername.text,
    'remote_password': remotePassword.text,
    'remote_access': remoteAccess,
  };

  String _draft() => jsonEncode(_draftValues());

  void _syncSettings() {
    if (!mounted || _settingsSynced || widget.app.settings.isEmpty) return;
    _settingsSynced = true;
    final settings = widget.app.settings;
    final merged = mergeLoadedSettingsDraft(_savedDraft, _draftValues(), {
      'ffmpeg_path': '${settings['ffmpeg_path'] ?? ''}',
      'crispasr_dir': '${settings['crispasr_dir'] ?? ''}',
      'proxy': '${settings['proxy'] ?? ''}',
      'remote_username': '${settings['remote_username'] ?? 'admin'}',
      'remote_password': '${settings['remote_password'] ?? 'kikoeta'}',
      'remote_access': settings['remote_access'] == true,
    });
    ffmpeg.text = merged.values['ffmpeg_path'] as String;
    crispasr.text = merged.values['crispasr_dir'] as String;
    proxy.text = merged.values['proxy'] as String;
    remoteUsername.text = merged.values['remote_username'] as String;
    remotePassword.text = merged.values['remote_password'] as String;
    setState(() => remoteAccess = merged.values['remote_access'] as bool);
    _savedDraft = merged.baseline;
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
    // 主题切换统一走圆形揭示动画：设置页从窗口中心扩散
    ThemeReveal.instance.fromCenter(value);
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

  Future<({String tag, String url})> _fetchLatestRelease() async {
    const headers = {
      'Accept': 'application/vnd.github+json',
      'User-Agent': 'Kikoeta-Transl',
    };
    final apiResponse = await http
        .get(
          Uri.parse(
            'https://api.github.com/repos/chenflxs/kikoeta-transl/releases/latest',
          ),
          headers: headers,
        )
        .timeout(const Duration(seconds: 15));
    if (apiResponse.statusCode == 200) {
      final release = jsonDecode(apiResponse.body) as Map<String, dynamic>;
      final tag = (release['tag_name'] as String?)?.trim();
      final url = (release['html_url'] as String?)?.trim();
      if (tag == null || tag.isEmpty) {
        throw const FormatException('GitHub Release 未提供版本号');
      }
      return (
        tag: tag,
        url: url?.isNotEmpty == true ? url! : '$_repositoryUrl/releases',
      );
    }

    if (apiResponse.statusCode != 403) {
      throw HttpException('GitHub 返回 ${apiResponse.statusCode}');
    }

    // The unauthenticated REST API is rate limited. The public Atom feed is
    // served by github.com and does not consume that API quota.
    final feedResponse = await http
        .get(
          Uri.parse('$_repositoryUrl/releases.atom'),
          headers: const {'User-Agent': 'Kikoeta-Transl'},
        )
        .timeout(const Duration(seconds: 15));
    if (feedResponse.statusCode != 200) {
      throw HttpException(
        'GitHub API 返回 403，Release Feed 返回 ${feedResponse.statusCode}',
      );
    }
    final entry = RegExp(
      r'<entry\b[^>]*>([\s\S]*?)</entry>',
      caseSensitive: false,
    ).firstMatch(feedResponse.body)?.group(1);
    if (entry == null) throw const FormatException('Release Feed 中没有发布版本');
    final rawTag = RegExp(
      r'<title\b[^>]*>([\s\S]*?)</title>',
      caseSensitive: false,
    ).firstMatch(entry)?.group(1);
    final tag = rawTag?.replaceAll(RegExp(r'<[^>]*>'), '').trim();
    final rawUrl = RegExp(
      r'<link\b[^>]*href="([^"]+)"[^>]*/?>',
      caseSensitive: false,
    ).firstMatch(entry)?.group(1);
    if (tag == null || tag.isEmpty) {
      throw const FormatException('Release Feed 未提供版本号');
    }
    return (
      tag: _decodeXml(tag),
      url: rawUrl == null ? '$_repositoryUrl/releases' : _decodeXml(rawUrl),
    );
  }

  String _decodeXml(String value) => value
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&apos;', "'");

  Future<void> _checkForUpdate() async {
    if (_checkingUpdate) return;
    setState(() => _checkingUpdate = true);
    String message;
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;
      final release = await _fetchLatestRelease();
      final tag = release.tag;
      final url = release.url;
      final latest = tag.replaceFirst(RegExp(r'^[vV]'), '').split('+').first;
      final currentParts = currentVersion.split('.').map(int.parse).toList();
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
        message = '发现新版本 $tag（当前 $currentVersion）';
        await _openUrl(url);
      } else {
        message = '当前已是最新版本（$currentVersion）';
      }
    } catch (error) {
      message = '检查更新失败：$error';
    } finally {
      if (mounted) setState(() => _checkingUpdate = false);
    }
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final tools = widget.app.tools;
    final p = paletteOf(context);
    return KtPage(
      title: '设置',
      footer: Align(
        alignment: Alignment.centerRight,
        child: SizedBox(
          width: 180,
          child: FilledButton.icon(
            onPressed: () => _save(),
            icon: const Icon(Icons.save_outlined, size: 18),
            label: const Text('保存'),
          ),
        ),
      ),
      children: [
        KtSection(
          title: '工具',
          icon: Icons.handyman_outlined,
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
        KtSection(
          title: '路径',
          icon: Icons.folder_open_outlined,
          children: [
            KtField(controller: ffmpeg, label: 'ffmpeg 路径'),
            KtField(controller: crispasr, label: 'CrispASR 目录'),
            KtField(
              controller: proxy,
              label: 'HTTP 代理',
              hint: 'http://127.0.0.1:7890',
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4),
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
        KtSection(
          title: '界面与服务',
          icon: Icons.palette_outlined,
          children: [
            KtRow(
              // 图标随当前主题模式变化，和 kikoeta 的设置页一致
              icon: switch (themeMode) {
                'light' => Icons.light_mode_outlined,
                'dark' => Icons.dark_mode_outlined,
                _ => Icons.brightness_auto_outlined,
              },
              title: '主题',
              // 三段按钮按内容自适应宽度，不撑满整行
              trailing: SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'system', label: Text('跟随系统')),
                  ButtonSegment(value: 'light', label: Text('浅色')),
                  ButtonSegment(value: 'dark', label: Text('深色')),
                ],
                selected: {themeMode},
                showSelectedIcon: false,
                style: ButtonStyle(
                  backgroundColor: WidgetStateProperty.resolveWith(
                    (states) => states.contains(WidgetState.selected)
                        ? p.accent.withValues(alpha: .12)
                        : p.surface2,
                  ),
                  foregroundColor: WidgetStateProperty.resolveWith(
                    (states) => states.contains(WidgetState.selected)
                        ? p.accent
                        : p.muted,
                  ),
                  // 选中段加一圈同色细边：浅色调下 12% 底色对比很弱，
                  // 只靠底色不容易一眼看出当前选的是哪一段
                  side: WidgetStateProperty.resolveWith(
                    (states) => BorderSide(
                      color: states.contains(WidgetState.selected)
                          ? p.accent.withValues(alpha: .6)
                          : p.line,
                      width: 1,
                    ),
                  ),
                  // 视觉高度收窄到与设置页其它内联控件齐平
                  minimumSize: const WidgetStatePropertyAll(Size(0, 36)),
                  textStyle: const WidgetStatePropertyAll(
                    TextStyle(
                      fontFamily: 'SarasaUI',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  padding: const WidgetStatePropertyAll(
                    EdgeInsets.symmetric(horizontal: 10),
                  ),
                  visualDensity: VisualDensity.compact,
                ),
                onSelectionChanged: (selection) =>
                    _changeTheme(selection.first),
              ),
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
        KtSection(
          title: '远程身份验证',
          icon: Icons.lock_outline,
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
        KtSection(
          title: '关于',
          icon: Icons.info_outline,
          children: [
            Wrap(
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
          ],
        ),
      ],
    );
  }
}
