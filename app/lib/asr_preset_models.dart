String? asrPresetFamily(String name, {Object? basePreset}) {
  for (final family in const ['qwen3', 'moss']) {
    if (basePreset == family) return family;
  }
  for (final family in const ['qwen3', 'moss']) {
    if (name == family || name.startsWith('$family-自定义预设')) return family;
  }
  return null;
}

String? _modelFamily(String name) {
  final normalized = name.toLowerCase().replaceAll('_', '-');
  if (!normalized.endsWith('.gguf') ||
      normalized.contains('aligner') ||
      normalized.contains('alignment') ||
      normalized.contains('tts')) {
    return null;
  }
  if (RegExp(
    r'(?:^|-)moss-(?:transcribe-)?diarize(?:[-.]|$)',
  ).hasMatch(normalized)) {
    return 'moss';
  }
  if (RegExp(
    r'(?:^|-)qwen3-(?:asr(?:[-.]|$)|(?:1[.-]7|0[.-]6)b(?:[-.]|$))',
  ).hasMatch(normalized)) {
    return 'qwen3';
  }
  return null;
}

({String model, String backend})? selectAsrPresetModel({
  required String family,
  required Iterable<String> models,
  required String currentModel,
}) {
  final candidates = models
      .where((name) => _modelFamily(name) == family)
      .toList();
  if (candidates.isEmpty) return null;
  final currentName = currentModel
      .replaceAll('\\', '/')
      .split('/')
      .last
      .toLowerCase();
  int priority(String name) {
    final lower = name.toLowerCase();
    if (lower == currentName) return -1;
    if (family == 'qwen3') {
      return RegExp(r'1[._-]7b').hasMatch(lower) ? 0 : 1;
    }
    // Prefer the Q8/F16 variants verified by Subtitle Edit for native timing.
    if (RegExp(r'q8[_-]0').hasMatch(lower)) return 0;
    if (lower.contains('f16') || lower.contains('f32')) return 1;
    return 2;
  }

  candidates.sort((a, b) {
    final order = priority(a).compareTo(priority(b));
    return order != 0 ? order : a.toLowerCase().compareTo(b.toLowerCase());
  });
  final model = candidates.first;
  return (
    model: model,
    backend: family == 'moss'
        ? 'moss-diarize'
        : RegExp(r'1[._-]7b', caseSensitive: false).hasMatch(model)
        ? 'qwen3-1.7b'
        : 'qwen3',
  );
}
