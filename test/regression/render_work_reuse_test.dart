import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

void main() {
  testWidgets('nested quotes build each inline element once at every depth', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    final context = tester.element(find.byType(SizedBox).first);
    for (final depth in [0, 1, 4, 8, 12]) {
      var calls = 0;
      final config = GptMarkdownConfig(
        inlineCodeBuilder: (_, code, style, _) {
          calls++;
          return TextSpan(text: code, style: style);
        },
      );
      final spans = PlusparseRenderer.render(
        context,
        '${'> ' * depth}`one`',
        config,
      );
      expect(calls, 1, reason: 'depth $depth must not duplicate rendering');
      expect(countRevealCharacters(spans), 3);
      applyReveal(
        spans: spans,
        revealed: 2,
        effect: GptMarkdownAnimation.fade,
        progressFor: (_) => 0.5,
        defaultColor: Colors.black,
      );
      expect(calls, 1, reason: 'reveal must reuse styled content');
    }
  });

  testWidgets('heading reveal counts and reuses the actual custom content', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    var calls = 0;
    final spans = PlusparseRenderer.render(
      tester.element(find.byType(SizedBox).first),
      '# `short`',
      GptMarkdownConfig(
        inlineCodeBuilder: (_, _, _, _) {
          calls++;
          return const TextSpan(text: 'expanded content');
        },
      ),
    );
    expect(calls, 1);
    expect(countRevealCharacters(spans), 'expanded content'.length);
    applyReveal(
      spans: spans,
      revealed: 3,
      effect: GptMarkdownAnimation.fade,
      progressFor: (_) => 0.5,
      defaultColor: Colors.black,
    );
    expect(calls, 1);
  });

  testWidgets('hidden source is rendered once across reveal ticks', (
    tester,
  ) async {
    var hiddenBuilds = 0;
    InlineSpan codeBuilder(
      BuildContext context,
      String code,
      TextStyle style,
      InlineCodeStyle codeStyle,
    ) {
      if (code == 'hidden') hiddenBuilds++;
      return TextSpan(text: code, style: style);
    }

    Widget view(String text) => MaterialApp(
      home: Scaffold(
        body: GptMarkdown(
          text,
          animation: GptMarkdownAnimation.fade,
          charactersPerSecond: 10,
          isStreaming: true,
          inlineCodeBuilder: codeBuilder,
        ),
      ),
    );
    await tester.pumpWidget(view('start'));
    await tester.pumpWidget(view('start\n\n${'slow words ' * 20}\n\n`hidden`'));
    expect(hiddenBuilds, 1);
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(hiddenBuilds, 1);
    await tester.pumpWidget(view('replacement'));
    await tester.pumpWidget(view('replacement\n\n`hidden`'));
    expect(hiddenBuilds, 2, reason: 'removed source must be evicted');
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('ticks within a segment do not rebuild the document column', (
    tester,
  ) async {
    Widget view(String source) => MaterialApp(
      home: GptMarkdown(
        source,
        animation: GptMarkdownAnimation.fade,
        isStreaming: true,
        charactersPerSecond: 50,
      ),
    );
    await tester.pumpWidget(view('start'));
    await tester.pumpWidget(view('start\n\n${'long paragraph ' * 30}'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    final root =
        find
            .descendant(
              of: find.byType(GptMarkdown),
              matching: find.byType(Column),
            )
            .first;
    final before = tester.widget(root);
    await tester.pump(const Duration(milliseconds: 16));
    expect(identical(before, tester.widget(root)), isTrue);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('identical tables have independent scrolling ownership', (
    tester,
  ) async {
    const table = '| A | B |\n|---|---|\n| one | two |';
    await tester.pumpWidget(
      const MaterialApp(home: GptMarkdown('$table\n\n$table')),
    );
    // Found through the scroll views, not through `Scrollbar`: a table only
    // draws a bar on pointer platforms, and the ownership this guards is the
    // controller, which exists either way.
    final views =
        tester
            .widgetList<SingleChildScrollView>(
              find.ancestor(
                of: find.byType(Table),
                matching: find.byType(SingleChildScrollView),
              ),
            )
            .toList();
    expect(views, hasLength(2));
    expect(identical(views[0].controller, views[1].controller), isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('identical formulas can be mounted together', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: GptMarkdown(
          r'\[x^2\]'
          '\n\n'
          r'\[x^2\]',
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
