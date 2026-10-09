/// A reply streamed with the fade reveal only ever grows.
///
/// It used to shrink at the end of almost every list: while the fade was
/// still passing over a list, the line breaks between its items came back
/// from the reveal rebuilt as spans with children, the column layout did not
/// recognise them as separators, and the whole list fell back to one
/// paragraph of placeholders — a few pixels taller. When the fade moved on,
/// the list snapped to its real height and everything below it, typically
/// the next heading, jumped up.
///
/// Three smaller jumps came from the streaming hold showing a line too early:
/// a lone `2` before it became `2. item`, an empty `2. ` item whose content
/// was still held, and a `[1]` that became a `[1]: url` definition.
///
/// A drop of under 2 px is tolerated, and it is not a regression: a line
/// still being revealed is laid out without the text past the reveal head, so
/// a line holding only an inline code chip so far measures about 1.5 px taller
/// than the finished line. Every jump fixed here was 4 px or more.
library;

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

const _reply = '''# Reversing a linked list

Here is the **iterative** approach.

## The idea

You need three references at any moment:

1. `prev` — the part already reversed
2. `curr` — the node being moved
3. `next` — saved before you overwrite `curr.next`

### Emphasis, every way round

Plain, **bold**, *italic* and `code`.

## Things to watch

- [x] the empty list returns null
- [ ] `prev` must start as **null**, not as `head`

Pick one:

- (x) iterative
- ( ) recursive

## Nested structure

- Outer item with **bold**
  - Inner item with `code`
- Another outer item

> A quote with `code` in it.

Citations: the original [1], and the follow-up [2].

[1]: https://en.wikipedia.org/wiki/Linked_list
[2]: https://en.wikipedia.org/wiki/Cycle_detection
''';

void main() {
  for (final block in [
    GptMarkdownBlockAnimation.growIn,
    GptMarkdownBlockAnimation.fadeIn,
    GptMarkdownBlockAnimation.none,
  ]) {
    testWidgets('a faded stream never shrinks (${block.name} blocks)', (
      tester,
    ) async {
      final key = GlobalKey();
      Widget app(String text, bool streaming) => MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 620,
                child: GptMarkdown(
                  text,
                  key: key,
                  animation: GptMarkdownAnimation.fade,
                  blockAnimation: block,
                  isStreaming: streaming,
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpWidget(app('', true));
      var delivered = 0;
      var last = 0.0;
      final shrinks = <String>[];
      // Chunks of six characters every three frames — about the rate and
      // shape of a real stream.
      while (delivered < _reply.length) {
        delivered = (delivered + 6).clamp(0, _reply.length);
        await tester.pumpWidget(app(_reply.substring(0, delivered), true));
        for (var frame = 0; frame < 3; frame++) {
          await tester.pump(const Duration(milliseconds: 16));
          final height = tester.getSize(find.byKey(key)).height;
          if (height < last - 2) {
            final tail = _reply.substring(0, delivered);
            shrinks.add(
              '${last.toStringAsFixed(1)} -> ${height.toStringAsFixed(1)} '
              'after "${tail.substring(tail.length - 24)}"',
            );
          }
          last = height;
        }
      }
      await tester.pumpWidget(app(_reply, false));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(shrinks, isEmpty);
    });
  }
}
