# Testing

Things that bite when writing widget tests against rendered Markdown.

---

## `find.text` rarely works

Markdown renders as spans inside one paragraph, not as separate `Text` widgets,
so `find.text` has two ways to miss. It compares the string against a `Text`
widget's whole text — its `data`, or the plain text of its span when the widget
was built from one — so a fragment of a paragraph never matches. And a
paragraph carrying a link or inline code is not a `Text` at all (see the next
section), so no string finds it.

```dart
// GptMarkdown('**hello** world')
// Fails: the paragraph's whole text is "hello world"
expect(find.text('hello'), findsOneWidget);
```

Read the text out of the spans instead:

```dart
String plainText(WidgetTester tester) {
  final buffer = StringBuffer();
  for (final rt in tester.widgetList<RichText>(
    find.byWidgetPredicate((w) => w is RichText),
  )) {
    buffer.write(rt.text.toPlainText(includePlaceholders: false));
  }
  return buffer.toString();
}

expect(plainText(tester), contains('hello'));
```

> [!TIP]
> `find.text` **does** work for content that renders as its own widget — a chip
> from a custom component, a code block, a table cell — because each is a `Text`
> of its own, so the string you pass is its whole text.

---

## `find.byType(RichText)` misses paragraphs

Paragraphs carrying a link or inline code, or needing right-to-left placeholder
reordering, render through `BidiRichText` — a `RichText` **subclass**.
`find.byType` matches exact runtime types. A link puts a paragraph on that path
too: its tap target is resolved by the paragraph's render object, not by a
widget of its own.

```dart
// Misses them
find.byType(RichText)

// Finds them
find.byWidgetPredicate((widget) => widget is RichText)
```

> [!WARNING]
> This one is nasty because it fails *selectively*. A test passes on plain
> prose and fails the moment someone adds a link — or `` `code` `` — to the
> fixture.

---

## Changing a builder at runtime does nothing

`GptMarkdownConfig.isSame` decides whether spans are regenerated, and it cannot
compare closures — any consumer writing them inline creates a new one every
build, so comparing them would defeat the cache entirely.

```dart
// This will not take effect
await tester.pumpWidget(app(codeBuilder: builderA));
await tester.pumpWidget(app(codeBuilder: builderB));   // still builderA
```

Give the widget a key that changes with it:

```dart
GptMarkdown(text, key: ValueKey(builderId), codeBuilder: builder)
```

Styles, patterns and component lists **are** compared and do update live.

---

## Overflow warnings are expected at raised text scales

Block maths cannot wrap, and does not scroll sideways unless
`LatexStyle.scrollBlockHorizontally` is set. At 2× or 3× on a phone-width
surface a wide formula reports `A RenderLine overflowed`, failing any assertion
that `tester.takeException()` is null.

Code blocks and tables are not what to suspect: both sit in a horizontal
`SingleChildScrollView`, so they scroll and clip rather than report anything. A
long heading wraps like any other paragraph, and paragraph overflow is painted
rather than raised as an error, so it never reaches `takeException()` at all.

Drain it deliberately rather than widening the surface until it hides:

```dart
await tester.pumpAndSettle();
while (tester.takeException() != null) {}
```

> [!TIP]
> Do not silence it globally. Drain it in the tests where the overflow is
> expected, so a *new* overflow somewhere else still fails.

---

## Height ratios are not scale ratios

At a raised text scale a paragraph gets **more lines**, so its height can grow
5× while every line is exactly 2× taller.

```dart
// Wrong conclusion: "text scaling is broken, it grew 5x"
final ratio = heightAt2x / heightAt1x;
expect(ratio, closeTo(2.0, 0.1));   // fails for reasons that are not a bug
```

Measure at a width where nothing rewraps:

```dart
SizedBox(width: 4000, child: GptMarkdown(sample))
```

Or compare line height rather than total height, via
`RenderParagraph.getBoxesForSelection`.

---

## Streaming needs pumping, not settling

