// Generates the README showcase images.
//
// Not a test: it renders the package into PNGs. It lives under `tool/` so
// `flutter test` does not pick it up with the real suite, and it runs through
// the test harness only because that is the supported way to rasterise a
// Flutter widget to a file without opening a window.
//
// Run it with `./scripts/screenshots.sh`.
@Timeout(Duration(minutes: 2))
library;

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

import 'fonts.dart';

/// Where the images land, relative to this file.
const _out = '../../screenshots';

/// One card's worth of Markdown.
///
/// Kept deliberately small. A screenshot is read in about a second, so every
/// line has to earn its place — these show one capability each, in content a
/// reader understands without stopping to parse it.
const _scenes = <String, String>{
  'rich-text': """
# Weekly update

Shipping **v1.2** on Friday — a *small* release. The old `highlightBuilder` is ~~gone~~ deprecated, not removed.

- Faster streaming, with a cached settled prefix
- Friendlier tables with aligned columns
  - Nested items keep their indent
- See the [full changelog](https://pub.dev) for the rest

> One widget renders every line of this, including the quote.

---

Autolinks work too: https://pub.dev/packages/gpt_markdown
""",
  'math': r"""
### Physics homework

Einstein's relation is \(E = mc^2\), and the area under a parabola is

\[ \int_0^1 x^2\,dx = \frac{1}{3} \]

The quadratic formula, for **any** \(ax^2 + bx + c = 0\):

\[ x = \frac{-b \pm \sqrt{b^2 - 4ac}}{2a} \]

- Sums render inline: \(\sum_{i=1}^{n} i = \frac{n(n+1)}{2}\)
- So do fractions: \(\frac{22}{7} \approx \pi\)

Equations sit on the text baseline, so a line never jumps.
""",
  'tables': """
### Sales by region

| Region | Units | Change |
|:-------|------:|:------:|
| North  |   120 |   +8%  |
| South  |    94 |   −3%  |
| East   |   167 |  +12%  |
| West   |    58 |   +1%  |

Columns follow the alignment row — left, right, centre.

| Cell content | Works |
|:-------------|:------|
| **bold** and *italic* | yes |
| `inline code` | yes |
| [links](https://pub.dev) | yes |
""",
  'code': """
### Getting started

Add the package, then render a reply with `GptMarkdown`:

```bash
flutter pub add gpt_markdown
```

```dart
// Render a reply while it streams in.
final view = GptMarkdown(
  reply,
  isStreaming: true,
  onLinkTap: (url, title) => launch(url),
  animation: GptMarkdownAnimation.fade,
);
```

Inline code like `TextSpan` and `PlaceholderAlignment.baseline` wraps across lines instead of overflowing.
""",
  'lists': """
### Today

- [x] Write the parser
- [x] Land the autolink fix
- [ ] Take the screenshots
- [ ] Ship 1.2.1

1. Ordered lists work
2. Numbers come from the text
3. Nested content is kept
   - including bullets
   - and **bold** items

Citations render as tags too [1]
""",
  'inline-components': """
### Sprint review

@ada shipped the parser fix in #release :rocket:

- GH-6124 Blank links on iOS {{status:done}}
- GH-6131 Table overflow on web {{status:review}}
- GH-6140 Caret drift in RTL {{status:blocked}}

@grace takes {{file:table_layout.dart}} next :tada:

> #2959 stays plain text — only names your app knows become components.
""",
};

/// Logical width of one card. About a phone's worth, so the wrapping in the
/// image matches what a reader will see in their own app.
const _cardWidth = 440.0;
const _pagePadding = 26.0;

void main() {
  setUpAll(loadShowcaseFonts);

  for (final scene in _scenes.entries) {
    testWidgets(scene.key, (tester) async {
      const width = _pagePadding * 2 + _cardWidth;
      tester.view.physicalSize = const Size(width * 2, 1800);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_Showcase(markdown: scene.value));
      await tester.pumpAndSettle();
      // Overflow complaints from a deliberately narrow card are noise here.
      while (tester.takeException() != null) {}

      await expectLater(
        find.byKey(_Showcase.frameKey),
        matchesGoldenFile('$_out/${scene.key}.png'),
      );
    });
  }
}

/// Channels, people and shortcodes this showcase knows about.
///
/// Nothing generic is matched: `#2959` in the components scene stays plain
/// text precisely because it is not in this list. That is the package's advice
/// rendered as a picture.
const _channels = ['release', 'design-review'];

/// Each person's initials and avatar colour.
const _people = <String, ({String initials, Color color})>{
  'ada': (initials: 'AL', color: Color(0xFF7C3AED)),
  'grace': (initials: 'GH', color: Color(0xFF0EA5E9)),
  'linus': (initials: 'LT', color: Color(0xFFF97316)),
};

