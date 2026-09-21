import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_markdown/custom_widgets/bidi_rich_text.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

/// `MdWidget` caches the generated spans and only regenerates them when
/// `GptMarkdownConfig.isSame` says something changed. `isSame` is a
/// hand-maintained list of fields, so a field left out of it fails silently:
/// the widget rebuilds with the new config and keeps rendering the old output.
///
/// One test per config field that a consumer is likely to flip at runtime.

/// Rebuilds a [GptMarkdown] in place so the update goes through
/// `didUpdateWidget` rather than a fresh mount.
class _Harness extends StatefulWidget {
  const _Harness({required this.builder});

  final Widget Function(bool toggled) builder;

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  bool _toggled = false;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            ElevatedButton(
              onPressed: () => setState(() => _toggled = !_toggled),
              child: const Text('toggle'),
            ),
            Expanded(
              child: SingleChildScrollView(child: widget.builder(_toggled)),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> toggle(WidgetTester tester) async {
  await tester.tap(find.text('toggle'));
  await tester.pumpAndSettle();
}

/// A link is a `LinkTextSpan` now, not a `LinkButton` widget.
int linkCount(WidgetTester tester) {
  var count = 0;
  for (final rich in tester.widgetList<RichText>(
    find.byWidgetPredicate((w) => w is RichText),
  )) {
    void walk(InlineSpan span) {
      if (span is LinkTextSpan) {
        count += 1;
      }
      span.visitDirectChildren((child) {
        walk(child);
        return true;
      });
    }

    walk(rich.text);
  }
  return count;
}

/// A component with an obvious marker in its output.
class _ShoutMd extends InlineMd {
  @override
  RegExp get exp => RegExp(r'!![A-Za-z]+!!');

  @override
  InlineSpan span(BuildContext context, String text, GptMarkdownConfig config) {
    return TextSpan(text: 'SHOUT', style: config.style);
  }
}

bool _hasShout(Widget widget) =>
    widget is RichText && widget.text.toPlainText().contains('SHOUT');

void main() {
  testWidgets('autolinkSchemes takes effect without a remount', (tester) async {
    await tester.pumpWidget(
      _Harness(
        builder:
            (on) => GptMarkdown(
              'open myapp://thing now',
              autolinkSchemes: on ? const {'myapp'} : const {},
            ),
      ),
    );
    await tester.pumpAndSettle();
    expect(linkCount(tester), 0);

    await toggle(tester);
    expect(linkCount(tester), 1);
  });

  testWidgets('autolink takes effect without a remount', (tester) async {
    await tester.pumpWidget(
      _Harness(
        builder:
            (on) => GptMarkdown('go to https://example.com', autolink: !on),
      ),
    );
    await tester.pumpAndSettle();
    expect(linkCount(tester), 1);

    await toggle(tester);
    expect(linkCount(tester), 0);
  });

  testWidgets('inlineCodeStyle takes effect without a remount', (tester) async {
    await tester.pumpWidget(
      _Harness(
        builder:
            (on) => GptMarkdown(
              'run `code` now',
              inlineCodeStyle: InlineCodeStyle(borderWidth: on ? 0 : 1),
            ),
      ),
    );
    await tester.pumpAndSettle();

    RenderBidiParagraph paragraph() => tester.renderObject<RenderBidiParagraph>(
      find.byWidgetPredicate((w) => w is BidiRichText).first,
    );

    // Fill plus outline.
    expect(paragraph(), paintsExactlyCountTimes(#drawRRect, 2));

    await toggle(tester);
    // Outline removed — fill only.
    expect(paragraph(), paintsExactlyCountTimes(#drawRRect, 1));
  });

  testWidgets('inlineComponents take effect without a remount', (tester) async {
    final extra = [_ShoutMd(), ...MarkdownComponent.inlineComponents];

    await tester.pumpWidget(
      _Harness(
        builder:
            (on) => GptMarkdown(
              'say !!hello!! now',
              inlineComponents: on ? extra : null,
            ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byWidgetPredicate(_hasShout), findsNothing);

    await toggle(tester);
    expect(find.byWidgetPredicate(_hasShout), findsOneWidget);
  });

  testWidgets('inlinePatterns take effect without a remount', (tester) async {
    final patterns = [
      InlinePattern(
        pattern: RegExp(r'#general'),
        builder:
            (context, match, style) =>
                WidgetSpan(child: Text('CHIP:${match.group(0)}')),
      ),
    ];

    await tester.pumpWidget(
      _Harness(
        builder:
            (on) => GptMarkdown(
              'see #general now',
              inlinePatterns: on ? patterns : null,
            ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('CHIP:#general'), findsNothing);

    await toggle(tester);
    expect(find.text('CHIP:#general'), findsOneWidget);
  });
}
