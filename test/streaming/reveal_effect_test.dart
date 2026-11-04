/// The character effects have to look different from one another — the
/// point of offering four. `wave` and `blurIn` both used to collapse into a
/// plain fade: the crest was a grey derived from a grey text colour, and the
/// blur was over before the text was visible.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:material_ui/material_ui.dart';

const _text = Color(0xFFE4E1E9); // a dark theme's onSurface: nearly grey
const _accent = Color(0xFF3D5AFE);

double _alpha(TextStyle style) => (style.foreground?.color ?? style.color!).a;

void main() {
  group('wave', () {
    test('lands in the accent and settles into the text colour', () {
      final start = revealStyleFor(
        GptMarkdownAnimation.wave,
        0.3,
        _text,
        accent: _accent,
      )!;
      // Still clearly the accent's hue, at nearly full strength.
      final hue = HSLColor.fromColor(start.color!).hue;
      expect((hue - HSLColor.fromColor(_accent).hue).abs(), lessThan(20));
      expect(HSLColor.fromColor(start.color!).saturation, greaterThan(0.4));
      expect(_alpha(start), greaterThan(0.9));

      final late = revealStyleFor(
        GptMarkdownAnimation.wave,
        0.95,
        _text,
        accent: _accent,
      )!;
      expect(
        (late.color!.r - _text.r).abs() + (late.color!.b - _text.b).abs(),
        lessThan(0.15),
      );
      expect(
        revealStyleFor(GptMarkdownAnimation.wave, 1, _text, accent: _accent),
        isNull,
      );
    });

    test('without an accent it behaves as it always did', () {
      final style = revealStyleFor(GptMarkdownAnimation.wave, 0.5, _text)!;
      // The crest derived from the text colour: lightness 0.35 toward the
      // middle, halfway settled.
      final hsl = HSLColor.fromColor(_text);
      final crest = hsl.withLightness(hsl.lightness - 0.35).toColor();
      final expected = Color.lerp(crest, _text, 0.5)!;
      expect(style.color!.r, closeTo(expected.r, 0.001));
      expect(style.color!.g, closeTo(expected.g, 0.001));
      expect(style.color!.b, closeTo(expected.b, 0.001));
    });
  });

  group('blurIn', () {
    test('is still soft once the text is clearly visible', () {
      final style = revealStyleFor(
        GptMarkdownAnimation.blurIn,
        0.3,
        _text,
        fontSize: 20,
      )!;
      expect(_alpha(style), greaterThan(0.6));
      expect(style.foreground!.maskFilter, isNotNull);
    });

    test('scales its blur with the text', () {
      String blur(double size) => revealStyleFor(
        GptMarkdownAnimation.blurIn,
        0,
        _text,
        fontSize: size,
      )!.foreground!.maskFilter.toString();
      expect(blur(16), contains('3.2'));
      expect(blur(30), contains('6.0'));
      // Bounded both ways.
      expect(blur(4), contains('1.5'));
      expect(blur(100), contains('8.0'));
    });

    test('ends sharp and opaque', () {
      final style = revealStyleFor(
        GptMarkdownAnimation.blurIn,
        0.97,
        _text,
        fontSize: 20,
      )!;
      expect(style.foreground!.maskFilter, isNull);
      expect(_alpha(style), closeTo(_text.a, 0.001));
    });
  });

  testWidgets('the widget gives wave the theme accent', (tester) async {
    Widget app(String text) => MaterialApp(
      theme: ThemeData(colorSchemeSeed: Colors.deepOrange),
      home: Scaffold(
        body: GptMarkdown(
          text,
          animation: GptMarkdownAnimation.wave,
          revealFadeSeconds: 1,
        ),
      ),
    );
    await tester.pumpWidget(app(''));
    await tester.pumpWidget(app('Some words arriving now'));
    // Revealed (well under a second at the default speed), and the first
    // words about a third of the way into their one-second entrance.
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 30));
    }

    final primary = Theme.of(
      tester.element(find.byType(GptMarkdown)),
    ).colorScheme.primary;
    final colors = <Color>[];
    for (final rich in tester.widgetList<RichText>(find.byType(RichText))) {
      rich.text.visitChildren((span) {
        final c = span.style?.color;
        if (c != null) colors.add(c);
        return true;
      });
    }
    final primaryHue = HSLColor.fromColor(primary).hue;
    expect(
      colors.any(
        (c) =>
            c.a > 0.5 &&
            (HSLColor.fromColor(c).hue - primaryHue).abs() < 25 &&
            HSLColor.fromColor(c).saturation > 0.3,
      ),
      isTrue,
    );
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('the crest stands out even when the theme accent is pastel', (
    tester,
  ) async {
    // Material 3's dark primary is a pastel close to the text colour
    // (#BCC2FF on #E4E1E9 for this seed). Used as-is, the crest was invisible
    // and wave looked exactly like fade.
    Widget app(String text) => MaterialApp(
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF6C7CFF),
        brightness: Brightness.dark,
      ),
      home: Scaffold(
        body: GptMarkdown(
          text,
          animation: GptMarkdownAnimation.wave,
          revealFadeSeconds: 1,
        ),
      ),
    );
    await tester.pumpWidget(app(''));
    await tester.pumpWidget(app('Some words arriving now'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 30));
    }
    final text = Theme.of(
      tester.element(find.byType(GptMarkdown)),
    ).colorScheme.onSurface;
    final textLightness = HSLColor.fromColor(text).lightness;
    var vivid = false;
    for (final rich in tester.widgetList<RichText>(find.byType(RichText))) {
      rich.text.visitChildren((span) {
        final c = span.style?.color;
        if (c != null && c.a > 0.5) {
          final hsl = HSLColor.fromColor(c);
          if (hsl.saturation > 0.6 &&
              (hsl.lightness - textLightness).abs() > 0.2) {
            vivid = true;
          }
        }
        return true;
      });
    }
    expect(vivid, isTrue);
    await tester.pump(const Duration(seconds: 2));
  });
}
