String fieldIdFromLabel(String label) {
  final slug = label
      .toLowerCase()
      .trim()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_|_$'), '');
  return slug.isEmpty ? 'field' : slug;
}
