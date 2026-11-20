import 'package:flutter/services.dart';

import '../l10n/generated/app_localizations.dart';

enum CompletionAction {
  none,
  lock,
  sleep,
  shutdown;

  static const _channel = MethodChannel('kikoeta_transl/power');

  String label(AppLocalizations l10n) => switch (this) {
    none => l10n.completionActionNone,
    lock => l10n.completionActionLock,
    sleep => l10n.completionActionSleep,
    shutdown => l10n.completionActionShutdown,
  };

  Future<void> perform() async {
    if (this != none) await _channel.invokeMethod<void>(name);
  }
}