`pumpAndSettle` waits for animations to finish. A reveal does finish — but only
after the whole reply is revealed, which may be seconds of simulated time.

```dart
// One frame of the reveal
await tester.pump(const Duration(milliseconds: 16));

// Let it run to completion
await tester.pumpAndSettle(const Duration(seconds: 5));
```

For tests that are not about streaming, skip the animation entirely:

```dart
GptMarkdown(text, animation: GptMarkdownAnimation.none)
// or
GptMarkdown(text, animation: GptMarkdownAnimation.fade, isStreaming: false)
```

### Test the lifecycle, not only one frame

A useful streaming test covers append, completion and replacement:

```dart
await tester.pumpWidget(app(text: 'Hello', streaming: true));
await tester.pumpWidget(app(text: 'Hello world', streaming: true));
await tester.pump(const Duration(milliseconds: 100));

// Completion fast-forwards whatever remains.
await tester.pumpWidget(app(text: 'Hello world', streaming: false));
await tester.pumpAndSettle();

// A replacement is a regenerate, not an append.
await tester.pumpWidget(app(text: 'Different answer', streaming: true));
await tester.pump(const Duration(milliseconds: 16));
```

Test reduced motion separately by wrapping the widget in a `MediaQuery` whose
`disableAnimations` is true. The complete text should render without waiting
for a ticker.

### Assert semantics after the text goes quiet

While the source is still growing by append, or a reveal is in flight, the
whole document collapses to one container node and everything beneath it is
excluded. A mid-stream `getSemantics` on a heading, a link or a list item finds
no such node. The structure comes back 250 ms after the last chunk.

```dart
await tester.pumpWidget(app(text: 'See [the'));
await tester.pumpWidget(app(text: 'See [the docs](https://example.com)'));
await tester.pump();
// One node, no link — a semantics assertion here fails for the wrong reason.

// Going quiet is a timer. With no animation running there is no frame for
// pumpAndSettle to wait on, so pump the delay explicitly.
await tester.pump(const Duration(milliseconds: 300));
```

Turning `isStreaming` off does not open the tree either: the gate is growth the
widget observed, precisely because that flag defaults to true and hosts
routinely leave it on. The reply so far is still readable as the container's
label, but only where `MediaQuery.accessibleNavigationOf` is true, so a test
asserting on that label has to set `accessibleNavigation` itself.

### Check both parser paths when extending grammar

`incremental` is deprecated in 1.3.0 — deleting it from application code is the
migration. It stays useful in *tests*, which is why this recipe keeps it: it is
the only way to drive both parsers over the same source. Expect a deprecation
warning, and silence it with
`// ignore: deprecated_member_use_from_same_package`.

`incremental: true` is the default plusparse path; `false` selects the legacy
renderer unless an animation forces span reveal. Parser or Markdown-syntax
changes should have parity coverage:

```dart
for (final incremental in [false, true]) {
  await tester.pumpWidget(
    MaterialApp(
      home: GptMarkdown(source, incremental: incremental),
    ),
  );
  // Assert the same visible result for each path.
}
```

Custom `components` and `inlineComponents` intentionally use the legacy path,
so test them there rather than assuming `incremental: true` exercises
plusparse.

### Test block entrances independently

Character and block animations are separate. For a table, fence or block
maths, set a non-`none` character animation and the block entrance under test,
then pump part of `blockAnimationDuration`. Only `growIn` should change layout
height; `fadeIn`, `slideUp` and `scaleIn` reserve the final space immediately.

### Test code-copy feedback

Mock `SystemChannels.platform` before tapping the built-in copy button. Assert
that the copy icon changes to a check, that a second tap inside that window
writes nothing further, and that the icon returns after two seconds.

Do not assert that the button is disabled meanwhile — it deliberately stays
enabled. Wrapping it in `IgnorePointer` or `AbsorbPointer` did not stop the tap
reaching an ancestor, because an ancestor is already on the hit-test path; it
only stopped the button claiming the gesture, so the second tap fell through to
whatever wraps the code block, a tap-to-collapse in a chat UI. The
duplicate-clipboard guard lives in `_copyCode` instead, so what is worth
asserting is that `InkWell.onTap` stays non-null through the check-mark window
and that the second tap reaches no surrounding handler.

