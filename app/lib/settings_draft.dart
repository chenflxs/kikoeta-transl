import 'dart:convert';

// Merge settings that arrive after the page opens, retaining each edited field.
({Map<String, dynamic> values, String baseline}) mergeLoadedSettingsDraft(
  String savedDraft,
  Map<String, dynamic> current,
  Map<String, dynamic> loaded,
) {
  final saved = jsonDecode(savedDraft) as Map<String, dynamic>;
  return (
    values: {
      for (final key in current.keys)
        key: current[key] == saved[key] ? loaded[key] : current[key],
    },
    baseline: jsonEncode({for (final key in current.keys) key: loaded[key]}),
  );
}
