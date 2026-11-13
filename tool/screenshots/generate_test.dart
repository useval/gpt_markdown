// Generates the README showcase images, and the images and streaming clip the
// docs (`docs/`) show.
//
// Not a test: it renders the package into PNGs. It lives under `tool/` so
// `flutter test` does not pick it up with the real suite, and it runs through
// the test harness only because that is the supported way to rasterise a
// Flutter widget to a file without opening a window.
//
// Run it with `./scripts/screenshots.sh`.
@Timeout(Duration(minutes: 5))
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show SynchronousFuture;
import 'package:flutter/rendering.dart';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

import 'fonts.dart';

/// Where the images land, relative to this file.
const _out = '../../screenshots';

/// The docs' own images, at 2× for high-density screens (the README's are 1×).
/// The docs reuse the README images as well. Relative to the package root,
/// where `flutter test` runs.
const _docsOut = 'docs/images';

/// Frames of the streaming clip; `scripts/screenshots.sh` encodes them into
/// `docs/videos/streaming.mp4`. Under `build/`, so never committed.
const _framesOut = 'build/streaming-frames';

/// Renders for the product page on the company website: the same scenes with
/// no window or page around them (the site draws its own frame), at 3×.
/// Under `build/`, so never committed; the website's
/// `npm run product-assets` runs this group and converts what it writes.
const _siteOut = 'build/site';

/// Writes the frame to [path] at [ratio] times its logical size.
///
/// `matchesGoldenFile` captures at 1×, which reads soft on a high-density
/// screen; the docs site shows these images at their logical width.
Future<void> _save2x(
  WidgetTester tester,
  String path, {
  double ratio = 2,
}) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_Showcase.frameKey),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: ratio);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    File(path)
      ..parent.createSync(recursive: true)
      ..writeAsBytesSync(png!.buffer.asUint8List());
  });
}

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

/// Images only the docs need, beyond the README's.
final _docScenes = <String, _Scene>{
  'quickstart': const _Scene(
    "# Hello\n\nSome **bold** text and `inline code`.",
  ),
  'alerts': const _Scene('''
> [!NOTE]
> Your usage resets at midnight UTC.

> [!TIP]
> Pass `isStreaming: true` while the reply is still generating.

> [!IMPORTANT]
> Keys created before March need to be rotated.

> [!WARNING]
> Deleting a project deletes its API keys too.
'''),
  'html': const _Scene('''
### Plans

Press <kbd>Ctrl</kbd> + <kbd>K</kbd> to compare. Search terms are <mark>highlighted</mark>; H<sub>2</sub>O and x<sup>2</sup> work too.

<table>
  <thead><tr><th>Plan</th><th colspan="2">Limits</th></tr></thead>
  <tbody>
    <tr><td rowspan="2">Free</td><td>Requests</td><td>1,000 / day</td></tr>
    <tr><td>Seats</td><td>3</td></tr>
    <tr><td>Team</td><td>Requests</td><td>Unlimited</td></tr>
  </tbody>
</table>
'''),
  // The same reply twice: the package's defaults, then the style sheet the
  // customization guide shows (`docsStyleSheet` in test/docs/snippets_test.dart).
  'style-default': const _Scene(_styledReply, sheet: _defaultSheet),
  'style-custom': const _Scene(_styledReply, sheet: _customSheet),
};

const _styledReply = '''
## Release notes

Version **2.0** ships the new [importer](https://pub.dev) and drops `legacyMode`.

> Existing projects keep working; nothing to migrate.

```dart
final project = await Project.open('notes');
```
''';

GptMarkdownStyleSheet _defaultSheet(ColorScheme colors) =>
    const GptMarkdownStyleSheet();

/// Mirrors `docsStyleSheet` in test/docs/snippets_test.dart — keep them alike.
GptMarkdownStyleSheet _customSheet(ColorScheme colors) => GptMarkdownStyleSheet(
  heading: const HeadingStyle(
    textStyle: TextStyle(fontWeight: FontWeight.w700, letterSpacing: -0.6),
  ),
  link: LinkStyle(
    color: colors.primary,
    decoration: TextDecoration.none,
    fontWeight: FontWeight.w600,
  ),
  blockQuote: BlockQuoteStyle(
    barWidth: 4,
    barColor: colors.primary,
    barRadius: const Radius.circular(2),
    backgroundColor: colors.primary.withValues(alpha: 0.06),
    padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
  ),
  codeBlock: CodeBlockStyle(
    borderRadius: const Radius.circular(12),
    borderColor: colors.primary.withValues(alpha: 0.25),
  ),
);

/// The reply the streaming clip types out.
const _streamingReply = r'''
## Why is the sky blue?

Sunlight is a mix of colours. Air molecules scatter **short wavelengths** much more than long ones — the strength goes as \(1/\lambda^4\):

- Blue light scatters about **5×** more than red
- So blue reaches your eyes from every direction

```python
ratio = (700 / 450) ** 4   # ≈ 5.8
```

At sunset the light crosses more air, the blue is scattered away, and the sky turns *orange*.
''';

