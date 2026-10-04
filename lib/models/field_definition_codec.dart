import 'dart:convert';

import 'field_definition.dart';

Map<String, dynamic> fieldDefinitionToMap(FieldDefinition f) {
  return {
    'id': f.id,
    'label': f.label,
    'type': f.dbType,
    'defaultValue': f.defaultValue,
  };
}

FieldDefinition fieldDefinitionFromMap(Map<String, dynamic> map) {
  return FieldDefinition(
    id: map['id'] as String,
    label: map['label'] as String,
    type: FieldDefinition.typeFromDb(map['type'] as String),
    defaultValue: map['defaultValue'] as String?,
  );
}

List<FieldDefinition> decodeFieldLibrary(String? raw) {
  if (raw == null || raw.isEmpty) return [];
  final list = jsonDecode(raw) as List<dynamic>;
  return list
      .map((e) => fieldDefinitionFromMap(Map<String, dynamic>.from(e as Map)))
      .toList();
}

String encodeFieldLibrary(List<FieldDefinition> fields) {
  return jsonEncode(fields.map(fieldDefinitionToMap).toList());
}
