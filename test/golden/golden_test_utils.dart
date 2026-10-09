import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

/// Declares two golden tests for [markdown] rendered by a default
/// [GptMarkdown]: `defaults/<name>_light.png` and `defaults/<name>_dark.png`,
/// next to the calling test file.
///
/// **Off unless asked for.** Text rasterisation differs between platforms, so
/// goldens only match on the machine that generated them — CI never runs
/// them. Run them with `just check --golden`; regenerate after an intended
/// change with `just update-goldens`, and review the images before
/// committing: a golden that changed is a default that moved.
void markdownGolden(
  String name,
  String markdown, {
  Size size = const Size(420, 460),
}) {
  for (final brightness in Brightness.values) {
    testWidgets('$name ${brightness.name}', (tester) async {
      await tester.runAsync(_loadFonts);
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            useMaterial3: true,
            brightness: brightness,
            fontFamily: 'JetBrainsMono',
            extensions: [GptMarkdownThemeData(brightness: brightness)],
          ),
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(12),
              child: GptMarkdown(markdown),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      while (tester.takeException() != null) {}

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('defaults/${name}_${brightness.name}.png'),
      );
    }, skip: !_goldensEnabled);
  }
}

/// Set by `just check --golden` and `just update-goldens`.
final _goldensEnabled = Platform.environment.containsKey(
  'GPT_MARKDOWN_GOLDENS',
);

bool _fontsLoaded = false;

/// Loads the monospace font this package ships, by a path relative to the
/// package root (the directory `flutter test` runs in), never from somewhere
/// on the developer's disk. Registered under both names it is looked up by:
/// the theme's plain family and the code block's package-qualified one.
Future<void> _loadFonts() async {
  if (_fontsLoaded) return;
  _fontsLoaded = true;
  final bytes = File('lib/fonts/JetBrainsMono-Regular.ttf').readAsBytes();
  for (final family in const [
    'JetBrainsMono',
    'packages/gpt_markdown/JetBrainsMono',
  ]) {
    await (FontLoader(
      family,
    )..addFont(bytes.then(ByteData.sublistView))).load();
  }
}