/// One image: its Markdown, and the style sheet it renders with.
class _Scene {
  const _Scene(this.markdown, {this.sheet = _styleSheet});

  final String markdown;
  final GptMarkdownStyleSheet Function(ColorScheme colors) sheet;
}

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

  for (final scene in _docScenes.entries) {
    testWidgets('docs: ${scene.key}', (tester) async {
      const width = _pagePadding * 2 + _cardWidth;
      tester.view.physicalSize = const Size(width * 2, 1800);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _Showcase(markdown: scene.value.markdown, sheet: scene.value.sheet),
      );
      await tester.pumpAndSettle();
      while (tester.takeException() != null) {}

      await _save2x(tester, '$_docsOut/${scene.key}.png');
    });
  }

  // One image per component page, from tool/screenshots/components/<slug>.md.
  // The page shows the same file in its Markdown tab, so the two can't drift.
  final examples =
      Directory('tool/screenshots/components')
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.md'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));
  for (final file in examples) {
    final slug = file.uri.pathSegments.last.replaceAll('.md', '');
    testWidgets('docs: component $slug', (tester) async {
      const width = _pagePadding * 2 + _cardWidth;
      tester.view.physicalSize = const Size(width * 2, 1800);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);
      await _serveChart(tester);

      // The package's defaults: a component page shows what you get.
      await tester.pumpWidget(
        _Showcase(markdown: file.readAsStringSync(), sheet: _defaultSheet),
      );
      await tester.pumpAndSettle();
      while (tester.takeException() != null) {}

      await _save2x(tester, '$_docsOut/components/$slug.png');
      // A font load (KaTeX's) announces itself while the capture runs and
      // schedules one more frame; let the message land, then run that frame.
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump();
    });
  }

  // ─── The website's renders: bare, at 3× ─────────────────────────────────
  Future<void> siteShot(
    WidgetTester tester,
    String name,
    Widget scene, {
    double ratio = 3,
  }) async {
    tester.view.physicalSize = const Size(_cardWidth * 3, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await _serveChart(tester);
    await tester.pumpWidget(scene);
    await tester.pumpAndSettle();
    while (tester.takeException() != null) {}
    await _save2x(tester, '$_siteOut/$name.png', ratio: ratio);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();
  }

  for (final file in examples) {
    final slug = file.uri.pathSegments.last.replaceAll('.md', '');
    testWidgets('site: component $slug', (tester) async {
      await siteShot(
        tester,
        'components/$slug',
        _Showcase(
          markdown: file.readAsStringSync(),
          sheet: _defaultSheet,
          bare: true,
        ),
      );
    });
  }
  testWidgets('site: style-default', (tester) async {
    await siteShot(
      tester,
      'style-default',
      const _Showcase(markdown: _styledReply, sheet: _defaultSheet, bare: true),
    );
  });
  testWidgets('site: style-custom', (tester) async {
    await siteShot(
      tester,
      'style-custom',
      const _Showcase(markdown: _styledReply, sheet: _customSheet, bare: true),
    );
  });
  testWidgets('site: inline-components', (tester) async {
    await siteShot(
      tester,
      'inline-components',
      _Showcase(markdown: _scenes['inline-components']!, bare: true),
    );
  });

  // The streaming clip: the reply arrives in chunks, as from a model, with the
  // fade reveal on. One frame every 80 ms of (fake) time — 12.5 fps.
  Future<void> streamFrames(
    WidgetTester tester,
    String out, {
    bool bare = false,
  }) async {
    final width = bare ? _cardWidth : _pagePadding * 2 + _cardWidth;
    tester.view.physicalSize = Size(width * 2, 1800);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    const step = Duration(milliseconds: 80);
    const charsPerStep = 8; // ≈ 100 characters a second, a typical model
    var frame = 0;
    Future<void> capture() =>
        _save2x(tester, '$out/${(frame++).toString().padLeft(3, '0')}.png');

    for (var n = 0; n <= _streamingReply.length; n += charsPerStep) {
      await tester.pumpWidget(
        _Showcase(
          markdown: _streamingReply.substring(0, n),
          streaming: true,
          height: _streamingHeight,
          bare: bare,
        ),
      );
      await tester.pump(step);
      while (tester.takeException() != null) {}
      await capture();
    }
    // Generation ends; let the reveal finish, then hold the result.
    await tester.pumpWidget(
      _Showcase(
        markdown: _streamingReply,
        streaming: true,
        isStreaming: false,
        height: _streamingHeight,
        bare: bare,
      ),
    );
    for (var i = 0; i < 30; i++) {
      await tester.pump(step);
      while (tester.takeException() != null) {}
      await capture();
    }
  }

  testWidgets(
    'docs: streaming frames',
    (tester) => streamFrames(tester, _framesOut),
  );
  testWidgets(
    'site: streaming frames',
    (tester) => streamFrames(tester, '$_siteOut/streaming-frames', bare: true),
  );
}

