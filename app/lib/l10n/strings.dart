import 'package:flutter/widgets.dart';

import 'app_language.dart';
import 'generated/app_localizations.dart';

extension LocalizedBuildContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

/// 仅用于没有 BuildContext 的服务或初始化流程。
AppLocalizations get appL10n => AppLanguage.strings;

extension LocalizedJobStatus on AppLocalizations {
  String jobStatusLabel(String status) => switch (status) {
    'queued' => statusQueued,
    'running' => statusRunning,
    'pausing' => statusPausing,
    'paused' => statusPaused,
    'cancelling' => statusCancelling,
    'completed' || 'done' => statusCompleted,
    'failed' => statusFailed,
    'cancelled' => statusCancelled,
    _ => status,
  };
}