const _shortcodes = <String, (IconData, Color)>{
  'tada': (Icons.celebration_rounded, Color(0xFFDB2777)),
  'rocket': (Icons.rocket_launch_rounded, Color(0xFF4F46E5)),
};

/// Status pills: label, dot colour, background.
const _statuses = <String, (String, Color, Color)>{
  'done': ('Done', Color(0xFF16A34A), Color(0xFFDCFCE7)),
  'review': ('In review', Color(0xFFD97706), Color(0xFFFEF3C7)),
  'blocked': ('Blocked', Color(0xFFDC2626), Color(0xFFFEE2E2)),
};

/// The inline syntax an app layers on top of Markdown.
///
/// Applied to every scene. Only the names above match, so the other scenes are
/// untouched — which is the whole point of leaving `genericTokenPattern` null.
List<InlinePattern> _showcasePatterns(BuildContext context) {
  final colors = Theme.of(context).colorScheme;

  return [
    InlinePattern.prefixed(
      prefix: '#',
      knownNames: _channels,
      builder: (context, match, style) => _pill(
        style: style,
        background: colors.primary.withValues(alpha: 0.08),
        border: colors.primary.withValues(alpha: 0.18),
        children: [
          Icon(
            Icons.tag_rounded,
            size: (style.fontSize ?? 14) * 0.95,
            color: colors.primary,
          ),
          const SizedBox(width: 2),
          _pillLabel(_withoutPrefix(match.group(0)), style, colors.primary),
        ],
      ),
    ),
    InlinePattern.prefixed(
      prefix: '@',
      knownNames: _people.keys,
      builder: (context, match, style) {
        final name = _withoutPrefix(match.group(0));
        final person = _people[name]!;
        return _pill(
          style: style,
          leftInset: 2,
          background: person.color.withValues(alpha: 0.10),
          border: person.color.withValues(alpha: 0.20),
          children: [
            _Avatar(initials: person.initials, color: person.color),
            const SizedBox(width: 5),
            _pillLabel(name, style, person.color),
          ],
        );
      },
    ),
    // Shortcodes resolve to icons rather than emoji: a test renderer has no
    // emoji font, so a glyph would come out as an empty box.
    InlinePattern.delimited(
      open: ':',
      knownNames: _shortcodes.keys,
      builder: (context, match, style) {
        final name = match.namedGroup('name');
        final entry = name == null ? null : _shortcodes[name];
        if (entry == null) {
          return TextSpan(text: match.group(0), style: style);
        }
        return WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Icon(
            entry.$1,
            size: (style.fontSize ?? 14) * 1.15,
            color: entry.$2,
          ),
        );
      },
    ),
    // A TextSpan, so it stays selectable and wraps with the paragraph.
    InlinePattern(
      pattern: RegExp(r'(?<![\w-])GH-(\d+)\b'),
      builder: (context, match, style) => TextSpan(
        text: match.group(0),
        style: style.copyWith(
          color: colors.primary,
          fontWeight: FontWeight.w600,
          fontFamily: 'JetBrainsMono',
          fontSize: (style.fontSize ?? 14) * 0.9,
        ),
      ),
    ),
  ];
}

/// Payloads the parser must not touch: `{{status:done}}`, `{{file:a_b.dart}}`.
///
/// A file name full of underscores is exactly what Markdown would eat as
/// emphasis, which is why these are directives and not patterns.
List<InlineDirective> _showcaseDirectives(BuildContext context) {
  final colors = Theme.of(context).colorScheme;

  return [
    InlineDirective(
      open: '{{',
      close: '}}',
      builder: (context, payload, style) {
        final split = payload.indexOf(':');
        final kind = split < 0 ? payload : payload.substring(0, split);
        final value = split < 0 ? '' : payload.substring(split + 1);
        final size = style.fontSize ?? 14;

        if (kind == 'status' && _statuses.containsKey(value)) {
          final (label, dot, background) = _statuses[value]!;
          return _pill(
            style: style,
            background: background,
            radius: 99,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
              ),
              const SizedBox(width: 5),
              _pillLabel(
                label,
                style.copyWith(fontSize: size * 0.8),
                Color.lerp(dot, Colors.black, 0.35)!,
              ),
            ],
          );
        }
        if (kind == 'file') {
          return _pill(
            style: style,
            background: colors.surfaceContainerHighest.withValues(alpha: 0.6),
            border: colors.outlineVariant,
            children: [
              Icon(
                Icons.description_outlined,
                size: size * 0.95,
                color: colors.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
              _pillLabel(
                value,
                style.copyWith(
                  fontFamily: 'JetBrainsMono',
                  fontSize: size * 0.85,
                  fontWeight: FontWeight.w500,
                ),
                colors.onSurface,
              ),
            ],
          );
        }
        return TextSpan(text: '{{$payload}}', style: style);
      },
    ),
  ];
}