/// The address the image example points at.
const _chartUrl = 'https://example.com/charts/signups.png';

/// Puts a drawn bar chart in the image cache under [_chartUrl], so the image
/// example renders exactly as the package draws a network image that returns
/// it — without a network, which the test harness does not have.
Future<void> _serveChart(WidgetTester tester) async {
  final image = await tester.runAsync(() {
    const size = Size(640, 300);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)
      ..drawRect(Offset.zero & size, Paint()..color = const Color(0xFFF8F9FC));
    final grid = Paint()
      ..color = const Color(0xFFE3E7EE)
      ..strokeWidth = 2;
    for (var y = 60.0; y < 260; y += 50) {
      canvas.drawLine(Offset(40, y), Offset(size.width - 40, y), grid);
    }
    const values = [0.35, 0.48, 0.42, 0.61, 0.58, 0.74, 0.86];
    const barWidth = 56.0;
    final gap =
        (size.width - 80 - barWidth * values.length) / (values.length - 1);
    for (var i = 0; i < values.length; i++) {
      final left = 40 + i * (barWidth + gap);
      final height = 200 * values[i];
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTWH(left, 260 - height, barWidth, height),
          topLeft: const Radius.circular(8),
          topRight: const Radius.circular(8),
        ),
        Paint()
          ..color = Color.lerp(
            const Color(0xFFA5B4FC),
            const Color(0xFF4F46E5),
            i / (values.length - 1),
          )!,
      );
    }
    canvas.drawLine(
      const Offset(40, 260),
      Offset(size.width - 40, 260),
      Paint()
        ..color = const Color(0xFF94A3B8)
        ..strokeWidth = 2,
    );
    return recorder.endRecording().toImage(
      size.width.toInt(),
      size.height.toInt(),
    );
  });
  PaintingBinding.instance.imageCache.putIfAbsent(
    const NetworkImage(_chartUrl),
    () => OneFrameImageStreamCompleter(
      SynchronousFuture(ImageInfo(image: image!)),
    ),
  );
}

/// Fixed card height for the clip, so every frame is the same size.
const _streamingHeight = 400.0;

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
  const _Showcase({
    required this.markdown,
    this.sheet = _styleSheet,
    this.streaming = false,
    this.isStreaming = true,
    this.height,
    this.bare = false,
  });

  static const frameKey = ValueKey('showcase-frame');

  /// Just the content on white: no page, no window.
  final bool bare;

  final String markdown;
  final GptMarkdownStyleSheet Function(ColorScheme colors) sheet;

  /// Render as a live reply: the fade reveal, with [isStreaming] passed on.
  final bool streaming;
  final bool isStreaming;

  /// A fixed card body height; null sizes the card to its content.
  final double? height;

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
            padding: bare
                ? EdgeInsets.zero
                : const EdgeInsets.all(_pagePadding),
            decoration: bare
                ? null
                : const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFF4F6FB), Color(0xFFE4E9F2)],
                    ),
                  ),
            child: _Card(
              markdown: markdown,
              sheet: sheet,
              streaming: streaming,
              isStreaming: isStreaming,
              height: height,
              bare: bare,
            ),
          ),
        ),
      ),
    );
  }
}

/// The card, drawn as a small window so the image reads as a piece of an app
/// rather than as a slab of text.
class _Card extends StatelessWidget {
  const _Card({
    required this.markdown,
    required this.sheet,
    required this.streaming,
    required this.isStreaming,
    required this.height,
    this.bare = false,
  });

  final String markdown;
  final GptMarkdownStyleSheet Function(ColorScheme colors) sheet;
  final bool streaming;
  final bool isStreaming;
  final double? height;
  final bool bare;

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
          borderRadius: BorderRadius.circular(bare ? 0 : 16),
          border: bare ? null : Border.all(color: const Color(0xFFE3E7EE)),
          // No shadow: the test renderer draws a blurred shadow as a hard
          // slab, so the border alone separates card from page.
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(bare ? 0 : 15),
          child: Theme(
            data: theme,
            child: Builder(
              builder: (context) => Material(
                color: theme.colorScheme.surface,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!bare) const _TitleBar(),
                    Container(
                      height: height,
                      alignment: Alignment.topLeft,
                      padding: bare
                          ? const EdgeInsets.all(24)
                          : const EdgeInsets.fromLTRB(22, 16, 22, 22),
                      child: GptMarkdown(
                        markdown,
                        inlinePatterns: _showcasePatterns(context),
                        inlineDirectives: _showcaseDirectives(context),
                        styleSheet: sheet(theme.colorScheme),
                        animation: streaming
                            ? GptMarkdownAnimation.fade
                            : GptMarkdownAnimation.none,
                        isStreaming: isStreaming,
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
