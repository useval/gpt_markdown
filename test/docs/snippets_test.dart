// ignore_for_file: deprecated_member_use_from_same_package

/// Compiles representative code from `README.md`, `docs/` and examples.
///
/// Documentation rots silently: a renamed parameter or a changed builder
/// signature leaves the guide wrong with nothing to catch it. This file is the
/// guard for the public constructor, style and builder signatures.
///
/// It is a compile-time check. The test body only has to exist.
library;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

const documentedCharacterAnimations = <GptMarkdownAnimation>[
  GptMarkdownAnimation.none,
  GptMarkdownAnimation.typewriter,
  GptMarkdownAnimation.fade,
  GptMarkdownAnimation.blurIn,
  GptMarkdownAnimation.wave,
];

const documentedBlockAnimations = <GptMarkdownBlockAnimation>[
  GptMarkdownBlockAnimation.none,
  GptMarkdownBlockAnimation.fadeIn,
  GptMarkdownBlockAnimation.growIn,
  GptMarkdownBlockAnimation.slideUp,
  GptMarkdownBlockAnimation.scaleIn,
];

class ShoutMd extends InlineMd {
  @override
  RegExp get exp => RegExp(r'!![A-Za-z]+!!');

  @override
  Set<MarkdownScope> get scopes => MarkdownComponent.allScopesExceptLinkLabel;

  @override
  InlineSpan span(BuildContext context, String text, GptMarkdownConfig config) {
    return TextSpan(
      text: text.replaceAll('!!', '').toUpperCase(),
      style: config.style?.copyWith(fontWeight: FontWeight.bold),
    );
  }
}

Widget docsCompile(BuildContext context) {
  return GptMarkdown(
    'text',
    incremental: true,
    animation: GptMarkdownAnimation.fade,
    blockAnimation: GptMarkdownBlockAnimation.slideUp,
    isStreaming: true,
    charactersPerSecond: 300,
    revealFadeSeconds: 0.25,
    blockAnimationDuration: const Duration(milliseconds: 200),
    blockAnimationCurve: Curves.easeOut,
    autolink: true,
    autolinkSchemes: const {'myapp'},
    useDollarSignsForLatex: true,
    textAlign: TextAlign.start,
    textScaler: TextScaler.noScaling,
    maxLines: 20,
    overflow: TextOverflow.ellipsis,
    followLinkColor: false,
    latexWorkaround: (tex) => tex,
    onLinkTap: (url, title) {},
    onImageTap: (url) {},
    onCodeCopy: (code) {},
    onSourceTagTap: (content) {},
    onCheckboxChanged: (value) {},
    inlineComponents: [ShoutMd(), ...MarkdownComponent.inlineComponents],
    inlineDirectives: [
      InlineDirective(
        open: '\u{E200}widget\u{E202}',
        close: '\u{E201}',
        builder:
            (context, payload, style) => TextSpan(text: payload, style: style),
      ),
    ],
    styleSheet: const GptMarkdownStyleSheet(
      heading: HeadingStyle(textStyle: TextStyle(letterSpacing: -0.5)),
      link: LinkStyle(decoration: TextDecoration.none),
      inlineCode: InlineCodeStyle(fontFamily: 'GeistMono'),
      checkbox: CheckboxStyle(interactive: true),
      blockQuote: BlockQuoteStyle(barWidth: 4),
      codeBlock: CodeBlockStyle(
        showCopyButton: false,
        borderRadius: Radius.circular(12),
      ),
      list: ListStyle(bulletSize: 5),
      table: TableStyle(cellPadding: EdgeInsets.all(8)),
      image: ImageStyle(borderRadius: Radius.circular(6)),
      hr: HrStyle(thickness: 2),
      sourceTag: SourceTagStyle(size: 18),
      latex: LatexStyle(scrollBlockHorizontally: true),
    ),
    inlinePatterns: [
      InlinePattern(
        pattern: RegExp(r'(?<![\w-])GH-(\d+)\b'),
        scopes: MarkdownComponent.allScopes,
        builder:
            (context, match, style) => TextSpan(
              text: match.group(0),
              style: style.copyWith(fontWeight: FontWeight.w600),
              recognizer: TapGestureRecognizer()..onTap = () {},
            ),
      ),
      InlinePattern.prefixed(
        prefix: '#',
        knownNames: const ['general'],
        builder:
            (context, match, style) => WidgetSpan(
              alignment: PlaceholderAlignment.baseline,
              baseline: TextBaseline.alphabetic,
              child: Text(match.group(0) ?? ''),
            ),
      ),
    ],
    headingBuilder: (context, level, content, style) => content,
    blockQuoteBuilder: (context, content, style) => content,
    checkboxBuilder: (context, checked, content, style) => content,
    radioOptionBuilder: (context, selected, content, style) => content,
    hrBuilder: (context, style) => const SizedBox(),
    codeBuilder: (context, name, code, closed) => Text(code),
    imageBuilder: (context, url, width, height) => const SizedBox(),
    latexBuilder: (context, tex, style, inline) => Text(tex),
    linkBuilder: (context, label, url, style) => const SizedBox(),
    sourceTagBuilder: (context, content, style) => Text(content),
    inlineLinkBuilder: (link) => link.defaultSpan(),
    inlineSourceTagBuilder: (tag) => tag.defaultSpan(),
    orderedListBuilder: (context, no, child, config) => child,
    unOrderedListBuilder: (context, child, config) => child,
    inlineCodeBuilder:
        (context, code, style, codeStyle) => CodeTextSpan(
          text: code,
          style: style,
          codeStyle: codeStyle.copyWith(backgroundColor: Colors.amber),
        ),
  );
}

