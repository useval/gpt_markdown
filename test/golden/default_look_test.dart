import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

/// Locks the default appearance.
///
/// **These run on Linux only.** Text rasterisation is not identical across
/// platforms, so a golden captured on macOS fails on CI and vice versa —
/// not because anything changed, but because the pixels are produced by a
/// different renderer.
///
/// A tolerance was tried and rejected: any threshold loose enough to absorb
/// cross-platform antialiasing also hides real changes. Widening the
/// blockquote bar from 3 to 9 points passed at a 0.5% tolerance, which defeats
/// the point of having goldens at all.
///
/// So they are pinned to one platform, the one CI uses. Regenerate with
/// `scripts/goldens.sh`, which runs them in the CI image.
///
/// Customization work must not change how anything looks out of the box. These
/// goldens are captured before a refactor and must still pass after it without
/// `--update-goldens`. If one fails, a default moved.
const _cases = <String, String>{
  'blockquote':
      '> A quoted line with `code`, **bold** and a\n'
      '> [link](https://example.com) inside it.\n\n'
      'Text after the quote.',
  'lists': '- first item\n- second item\n\n1. one\n2. two',
  'checkbox': '- [x] done already\n- [ ] still to do',
  'headings': '# Heading one\n\n## Heading two\n\nBody text.',
  'table': '| A | B |\n|---|---|\n| 1 | 2 |',
  'code_block': '```dart\nvar x = 1;\n```',
  'inline':
      'Text with `code`, **bold**, *italic* and '
      '[a link](https://example.com).',
  'rule': 'above\n\n---\n\nbelow',
};

/// Loads the monospace font this package already ships.
///
/// Goldens must render identically on every machine, so the font cannot come
/// from a path on the developer's disk — an earlier version of this file read
/// Roboto out of the local Flutter SDK, which silently fell back to the test
/// font on CI and failed every golden.
///
/// The bundled font is read by a path relative to the package root, which is
/// the working directory `flutter test` runs in.
Future<void> _loadFonts() async {
  final file = File('lib/fonts/JetBrainsMono-Regular.ttf');
  if (!file.existsSync()) {
    return;
  }
  final loader = FontLoader('JetBrainsMono')
    ..addFont(file.readAsBytes().then(ByteData.sublistView));
  await loader.load();
}

void main() {
  setUpAll(_loadFonts);

  // Skipped off Linux rather than failing: a developer on macOS should still
  // be able to run the whole suite.
  // `testWidgets` takes a bool, so the reason lives here: goldens are
  // generated on Linux and only compared there.
  //
  // GPT_MARKDOWN_SKIP_GOLDENS opts out on a machine that is Linux but is not
  // running the SDK the goldens were generated with. The beta-channel job in
  // score.yml is the case that matters: it exists to surface new lints and
  // deprecations early, and a wall of golden failures caused by engine
  // rasterisation drift buries exactly the signal it was added to find.
  final skipGoldens =
      !Platform.isLinux ||
      Platform.environment.containsKey('GPT_MARKDOWN_SKIP_GOLDENS');

  for (final entry in _cases.entries) {
    for (final brightness in Brightness.values) {
      testWidgets('${entry.key} ${brightness.name}', (tester) async {
        tester.view.physicalSize = const Size(420, 460);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(
              useMaterial3: true,
              brightness: brightness,
              fontFamily: 'JetBrainsMono',
              extensions: [GptMarkdownThemeData(brightness: brightness)],
            ),
            home: Scaffold(
              body: Padding(
                padding: const EdgeInsets.all(12),
                child: GptMarkdown(entry.value),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        while (tester.takeException() != null) {}

        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('defaults/${entry.key}_${brightness.name}.png'),
        );
      }, skip: skipGoldens);
    }
  }
}