/// Drops the `#` or `@` a prefixed pattern matched along with the name.
String _withoutPrefix(String? token) {
  if (token == null || token.isEmpty) {
    return '';
  }
  return token.substring(1);
}

/// A rounded component centred on the line, sized to sit inside it so the
/// paragraph keeps its rhythm.
InlineSpan _pill({
  required TextStyle style,
  required Color background,
  required List<Widget> children,
  Color? border,
  double radius = 7,
  double leftInset = 7,
}) {
  final size = style.fontSize ?? 14;
  return WidgetSpan(
    alignment: PlaceholderAlignment.middle,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 1),
      child: Container(
        height: size * 1.5,
        padding: EdgeInsets.only(left: leftInset, right: 7),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(radius),
          border: border == null ? null : Border.all(color: border),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: children),
      ),
    ),
  );
}

Widget _pillLabel(String text, TextStyle style, Color color) {
  return Text(
    text,
    style: style.copyWith(color: color, fontWeight: FontWeight.w600, height: 1),
  );
}

/// Initials on a coloured disc — what a mention looks like in a chat app.
class _Avatar extends StatelessWidget {
  const _Avatar({required this.initials, required this.color});

  final String initials;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 17,
      height: 17,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: Text(
        initials,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 7.5,
          fontWeight: FontWeight.w700,
          height: 1,
        ),
      ),
    );
  }
}

/// The few places the defaults are softened for the images.
///
/// Material's checkbox reserves a 48 px tap target, which spaces a task list
/// far apart, and default table rules are a hard black. Everything else is the
/// package's own styling.
GptMarkdownStyleSheet _styleSheet(ColorScheme colors) {
  return GptMarkdownStyleSheet(
    checkbox: const CheckboxStyle(
      size: 18,
      gapAfterBox: 10,
      borderRadius: Radius.circular(4),
    ),
    table: TableStyle(
      borderColor: colors.outlineVariant,
      borderRadius: const Radius.circular(8),
      headerBackground: colors.surfaceContainerHigh,
      headerTextStyle: const TextStyle(fontWeight: FontWeight.w600),
      cellPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
    ),
  );
}

/// One light card on a soft page.
class _Showcase extends StatelessWidget {
  const _Showcase({required this.markdown});

  static const frameKey = ValueKey('showcase-frame');

  final String markdown;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, fontFamily: 'Roboto'),
      home: Align(
        alignment: Alignment.topLeft,
        child: RepaintBoundary(
          key: frameKey,
          child: Container(
            padding: const EdgeInsets.all(_pagePadding),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFF4F6FB), Color(0xFFE4E9F2)],
              ),
            ),
            child: _Card(markdown: markdown),
          ),
        ),
      ),
    );
  }
}

/// The card, drawn as a small window so the image reads as a piece of an app
/// rather than as a slab of text.
class _Card extends StatelessWidget {
  const _Card({required this.markdown});

  final String markdown;

  @override
  Widget build(BuildContext context) {
    // Material 3 light with a white surface, so the image shows the package's
    // own styling rather than a tint the theme would add.
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorSchemeSeed: const Color(0xFF4F46E5),
      fontFamily: 'Roboto',
    );
    final theme = base.copyWith(
      colorScheme: base.colorScheme.copyWith(surface: Colors.white),
      extensions: [GptMarkdownThemeData(brightness: Brightness.light)],
    );

    return SizedBox(
      width: _cardWidth,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE3E7EE)),
          // No shadow: the test renderer draws a blurred shadow as a hard
          // slab, so the border alone separates card from page.
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(15),
          child: Theme(
            data: theme,
            child: Builder(
              builder: (context) => Material(
                color: theme.colorScheme.surface,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const _TitleBar(),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(22, 16, 22, 22),
                      child: GptMarkdown(
                        markdown,
                        inlinePatterns: _showcasePatterns(context),
                        inlineDirectives: _showcaseDirectives(context),
                        styleSheet: _styleSheet(theme.colorScheme),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A window title bar: three lights and a hairline, enough for the eye to read
/// "app" without adding anything to interpret.
class _TitleBar extends StatelessWidget {
  const _TitleBar();

  /// The familiar macOS traffic lights. Recognisable at a glance, and the one
  /// spot of colour in an otherwise quiet frame.
  static const _lights = [
    Color(0xFFFF5F57),
    Color(0xFFFEBC2E),
    Color(0xFF28C840),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: const BoxDecoration(
        color: Color(0xFFF8F9FC),
        border: Border(bottom: BorderSide(color: Color(0xFFECEFF4))),
      ),
      child: Row(
        children: [
          for (var i = 0; i < _lights.length; i++) ...[
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: _lights[i],
                shape: BoxShape.circle,
              ),
            ),
            if (i < _lights.length - 1) const SizedBox(width: 7),
          ],
        ],
      ),
    );
  }
}
