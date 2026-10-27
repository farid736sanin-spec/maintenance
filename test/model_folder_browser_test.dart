import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:maintenance/features/settings/model_folder_browser.dart';
import 'package:maintenance/services/litert_lm_service.dart';
import 'package:path/path.dart' as p;

void main() {
  test('modelsInFolder lists litertlm files and skips other files', () async {
    final dir = await Directory.systemTemp.createTemp('litert_models');
    addTearDown(() => dir.delete(recursive: true));
    await File(p.join(dir.path, 'a.litertlm')).writeAsString('x');
    await File(p.join(dir.path, 'note.txt')).writeAsString('x');
    await File(p.join(dir.path, '.hidden.litertlm')).writeAsString('x');
    final nested = Directory(p.join(dir.path, 'sub'))..createSync();
    await File(p.join(nested.path, 'b.litertlm')).writeAsString('x');

    final listed = modelsInFolder(dir.path);

    expect(listed.error, isNull);
    expect(
      listed.models.map((file) => p.basename(file.path)),
      ['a.litertlm', 'b.litertlm'],
    );
  });

  test('modelsInFolder reports a missing folder', () {
    final listed = modelsInFolder(
      p.join(Directory.systemTemp.path, 'missing-litert-folder'),
    );
    expect(listed.models, isEmpty);
    expect(listed.error, 'That folder is not there.');
  });

  test('modelTypeForLitertPath matches Gemma and Qwen names', () {
    expect(
      modelTypeForLitertPath('/models/gemma-4-E2B-it.litertlm').name,
      'gemma4',
    );
    expect(modelTypeForLitertPath('/models/gemma-2b.litertlm').name, 'gemmaIt');
    expect(modelTypeForLitertPath('/models/Qwen3-0.6B.litertlm').name, 'qwen3');
    expect(modelTypeForLitertPath('/models/custom.litertlm').name, 'general');
  });
}
