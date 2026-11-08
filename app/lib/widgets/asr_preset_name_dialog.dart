import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../widgets.dart';

class AsrPresetNameDialog extends StatefulWidget {
  final String suggestedName;
  final Set<String> existingNames;

  const AsrPresetNameDialog({
    super.key,
    required this.suggestedName,
    required this.existingNames,
  });

  @override
  State<AsrPresetNameDialog> createState() => _AsrPresetNameDialogState();
}

class _AsrPresetNameDialogState extends State<AsrPresetNameDialog> {
  late final TextEditingController _name;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.suggestedName)
      ..addListener(_changed);
  }

  void _changed() => setState(() {});

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  String? get _error {
    final name = _name.text.trim();
    if (name.isEmpty) return appL10n.presetNameRequired;
    if (widget.existingNames.contains(name)) return appL10n.presetNameExists;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final p = paletteOf(context);
    return Dialog(
      backgroundColor: p.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        width: 420,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.l10n.saveAsrPresetAs,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              KtField(controller: _name, label: context.l10n.presetName),
              if (_error != null)
                Text(_error!, style: TextStyle(color: p.red, fontSize: 12)),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(context.l10n.cancel),
                    ),
                    FilledButton.icon(
                      onPressed: _error == null
                          ? () => Navigator.of(context).pop(_name.text.trim())
                          : null,
                      icon: const Icon(Icons.save_outlined, size: 17),
                      label: Text(context.l10n.save),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
