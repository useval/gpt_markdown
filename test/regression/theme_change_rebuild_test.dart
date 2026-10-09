import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

/// `MdWidget` caches the generated spans for performance. Colours are resolved
/// while those spans are built, so anything inherited that feeds a colour —
/// the `ThemeData`, a `GptMarkdownTheme`, the text direction — has to
/// invalidate that cache. It is a silent failure when it does not: the widget
/// rebuilds and keeps painting the previous theme.

/// Flips between two states in place, so updates go through
/// `didUpdateWidget` / `didChangeDependencies` rather than a fresh mount.
class _Flip extends StatefulWidget {
  const _Flip({required this.builder});

  final Widget Function(bool flipped) builder;

  @override
  State<_Flip> createState() => _FlipState();
}

class _FlipState extends State<_Flip> {
  bool _flipped = false;

  @override
  Widget build(BuildContext context) => widget.builder(_flipped);

  void flip() => setState(() => _flipped = !_flipped);
}

Future<void> flip(WidgetTester tester) async {
  tester.state<_FlipState>(find.byType(_Flip)).flip();
  await tester.pumpAndSettle();
}

List<InlineSpan> allSpans(WidgetTester tester) {
  final spans = <InlineSpan>[];
  void visit(InlineSpan span) {
    spans.add(span);
    if (span is TextSpan) {
      span.children?.forEach(visit);
    }
  }

  for (final rt in tester.widgetList<RichText>(
    find.byWidgetPredicate((w) => w is RichText),
  )) {
    visit(rt.text);
  }
  return spans;
}

Color? inlineCodeColor(WidgetTester tester) =>
    allSpans(tester).whereType<CodeTextSpan>().single.style?.color;

void main() {
  testWidgets('inline code follows a light/dark switch', (tester) async {
    await tester.pumpWidget(
      _Flip(
        builder: (dark) => MaterialApp(
          theme: ThemeData(useMaterial3: true),
          darkTheme: ThemeData(useMaterial3: true, brightness: Brightness.dark),
          themeMode: dark ? ThemeMode.dark : ThemeMode.light,
          home: const Scaffold(body: GptMarkdown('run `code` now')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final light = inlineCodeColor(tester);
    expect(light, isNotNull);

    await flip(tester);
    expect(
      inlineCodeColor(tester),
      isNot(light),
      reason: 'the chip text colour is derived from the ColorScheme',
    );
  });

  testWidgets('a new GptMarkdownTheme takes effect', (tester) async {
    await tester.pumpWidget(
      _Flip(
        builder: (flipped) => MaterialApp(
          theme: ThemeData(
            useMaterial3: true,
            extensions: [
              GptMarkdownThemeData(
                brightness: Brightness.light,
                inlineCode: InlineCodeStyle(
                  color: flipped
                      ? const Color(0xFF00FF00)
                      : const Color(0xFFFF0000),
                ),
              ),
            ],
          ),
          home: const Scaffold(body: GptMarkdown('run `code` now')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(inlineCodeColor(tester), const Color(0xFFFF0000));

    await flip(tester);
    expect(inlineCodeColor(tester), const Color(0xFF00FF00));
  });

  testWidgets('link colour follows the theme', (tester) async {
    Color? linkColour() {
      for (final span in allSpans(tester)) {
        final decoration = span.style?.decoration;
        if (decoration == TextDecoration.underline) {
          return span.style?.color;
        }
      }
      return null;
    }

    await tester.pumpWidget(
      _Flip(
        builder: (flipped) => MaterialApp(
          theme: ThemeData(
            useMaterial3: true,
            extensions: [
              GptMarkdownThemeData(
                brightness: Brightness.light,
                linkColor: flipped
                    ? const Color(0xFF00FF00)
                    : const Color(0xFFFF0000),
              ),
            ],
          ),
          home: const Scaffold(
            body: GptMarkdown('see [docs](https://example.com)'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(linkColour(), const Color(0xFFFF0000));

    await flip(tester);
    expect(linkColour(), const Color(0xFF00FF00));
  });

  testWidgets('heading styles follow the theme', (tester) async {
    double? headingSize() => allSpans(tester)
        .whereType<TextSpan>()
        .firstWhere((s) => s.text == 'Title')
        .style
        ?.fontSize;

    await tester.pumpWidget(
      _Flip(
        builder: (flipped) => MaterialApp(
          theme: ThemeData(
            useMaterial3: true,
            extensions: [
              GptMarkdownThemeData(
                brightness: Brightness.light,
                h1: TextStyle(fontSize: flipped ? 40 : 20),
              ),
            ],
          ),
          home: const Scaffold(body: GptMarkdown('# Title')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(headingSize(), 20);

    await flip(tester);
    expect(headingSize(), 40);
  });
}