Widget themeCompile() {
  return MaterialApp(
    theme: ThemeData(
      extensions: [
        GptMarkdownThemeData(
          brightness: Brightness.light,
          styleSheet: const GptMarkdownStyleSheet(
            blockQuote: BlockQuoteStyle(barColor: Colors.indigo),
          ),
        ),
      ],
    ),
    home: const SizedBox(),
  );
}

InlineSpan widgetSpanCompile() => baselineWidgetSpan(const Text('chip'));

int splitCompile() => settledSplitOffset('a\n\nb\n\nc');

/// A block component, from `docs/custom-components.md`.
class CalloutMd extends BlockMd {
  @override
  String get expString => r':::(\w+)\n([\s\S]*?)\n:::';

  @override
  Widget build(BuildContext context, String text, GptMarkdownConfig config) {
    final match = exp.firstMatch(text);
    final kind = match?.group(1) ?? 'note';
    final body = match?.group(2) ?? '';
    return Row(
      children: [
        Icon(kind == 'warning' ? Icons.warning : Icons.info),
        Flexible(child: GptMarkdown(body, style: config.style)),
      ],
    );
  }
}

/// The plain-text helper documented in `docs/testing.md`.
String plainTextSnippet(WidgetTester tester) {
  final buffer = StringBuffer();
  for (final rt in tester.widgetList<RichText>(
    find.byWidgetPredicate((w) => w is RichText),
  )) {
    buffer.write(rt.text.toPlainText(includePlaceholders: false));
  }
  return buffer.toString();
}

/// Builder snippets that reuse the resolved style, from
/// `docs/customization.md`.
Widget builderSnippets() {
  return GptMarkdown(
    'text',
    blockQuoteBuilder:
        (context, content, style) => DecoratedBox(
          decoration: BoxDecoration(
            border: BorderDirectional(
              start: BorderSide(
                color: style.barColor ?? Colors.grey,
                width: style.barWidth ?? 3,
              ),
            ),
          ),
          child: content,
        ),
    headingBuilder:
        (context, level, content, style) => Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Flexible(child: content),
            IconButton(icon: const Icon(Icons.link), onPressed: () {}),
          ],
        ),
    codeBuilder:
        (context, name, code, closed) => Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          child: SelectableText(
            code,
            style: const TextStyle(fontFamily: 'monospace'),
          ),
        ),
    inlineCodeBuilder:
        (context, code, style, codeStyle) =>
            baselineWidgetSpan(Text(code, style: style)),
  );
}