---

## Testing a style

Assert on the widget the style feeds, not on pixels:

```dart
testWidgets('the bar follows the theme', (tester) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(
        extensions: [
          GptMarkdownThemeData(
            brightness: Brightness.light,
            styleSheet: const GptMarkdownStyleSheet(
              blockQuote: BlockQuoteStyle(barWidth: 7),
            ),
          ),
        ],
      ),
      home: const Scaffold(body: GptMarkdown('> quoted')),
    ),
  );
  await tester.pumpAndSettle();

  final quote = tester.widget<BlockQuoteWidget>(
    find.byType(BlockQuoteWidget),
  );
  expect(quote.width, 7);
});
```

Also assert the **merge**, because per-object override is the easy mistake:
set one field on the widget and a different one on the theme, then check both
survived.

---

## Golden tests

The package's defaults are locked by goldens in
`test/golden/default_look_test.dart` — eight constructs in light and dark.

> [!IMPORTANT]
> **They run on Linux only**, and are skipped everywhere else.
>
> Text rasterisation is not identical across platforms, so a golden captured on
> macOS fails on CI for reasons that are not a change. Pinning to one platform
> is the only way the comparison means anything.

A tolerance was tried and rejected. Any threshold loose enough to absorb
cross-platform antialiasing also hides real changes — widening the blockquote
bar from 3 to 9 points passed at a 0.5% tolerance, which defeats the point.

To regenerate after an intended change, dispatch the workflow against your
branch. It regenerates on Linux and commits the images back, so a maintainer
on macOS or Windows never has to produce them by hand:

```bash
gh workflow run goldens.yml --ref my-branch
gh run watch
git pull
```

Pass `-f commit=false` to get the images as an artifact and commit them
yourself. On Linux, `./scripts/goldens.sh` does the whole thing locally.

> [!WARNING]
> Regenerating is not a fix for a failing golden — it is how you record a
> change you meant to make. `--update-goldens` overwrites the reference with
> whatever the code now draws, so running it on a red build makes the
> regression the new baseline. Look at the diff images first.
>
> This is why the workflow is manual. If it ran on every push the goldens would
> always match and the test could never fail.

If a golden fails on CI, download the `golden-failures` artifact from the run —
it contains the expected, actual and diff images, which is the only readable
way to see what moved.

## README screenshots

`./scripts/screenshots.sh` regenerates the showcase images in `screenshots/`
from `tool/screenshots/`. One dark card per capability, laid out as a grid in
the README. They render through the test harness because that is
the supported way to rasterise a widget to a file without opening a window.

Unlike goldens, nothing compares them — they are documentation, so any machine
can regenerate them. `flutter test` only looks in `test/`, so they never run on
CI and never gate a build.

> [!IMPORTANT]
> After regenerating, **bump the `?v=` on every image URL in `README.md`**.
> GitHub serves README images through a proxy that caches by URL, so without a
> new query string a reader keeps seeing the previous picture — for a long time,
> and with nothing to indicate it is stale. Commit and push the PNGs too: the
> URLs point at `main`, so an uncommitted image simply does not exist yet.

> [!NOTE]
> Two things in the images are harness artefacts, not defects in what a reader
> would see. Text that resolves to a null font family — the code block's copy
> button, for one — draws in the test font, whose glyphs are filled boxes, so
> that button is switched off for the screenshots. Fonts are otherwise loaded
> from paths resolved out of the SDK and `.dart_tool/package_config.json`, never
> hardcoded.

## Documentation snippets are compiled

Representative snippets from `docs/` live in
`test/docs/snippets_test.dart` and are compiled by the test suite. The file
covers public constructor options, style objects and builder signatures so an
API rename fails loudly. It is not an automatic Markdown code-fence extractor,
so prose, links and examples still need review.

Add to it when you document something new.
