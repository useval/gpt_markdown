import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import '../utils/test_helpers.dart';

Iterable<TextSpan> descendantTextSpans(InlineSpan span) sync* {
  if (span is! TextSpan) return;
  yield span;
  for (final child in span.children ?? const <InlineSpan>[]) {
    yield* descendantTextSpans(child);
  }
}

RichText codeRichText(WidgetTester tester, String code) {
  return tester.widget<RichText>(
    find.byWidgetPredicate(
      (widget) => widget is RichText && widget.text.toPlainText() == code,
    ),
  );
}

void main() {
  group('Code blocks', () {
    testWidgets('simple code block', (tester) async {
      await pumpMarkdown(tester, '```\ncode here\n```');
      final output = getSerializedOutput(tester);
      expect(output, contains('CODE_BLOCK'));
      expect(output, contains('code here'));
      expect(find.text('Code'), findsOneWidget);
    });

    testWidgets('code block with language', (tester) async {
      await pumpMarkdown(tester, '```dart\nvoid main() {}\n```');
      final output = getSerializedOutput(tester);
      expect(output, contains('CODE_BLOCK'));
      expect(output, contains('lang="dart"'));
      expect(output, contains('void main()'));
    });

    testWidgets('code block with javascript', (tester) async {
      await pumpMarkdown(tester, '```javascript\nconst x = 1;\n```');
      final output = getSerializedOutput(tester);
      expect(output, contains('CODE_BLOCK'));
      expect(output, contains('lang="javascript"'));
    });

    testWidgets('code block with python', (tester) async {
      await pumpMarkdown(tester, '```python\ndef hello():\n    pass\n```');
      final output = getSerializedOutput(tester);
      expect(output, contains('CODE_BLOCK'));
      expect(output, contains('lang="python"'));
    });

    testWidgets('known language receives syntax token colours', (tester) async {
      const code = 'void main() {\n  final value = "hello";\n}';
      await pumpMarkdown(tester, '```dart\n$code\n```');

      final spans = descendantTextSpans(codeRichText(tester, code).text);
      final tokenColors =
          spans.map((span) => span.style?.color).whereType<Color>();

      expect(tokenColors.toSet().length, greaterThanOrEqualTo(2));
    });

    testWidgets('python functions use a varied token palette', (tester) async {
      const code = '''@staticmethod
def greet(name: str, count: int = 3):
    # Welcome the user
    if count > 0:
        print(f"Hello {name}")
    return None''';
      await pumpMarkdown(tester, '```python\n$code\n```');

      final spans = descendantTextSpans(codeRichText(tester, code).text);
      final tokenColors =
          spans.map((span) => span.style?.color).whereType<Color>().toSet();

      expect(tokenColors.length, greaterThanOrEqualTo(5));
    });

    testWidgets('common language alias is highlighted', (tester) async {
      const code = 'const answer = 42;';
      await pumpMarkdown(tester, '```js\n$code\n```');

      final spans = descendantTextSpans(codeRichText(tester, code).text);
      expect(spans.any((span) => span.style?.color != null), isTrue);
    });

    testWidgets('unknown language falls back to unchanged plain text', (
      tester,
    ) async {
      const code = 'some untouched source();';
      await pumpMarkdown(tester, '```not-a-real-language\n$code\n```');

      final richText = codeRichText(tester, code);
      final spans = descendantTextSpans(richText.text).toList();
      expect(richText.text.toPlainText(), code);
      expect(spans.skip(1).every((span) => span.style?.color == null), isTrue);
    });

    testWidgets('copy action is icon-only and briefly shows a check', (
      tester,
    ) async {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async => null,
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      final semantics = tester.ensureSemantics();
      await pumpMarkdown(tester, '```dart\nfinal value = 1;\n```');

      expect(find.text('Copy code'), findsNothing);
      expect(find.byIcon(Icons.content_copy_rounded), findsOneWidget);
      // Icon-only: the label is the tooltip and the accessible name, never
      // visible text. The control is interactive from the first build — it
      // used to be a plain icon until a pointer arrived, which left it
      // unreachable by keyboard and swallowed the first stylus tap. See
      // test/regression/code_copy_reachability_test.dart.
      expect(find.byType(InkWell), findsOneWidget);
      expect(
        tester.getSemantics(find.byIcon(Icons.content_copy_rounded)).label,
        contains('Copy code'),
      );
      semantics.dispose();

      await tester.tap(find.byIcon(Icons.content_copy_rounded));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
      // The first tap promotes it, so the check mark animates like the real
      // control rather than snapping.
      expect(tester.widget<InkWell>(find.byType(InkWell)).onTap, isNotNull);
      // The button is deliberately NOT pointer-disabled during the check-mark
      // window. Wrapping it in `IgnorePointer`/`AbsorbPointer` did not stop a
      // second tap reaching an ancestor — an ancestor is already on the
      // hit-test path — it only stopped the button claiming the gesture, so
      // the tap fell through to whatever wraps the code block. The
      // duplicate-clipboard guard lives in `_copyCode`; see
      // test/regression/code_copy_tap_fallthrough_test.dart.
      expect(
        find.ancestor(
          of: find.byIcon(Icons.check_rounded),
          matching: find.byWidgetPredicate(
            (widget) =>
                (widget is IgnorePointer && widget.ignoring) ||
                (widget is AbsorbPointer && widget.absorbing),
          ),
        ),
        findsNothing,
      );

      await tester.pump(const Duration(seconds: 2));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byIcon(Icons.content_copy_rounded), findsOneWidget);
      expect(tester.widget<InkWell>(find.byType(InkWell)).onTap, isNotNull);
    });

    testWidgets('code block preserves content', (tester) async {
      await pumpMarkdown(tester, '```\nline1\nline2\nline3\n```');
      final output = getSerializedOutput(tester);
      expect(output, contains('CODE_BLOCK'));
      expect(output, contains('line1'));
    });

    testWidgets('unclosed code block', (tester) async {
      await pumpMarkdown(tester, '```dart\nunclosed code');
      final output = getSerializedOutput(tester);
      // Library may handle unclosed blocks gracefully
      expect(output, contains('CODE_BLOCK'));
    });

    testWidgets('empty code block', (tester) async {
      await pumpMarkdown(tester, '```\n```');
      final output = getSerializedOutput(tester);
      expect(output, contains('CODE_BLOCK'));
    });
  });
}