/// The link-validation snippet from `docs/getting-started.md`.
void safeLinkTap(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null) {
    return;
  }
  if (uri.scheme != 'https' && uri.scheme != 'mailto') {
    return;
  }
}

/// Scope snippets from `docs/inline-syntax.md`.
List<InlinePattern> scopedPatterns() {
  return [
    InlinePattern(
      pattern: RegExp(r'GH-\d+'),
      builder: (context, match, style) => TextSpan(text: match.group(0)),
      scopes: MarkdownComponent.allScopes,
    ),
    InlinePattern(
      pattern: RegExp(r'@[a-z]+'),
      builder: (context, match, style) => TextSpan(text: match.group(0)),
      scopes: const {MarkdownScope.content},
    ),
  ];
}

/// The delimited-token snippets from `docs/inline-syntax.md`.
const _emoji = {'tada': '🎉', 'rocket': '🚀', 'fire': '🔥'};
const _iconTable = {'bug': Icons.bug_report, 'ship': Icons.rocket_launch};

List<InlinePattern> delimitedPatterns() {
  return [
    InlinePattern.delimited(
      open: ':',
      knownNames: _emoji.keys,
      builder: (context, match, style) {
        final name = match.namedGroup('name');
        final glyph = name == null ? null : _emoji[name];
        if (glyph == null) {
          return TextSpan(text: match.group(0), style: style);
        }
        return TextSpan(text: glyph, style: style);
      },
    ),
    InlinePattern.delimited(
      open: ':',
      knownNames: _iconTable.keys,
      builder: (context, match, style) {
        final name = match.namedGroup('name');
        final icon = name == null ? null : _iconTable[name];
        if (icon == null) {
          return TextSpan(text: match.group(0), style: style);
        }
        return WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Icon(icon, size: (style.fontSize ?? 14) * 1.15),
        );
      },
    ),
    InlinePattern.delimited(
      open: '{{',
      close: '}}',
      knownNames: const ['token'],
      builder: (context, match, style) => TextSpan(text: match.group(0)),
    ),
  ];
}

/// The streaming widget from `docs/streaming.md`.
class ReplyView extends StatefulWidget {
  const ReplyView({super.key, required this.stream});

  final Stream<String> stream;

  @override
  State<ReplyView> createState() => _ReplyViewState();
}

class _ReplyViewState extends State<ReplyView> {
  final _buffer = StringBuffer();
  bool _generating = true;

  @override
  void initState() {
    super.initState();
    widget.stream.listen(
      (chunk) => setState(() => _buffer.write(chunk)),
      onDone: () => setState(() => _generating = false),
    );
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: GptMarkdown(
      _buffer.toString(),
      animation: GptMarkdownAnimation.fade,
      isStreaming: _generating,
    ),
  );
}

/// The getting-started widget from `example/example.md`.
class AnswerView extends StatelessWidget {
  const AnswerView({super.key, required this.reply});

  final String reply;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: GptMarkdown(reply, onLinkTap: (url, title) {}),
    );
  }
}

/// The theme-extension snippet from `example/example.md`.
Widget exampleTheme(BuildContext context) {
  return MaterialApp(
    theme: ThemeData(
      useMaterial3: true,
      extensions: [
        GptMarkdownThemeData(
          brightness: Brightness.light,
          h1: Theme.of(context).textTheme.headlineMedium,
          styleSheet: const GptMarkdownStyleSheet(
            link: LinkStyle(decoration: TextDecoration.none),
            table: TableStyle(cellPadding: EdgeInsets.all(10)),
            latex: LatexStyle(scrollBlockHorizontally: true),
          ),
        ),
      ],
    ),
    darkTheme: ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      extensions: [GptMarkdownThemeData(brightness: Brightness.dark)],
    ),
    home: const SizedBox(),
  );
}

