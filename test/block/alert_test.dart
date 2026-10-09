import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_markdown/custom_widgets/indent_widget.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

/// Alerts (#79): a quote whose first line is `[!NOTE]`, `[!TIP]`,
/// `[!IMPORTANT]`, `[!WARNING]` or `[!CAUTION]`.

const _all = '''> [!NOTE]
> Note body.

> [!TIP]
> Tip body.

> [!IMPORTANT]
> Important body.

> [!WARNING]
> Warning body.

> [!CAUTION]
> Caution body.''';

String _text(WidgetTester tester) {
  final buffer = StringBuffer();
  for (final rt in tester.widgetList<RichText>(find.byType(RichText))) {
    buffer.writeln(rt.text.toPlainText(includePlaceholders: false));
  }
  return buffer.toString();
}

Future<void> _pump(
  WidgetTester tester,
  String data, {
  bool legacy = false,
  GptMarkdownStyleSheet? styleSheet,
  BlockQuoteBuilder? blockQuoteBuilder,
  AlertBuilder? alertBuilder,
  Brightness brightness = Brightness.light,
  double textScale = 1,
  bool intrinsicWidth = false,
}) async {
  Widget child = GptMarkdown(
    data,
    inlineComponents: legacy ? MarkdownComponent.inlineComponents : null,
    styleSheet: styleSheet,
    blockQuoteBuilder: blockQuoteBuilder,
    alertBuilder: alertBuilder,
  );
  if (intrinsicWidth) {
    child = IntrinsicWidth(child: child);
  }
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(brightness: brightness),
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Color _barColor(WidgetTester tester, {int index = 0}) => tester
    .widgetList<BlockQuoteWidget>(find.byType(BlockQuoteWidget))
    .elementAt(index)
    .color;

/// The alert's own clip: the package clips elsewhere too.
Finder get _clips => find.byWidgetPredicate(
  (w) =>
      w is ClipRRect &&
      w.borderRadius == const BorderRadius.all(Radius.circular(6)),
);

void main() {
  group('parsing', () {
    MdBlockQuote quote(String source) =>
        Plusparse.parse(source).children.single as MdBlockQuote;

    test('each marker sets its type and strips the marker from the body', () {
      for (final type in MarkdownAlertType.values) {
        final q = quote('> [!${type.name.toUpperCase()}]\n> Body.');
        expect(q.alert?.type, type);
        final body = q.alert!.children.single as MdParagraph;
        expect((body.children.single as MdText).text, 'Body.');
      }
    });

    test('the quote children are what they were before alerts', () {
      final q = quote('> [!NOTE]\n> Body.');
      final first = q.children.first as MdParagraph;
      expect(
        first.children.whereType<MdText>().map((e) => e.text).join(),
        contains('[!NOTE]'),
      );
    });

    test('markers are case-insensitive and ignore surrounding space', () {
      expect(
        quote('> [!warning]  \n> x').alert?.type,
        MarkdownAlertType.warning,
      );
      expect(quote('>   [!Tip]\n> x').alert?.type, MarkdownAlertType.tip);
    });

    test('anything else stays an ordinary quote', () {
      expect(quote('> [!FOO]\n> x').alert, isNull);
      expect(quote('> [!NOTE] with text\n> x').alert, isNull);
      expect(quote('> x\n> [!NOTE]').alert, isNull);
      expect(quote('> plain').alert, isNull);
    });

    test('a marker with no body yet is an alert with an empty body', () {
      final q = quote('> [!NOTE]');
      expect(q.alert?.type, MarkdownAlertType.note);
      expect(q.alert!.children, isEmpty);
    });
  });

  for (final legacy in [false, true]) {
    final pipeline = legacy ? 'legacy' : 'plusparse';

    group(pipeline, () {
      testWidgets('renders every type with its title and body', (tester) async {
        await _pump(tester, _all, legacy: legacy);
        expect(tester.takeException(), isNull);
        final text = _text(tester);
        for (final title in [
          'Note',
          'Tip',
          'Important',
          'Warning',
          'Caution',
        ]) {
          expect(text, contains(title));
          expect(text, contains('$title body.'));
        }
        expect(text, isNot(contains('[!')));
        expect(find.byType(Icon), findsNWidgets(5));
      });

      testWidgets('each type has its own accent, light and dark', (
        tester,
      ) async {
        for (final brightness in Brightness.values) {
          await _pump(tester, _all, legacy: legacy, brightness: brightness);
          final colours = {
            for (var i = 0; i < 5; i++) _barColor(tester, index: i),
          };
          expect(colours, hasLength(5));
        }
        await _pump(tester, '> [!NOTE]\n> x', legacy: legacy);
        final light = _barColor(tester);
        await _pump(
          tester,
          '> [!NOTE]\n> x',
          legacy: legacy,
          brightness: Brightness.dark,
        );
        expect(_barColor(tester), isNot(light));
      });

      testWidgets('an ordinary quote is unchanged', (tester) async {
        await _pump(tester, '> just a quote', legacy: legacy);
        expect(_text(tester), contains('just a quote'));
        expect(find.byType(Icon), findsNothing);
      });

      testWidgets('an unknown marker is left as written', (tester) async {
        await _pump(tester, '> [!FOO]\n> x', legacy: legacy);
        expect(_text(tester), contains('[!FOO]'));
        expect(find.byType(Icon), findsNothing);
      });

      testWidgets('per-type style wins over the shared style', (tester) async {
        await _pump(
          tester,
          _all,
          legacy: legacy,
          styleSheet: const GptMarkdownStyleSheet(
            alert: AlertStyle(
              color: Color(0xFF111111),
              title: 'Shared',
              warning: AlertStyle(
                color: Color(0xFF222222),
                title: 'Heads up',
                icon: Icons.bolt,
              ),
            ),
          ),
        );
        final text = _text(tester);
        expect(text, contains('Heads up'));
        expect('Shared'.allMatches(text), hasLength(4));
        expect(_barColor(tester, index: 0), const Color(0xFF111111));
        expect(_barColor(tester, index: 3), const Color(0xFF222222));
        expect(find.byIcon(Icons.bolt), findsOneWidget);
      });

      testWidgets('an empty title and no icon hide the title row', (
        tester,
      ) async {
        await _pump(
          tester,
          '> [!NOTE]\n> Body only.',
          legacy: legacy,
          styleSheet: const GptMarkdownStyleSheet(
            alert: AlertStyle(title: '', showIcon: false),
          ),
        );
        expect(_text(tester), isNot(contains('Note')));
        expect(_text(tester), contains('Body only.'));
        expect(find.byType(Icon), findsNothing);
      });

      testWidgets('an app with a blockQuoteBuilder keeps its quotes', (
        tester,
      ) async {
        final seen = <String>[];
        await _pump(
          tester,
          '> [!NOTE]\n> Body.',
          legacy: legacy,
          blockQuoteBuilder: (context, content, style) {
            seen.add('quote');
            return content;
          },
        );
        expect(seen, isNotEmpty);
        expect(_text(tester), contains('[!NOTE]'));
        expect(find.byType(Icon), findsNothing);
      });

      testWidgets('alertBuilder gets the details and the stock widgets', (
        tester,
      ) async {
        final details = <AlertBuildDetails>[];
        await _pump(
          tester,
          '> [!TIP]\n> Body.\n\n> [!CAUTION]\n> Other.',
          legacy: legacy,
          blockQuoteBuilder: (context, content, style) => content,
          alertBuilder: (context, d) {
            details.add(d);
            return d.type == MarkdownAlertType.tip
                ? d.defaultAlert()
                : d.asBlockQuote();
          },
        );
        expect(details.map((d) => d.type), [
          MarkdownAlertType.tip,
          MarkdownAlertType.caution,
        ]);
        expect(details.first.style.title, 'Tip');
        expect(details.first.style.color, isNotNull);
        final text = _text(tester);
        expect(text, contains('Tip'));
        expect(text, contains('[!CAUTION]'));
        expect(text, contains('Other.'));
      });

      for (final textScale in [1.0, 2.0, 3.0]) {
        testWidgets('lays out at ${textScale}x', (tester) async {
          await _pump(tester, _all, legacy: legacy, textScale: textScale);
          expect(tester.takeException(), isNull);
        });
      }
    });
  }

  testWidgets('the icon scales with the text', (tester) async {
    await _pump(tester, '> [!NOTE]\n> x');
    // Measured on screen: an inline widget is scaled by a paint transform,
    // so its layout size stays the same.
    final one = tester.getRect(find.byType(Icon)).height;
    await _pump(tester, '> [!NOTE]\n> x', textScale: 2);
    expect(
      tester.getRect(find.byType(Icon)).height,
      moreOrLessEquals(one * 2, epsilon: 0.5),
    );
  });

  testWidgets('works inside IntrinsicWidth', (tester) async {
    await _pump(tester, _all, intrinsicWidth: true);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a streamed alert turns into one when its marker completes', (
    tester,
  ) async {
    await _pump(tester, '> [!NO');
    expect(find.byType(Icon), findsNothing);
    await _pump(tester, '> [!NOTE]\n> Stre');
    expect(find.byType(Icon), findsOneWidget);
    await _pump(tester, '> [!NOTE]\n> Streamed body.');
    expect(_text(tester), contains('Streamed body.'));
  });

  testWidgets('the theme style applies and the widget wins per field', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          extensions: [
            GptMarkdownThemeData(
              brightness: Brightness.light,
              styleSheet: const GptMarkdownStyleSheet(
                alert: AlertStyle(title: 'Themed', color: Color(0xFF333333)),
              ),
            ),
          ],
        ),
        home: const Scaffold(
          body: GptMarkdown(
            '> [!NOTE]\n> x',
            styleSheet: GptMarkdownStyleSheet(
              alert: AlertStyle(color: Color(0xFF444444)),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(_text(tester), contains('Themed'));
    expect(_barColor(tester), const Color(0xFF444444));
  });

  testWidgets('a faint tint of the accent fills the alert by default', (
    tester,
  ) async {
    for (final brightness in Brightness.values) {
      await _pump(tester, '> [!WARNING]\n> x', brightness: brightness);
      final accent = _barColor(tester);
      final alpha = brightness == Brightness.dark ? 0.12 : 0.08;
      expect(
        find.byWidgetPredicate(
          (w) => w is ColoredBox && w.color == accent.withValues(alpha: alpha),
        ),
        findsOneWidget,
      );
      expect(_clips, findsOneWidget);
    }
  });

  testWidgets('a transparent background and zero radius turn both off', (
    tester,
  ) async {
    await _pump(
      tester,
      '> [!WARNING]\n> x',
      styleSheet: const GptMarkdownStyleSheet(
        alert: AlertStyle(
          backgroundColor: Colors.transparent,
          borderRadius: Radius.zero,
        ),
      ),
    );
    final accent = _barColor(tester);
    expect(
      find.byWidgetPredicate(
        (w) => w is ColoredBox && w.color.a < 1 && w.color.r == accent.r,
      ),
      findsNothing,
    );
    expect(_clips, findsNothing);
  });

  testWidgets('a custom accent colour tints with that colour', (tester) async {
    await _pump(
      tester,
      '> [!NOTE]\n> x',
      styleSheet: const GptMarkdownStyleSheet(
        alert: AlertStyle(color: Color(0xFF00AA00)),
      ),
    );
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is ColoredBox &&
            w.color == const Color(0xFF00AA00).withValues(alpha: 0.08),
      ),
      findsOneWidget,
    );
  });

  test('AlertStyle merge, copyWith, lerp and equality', () {
    const a = AlertStyle(barWidth: 2, note: AlertStyle(title: 'A'));
    const b = AlertStyle(
      barWidth: 8,
      color: Color(0xFF000000),
      note: AlertStyle(icon: Icons.bolt),
    );
    final merged = a.merge(b);
    expect(merged.barWidth, 2);
    expect(merged.color, const Color(0xFF000000));
    expect(merged.note, const AlertStyle(title: 'A', icon: Icons.bolt));
    expect(a.copyWith(barWidth: 5).barWidth, 5);
    expect(AlertStyle.lerp(a, b, 0.5)!.barWidth, 5);
    expect(a, const AlertStyle(barWidth: 2, note: AlertStyle(title: 'A')));
    expect(a == b, isFalse);
    expect(
      const GptMarkdownStyleSheet(
        alert: a,
      ).merge(const GptMarkdownStyleSheet(alert: b)).alert,
      merged,
    );

    final resolved = merged.resolve(
      MarkdownAlertType.note,
      const ColorScheme.light(),
    );
    expect(resolved.title, 'A');
    expect(resolved.icon, Icons.bolt);
    expect(resolved.showIcon, isTrue);
    expect(resolved.note, isNull);
    expect(
      const AlertStyle()
          .resolve(MarkdownAlertType.tip, const ColorScheme.light())
          .title,
      'Tip',
    );
  });
}
