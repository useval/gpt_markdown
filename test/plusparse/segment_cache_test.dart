import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_markdown/plusparse/plusparse.dart';
import 'sample_documents.dart';

void main() {
  test('every appended prefix agrees with a fresh split', () {
    final registry = MarkdownBlockRegistry([
      const FencedBlockSyntax(type: 'warning', opening: ':::warning'),
    ]);
    for (final doc in [
      sampleChatGpt,
      sampleBlockHeavy,
      'a\n\na\n\n:::warning\nx\n\ny\n:::\nafter\n\nend',
      'a\r\n\r\nb\r\n\r\nc',
      'a\n\nb\n\n\n\n',
    ]) {
      final cache = MarkdownSegmentCache();
      for (var end = 0; end <= doc.length; end++) {
        final prefix = doc.substring(0, end);
        expect(
          cache.update(prefix, blockRegistry: registry),
          splitStreamSegments(prefix, blockRegistry: registry),
          reason: 'prefix $end of $doc',
        );
      }
      for (final replacement in ['replacement', '', doc, 'short']) {
        expect(
          cache.update(replacement, blockRegistry: registry),
          splitStreamSegments(replacement, blockRegistry: registry),
        );
      }
    }
  });
}