/// The remaining one-liners from `example/example.md`.
List<Widget> exampleOddsAndEnds() {
  const reply = 'text';
  return [
    GptMarkdown(
      reply,
      onImageTap: (url) {},
      onCodeCopy: (code) {},
      onSourceTagTap: (content) {},
    ),
    const SelectionArea(child: GptMarkdown(reply)),
    const GptMarkdown(reply, textDirection: TextDirection.rtl),
    const GptMarkdown(reply, useDollarSignsForLatex: true),
    const GptMarkdown(reply, autolink: false),
    const GptMarkdown(
      reply,
      animation: GptMarkdownAnimation.fade,
      isStreaming: true,
    ),
  ];
}

/// The table builder from the README.
Widget exampleTableBuilder() {
  return GptMarkdown(
    'text',
    tableBuilder:
        (context, tableRows, textStyle, config) => Table(
          border: TableBorder.all(color: Colors.grey),
          children:
              tableRows
                  .map(
                    (row) => TableRow(
                      decoration:
                          row.isHeader
                              ? const BoxDecoration(color: Color(0xFFEEEEEE))
                              : null,
                      children:
                          row.fields
                              .map(
                                (cell) => Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: Text(
                                    cell.data,
                                    textAlign: cell.alignment,
                                  ),
                                ),
                              )
                              .toList(),
                    ),
                  )
                  .toList(),
        ),
  );
}

/// The snippets on the README front page.
List<Widget> readmeSnippets(String reply, StringBuffer buffer) {
  return [
    GptMarkdown(reply, animation: GptMarkdownAnimation.fade, isStreaming: true),
    SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: GptMarkdown(reply, onLinkTap: (url, title) {}),
    ),
    GptMarkdown(
      reply,
      styleSheet: const GptMarkdownStyleSheet(
        inlineCode: InlineCodeStyle(fontFamily: 'GeistMono'),
        blockQuote: BlockQuoteStyle(barWidth: 4, barColor: Colors.indigo),
      ),
      blockQuoteBuilder: (context, content, style) => Card(child: content),
    ),
    GptMarkdown(
      buffer.toString(),
      animation: GptMarkdownAnimation.fade,
      isStreaming: true,
    ),
  ];
}

/// The style-sheet fragment shown on its own in the README.
const readmeStyleSheet = GptMarkdownStyleSheet(
  codeBlock: CodeBlockStyle(borderRadius: Radius.circular(12)),
);

void main() {
  test('every snippet in docs/ compiles', () {
    // Referencing them keeps the analyzer honest about unused declarations.
    expect(docsCompile, isNotNull);
    expect(themeCompile, isNotNull);
    expect(widgetSpanCompile(), isA<InlineSpan>());
    expect(splitCompile(), isA<int>());
    expect(ShoutMd().exp, isA<RegExp>());
    expect(CalloutMd().expString, isA<String>());
    expect(builderSnippets, isNotNull);
    expect(scopedPatterns(), hasLength(2));
    expect(delimitedPatterns(), hasLength(3));
    expect(plainTextSnippet, isNotNull);
    expect(() => safeLinkTap('https://example.com'), returnsNormally);
    expect(ReplyView, isNotNull);
    expect(AnswerView, isNotNull);
    expect(exampleTheme, isNotNull);
    expect(exampleOddsAndEnds(), hasLength(6));
    expect(exampleTableBuilder(), isA<Widget>());
    expect(readmeSnippets('text', StringBuffer()), hasLength(4));
    expect(readmeStyleSheet.codeBlock, isNotNull);
  });
}
