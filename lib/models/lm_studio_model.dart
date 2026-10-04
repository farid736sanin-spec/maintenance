class LmStudioModelInfo {
  const LmStudioModelInfo({
    required this.key,
    required this.displayName,
    required this.type,
    required this.isLoaded,
  });

  final String key;
  final String displayName;
  final String type;
  final bool isLoaded;

  bool get isLlm => type.toLowerCase() == 'llm';
}
