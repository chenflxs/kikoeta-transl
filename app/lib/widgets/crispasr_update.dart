import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../app_state.dart';
import '../l10n/strings.dart';
import '../services/engine.dart';
import '../widgets.dart';

class CrispAsrUpdateRow extends StatefulWidget {
  final AppState app;
  final Future<void> Function() prepare;
  const CrispAsrUpdateRow({
    super.key,
    required this.app,
    required this.prepare,
  });

  @override
  State<CrispAsrUpdateRow> createState() => _CrispAsrUpdateRowState();
}

class _CrispAsrUpdateRowState extends State<CrispAsrUpdateRow> {
  Map<String, dynamic>? _local;
  bool _checking = false;
  late String _configuredDirectory;

  @override
  void initState() {
    super.initState();
    _configuredDirectory = '${widget.app.settings['crispasr_dir'] ?? ''}';
    unawaited(_refresh());
  }

  @override
  void didUpdateWidget(covariant CrispAsrUpdateRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    final directory = '${widget.app.settings['crispasr_dir'] ?? ''}';
    if (_configuredDirectory != directory) {
      _configuredDirectory = directory;
      unawaited(_refresh());
    }
  }

  Future<void> _refresh() async {
    try {
      final local = await widget.app.engine.crispAsrStatus();
      if (mounted) setState(() => _local = local);
    } catch (_) {
      // Keep the existing tool-detection result until the user requests a check.
    }
  }

  Future<void> _open({bool quick = false}) async {
    if (_checking) return;
    setState(() => _checking = true);
    try {
      await widget.prepare();
      final release = await widget.app.engine.crispAsrReleases();
      if (!mounted) return;
      setState(() {
        _local = Map<String, dynamic>.from(release['local'] as Map);
        _checking = false;
      });
      final installed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _ReleaseDialog(
          engine: widget.app.engine,
          release: release,
          quick: quick,
        ),
      );
      if (installed == true) {
        await _refresh();
        await widget.app.refreshTools();
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(context.l10n.crispInstalled)));
        }
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.updateCheckFailed(error))),
        );
      }
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final asr = widget.app.tools['asr'] as Map?;
    final installed =
        _local?['installed'] == true ||
        (_local == null && '${asr?['executable'] ?? ''}'.isNotEmpty);
    final version = _local?['version']?.toString() ?? '';
    final directory =
        _local?['dir']?.toString() ?? asr?['dir']?.toString() ?? '';
    return LayoutBuilder(
      builder: (context, constraints) => KtRow(
        icon: Icons.mic_none,
        title: version.isEmpty ? 'CrispASR' : 'CrispASR $version',
        sub: directory.isEmpty ? context.l10n.notDetected : directory,
        trailing: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: constraints.maxWidth * .62),
          child: Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            children: [
              TextButton(
                onPressed: _checking ? null : () => _open(),
                child: Text(context.l10n.crispCheckUpdate),
              ),
              FilledButton.tonalIcon(
                onPressed: _checking ? null : () => _open(quick: true),
                icon: _checking
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.download_outlined, size: 17),
                label: Text(
                  installed
                      ? context.l10n.crispQuickUpdate
                      : context.l10n.crispDownload,
                ),
              ),
            ],
          ),
        ),
        showDivider: false,
      ),
    );
  }
}

class _ReleaseDialog extends StatefulWidget {
  final EngineClient engine;
  final Map<String, dynamic> release;
  final bool quick;
  const _ReleaseDialog({
    required this.engine,
    required this.release,
    required this.quick,
  });

  @override
  State<_ReleaseDialog> createState() => _ReleaseDialogState();
}

class _ReleaseDialogState extends State<_ReleaseDialog> {
  late final List<Map<String, dynamic>> _assets;
  int? _selected;
  Map<String, dynamic> _progress = const {'phase': 'idle'};
  Timer? _timer;
  bool _polling = false;
  bool _starting = false;
  bool _cancelling = false;
  String? _error;

  bool get _busy =>
      _starting ||
      const {
        'downloading',
        'extracting',
        'installing',
      }.contains(_progress['phase']);

  @override
  void initState() {
    super.initState();
    _assets = [
      for (final item in widget.release['assets'] as List)
        Map<String, dynamic>.from(item as Map),
    ];
    _selected = _assets.isEmpty ? null : _assets.first['id'] as int;
    unawaited(_restore());
  }

  Future<void> _restore() async {
    try {
      final state = await widget.engine.crispAsrUpdateStatus();
      if (!mounted) return;
      if (const {
        'downloading',
        'extracting',
        'installing',
      }.contains(state['phase'])) {
        setState(() => _progress = state);
        _watch();
      } else if (widget.quick &&
          (widget.release['newer'] == true ||
              (widget.release['local'] as Map)['error'] != '')) {
        await _install();
      }
    } catch (_) {
      // A fresh install can still be started if the initial status request failed.
    }
  }

