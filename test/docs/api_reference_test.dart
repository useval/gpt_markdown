// The API reference on each component page of the docs is generated from
// lib/. This fails when a style field, a builder typedef or a doc comment
// changed without the reference being regenerated.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/docs/api_reference.dart' show generateApiReference;

void main() {
  test('docs/components/api matches lib/', () {
    final files = generateApiReference(Directory.current);
    expect(files, isNotEmpty);
    for (final MapEntry(key: path, value: content) in files.entries) {
      final file = File(path);
      expect(
        file.existsSync() ? file.readAsStringSync() : null,
        content,
        reason:
            '$path is out of date — run `dart run tool/docs/api_reference.dart`',
      );
    }
  });
}