  void _watch() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _poll());
  }

  Future<void> _openCudaDownload() async {
    const url = 'https://developer.nvidia.com/cuda-downloads';
    try {
      if (Platform.isWindows) {
        await Process.start('explorer.exe', [url]);
      } else {
        await Process.start(Platform.isMacOS ? 'open' : 'xdg-open', [url]);
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  Future<void> _poll() async {
    if (_polling) return;
    _polling = true;
    try {
      final state = await widget.engine.crispAsrUpdateStatus();
      if (!mounted) return;
      setState(() {
        _progress = state;
        _error = state['phase'] == 'error' ? state['error']?.toString() : null;
      });
      if (!_busy) {
        _timer?.cancel();
        _cancelling = false;
        if (state['phase'] == 'done') Navigator.of(context).pop(true);
      }
    } catch (error) {
      if (mounted) {
        _timer?.cancel();
        setState(() {
          _progress = const {'phase': 'error'};
          _error = error.toString();
          _cancelling = false;
        });
      }
    } finally {
      _polling = false;
    }
  }

  Future<void> _install() async {
    if (_selected == null || _busy) return;
    setState(() {
      _starting = true;
      _error = null;
    });
    try {
      final state = await widget.engine.installCrispAsr(_selected!);
      if (!mounted) return;
      setState(() => _progress = state);
      _watch();
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  Future<void> _cancel() async {
    if (!_busy) {
      Navigator.of(context).pop(false);
      return;
    }
    setState(() => _cancelling = true);
    try {
      await widget.engine.cancelCrispAsrUpdate();
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error.toString();
          _cancelling = false;
          _progress = const {'phase': 'error'};
        });
        _timer?.cancel();
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _hint(BuildContext context, String flavor) => switch (flavor) {
    'cuda' => context.l10n.crispCudaHint,
    'cuda126' => context.l10n.crispCuda126Hint,
    'cuda13' => context.l10n.crispCuda13Hint,
    'vulkan' => context.l10n.crispVulkanHint,
    'metal' => context.l10n.crispMetalHint,
    'hip' || 'hip7' => context.l10n.crispHipHint,
    'cpu-legacy' => context.l10n.crispLegacyHint,
    'avx512' => context.l10n.crispAvx512Hint,
    _ => context.l10n.crispCpuHint,
  };

  @override
  Widget build(BuildContext context) {
    final p = paletteOf(context);
    final local = widget.release['local'] as Map;
    final env = widget.release['environment'] as Map;
    final hardware = [
      '${env['system']} ${env['arch']}',
      ...(env['gpus'] as List).map((gpu) => '$gpu'),
      if ((env['cuda'] as num) > 0) 'CUDA ≤ ${env['cuda']}',
    ].join(' · ');
    final phase = _progress['phase'];
    final total = (_progress['total'] as num?)?.toDouble() ?? 0;
    final received = (_progress['received'] as num?)?.toDouble() ?? 0;
    final fraction = total > 0 ? (received / total).clamp(0.0, 1.0) : null;
    return PopScope(
      canPop: !_busy,
      child: Dialog(
        backgroundColor: p.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 660,
            maxHeight: MediaQuery.sizeOf(context).height * .85,
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.crispReleaseTitle,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  context.l10n.crispVersions(
                    '${local['version']}'.isEmpty
                        ? context.l10n.notDetected
                        : '${local['version']}',
                    widget.release['tag']!,
                  ),
                  style: const TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(hardware, style: TextStyle(fontSize: 11, color: p.dim)),
                if (env['has_nvidia'] == true && (env['cuda'] as num) <= 0) ...[
                  const SizedBox(height: 8),
                  Text(
                    context.l10n.crispCudaMissing,
                    style: TextStyle(fontSize: 12, color: p.muted),
                  ),
                  Wrap(
                    spacing: 12,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      TextButton(
                        onPressed: _openCudaDownload,
                        child: Text(context.l10n.crispDownloadCuda),
                      ),
                      MouseRegion(
                        cursor: SystemMouseCursors.help,
                        child: Tooltip(
                          message: context.l10n.crispChooseCudaHelp,
                          constraints: const BoxConstraints(maxWidth: 340),
                          child: Text(
                            context.l10n.crispChooseCuda,
                            style: TextStyle(
                              fontSize: 12,
                              color: p.accent,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                if (widget.release['newer'] != true)
                  Text(
                    context.l10n.crispAlreadyLatest,
                    style: TextStyle(fontSize: 12, color: p.muted),
                  ),
                const SizedBox(height: 8),
                Flexible(
                  child: _assets.isEmpty
                      ? Text(context.l10n.crispNoPackage)
                      : RadioGroup<int>(
                          groupValue: _selected,
                          onChanged: (value) {
                            if (!_busy) setState(() => _selected = value);
                          },
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: _assets.length,
                            itemBuilder: (context, index) {
                              final item = _assets[index];
                              final size = ((item['size'] as num) / 1048576)
                                  .toStringAsFixed(1);
                              return RadioListTile<int>(
                                value: item['id'] as int,
                                enabled: !_busy,
                                contentPadding: EdgeInsets.zero,
                                dense: true,
                                title: Text(
                                  '${item['name']}${item['recommended'] == true ? ' · ${context.l10n.crispRecommended}' : ''}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                subtitle: Text(
                                  '$size MB · ${_hint(context, item['flavor'] as String)}',
                                  style: TextStyle(fontSize: 11, color: p.dim),
                                ),
                              );
                            },
                          ),
                        ),
                ),
                const SizedBox(height: 8),
                Text(
                  context.l10n.crispPreserveModels,
                  style: TextStyle(fontSize: 11, color: p.muted),
                ),
                if (_busy) ...[
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: phase == 'downloading' ? fraction : null,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _cancelling
                        ? context.l10n.crispCancelling
                        : phase == 'extracting'
                        ? context.l10n.crispExtracting
                        : phase == 'installing'
                        ? context.l10n.crispInstalling
                        : '${context.l10n.crispDownloading} ${(received / 1048576).toStringAsFixed(1)} / ${(total / 1048576).toStringAsFixed(1)} MB',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(_error!, style: TextStyle(fontSize: 12, color: p.red)),
                ],
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      TextButton(
                        onPressed:
                            phase == 'installing' || _starting || _cancelling
                            ? null
                            : _cancel,
                        child: Text(context.l10n.cancel),
                      ),
                      FilledButton.icon(
                        onPressed: _busy || _selected == null ? null : _install,
                        icon: const Icon(Icons.download_outlined, size: 17),
                        label: Text(context.l10n.crispInstall),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
