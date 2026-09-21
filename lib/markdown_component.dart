// This file defines the legacy regex pipeline's component types and its
// built-in components. They are deprecated as a group, and they refer to one
// another throughout, so the ignore is applied once for the whole file.
// ignore_for_file: deprecated_member_use_from_same_package
part of 'gpt_markdown.dart';

/// The nesting context a [MarkdownComponent] is being rendered in.
///
/// Markdown nests: a link label may contain bold text, a table cell may
/// contain a link, a heading may contain inline code. A component declares the
/// contexts it is meaningful in through [MarkdownComponent.scopes] and is
/// skipped everywhere else.
///
/// This is what stops, for example, an app-specific `#channel` chip from also
/// rendering *inside* `[#channel](url)`. That produced a [WidgetSpan] nested
/// in the link's own [WidgetSpan], which does not paint on iOS.
enum MarkdownScope {
  /// Ordinary document or inline content. The default.
  content,

  /// Inside the `label` half of a `[label](url)` link.
  linkLabel,

  /// Inside a table cell.
  tableCell,

  /// Inside a `#` heading.
  heading,
}

/// Markdown components
abstract class MarkdownComponent {
  /// Every scope — the default value of [scopes].
  ///
  /// Declared `const` so reading [scopes] allocates nothing; it is read once
  /// per component per [generate] call, and [generate] recurses.
  static const Set<MarkdownScope> allScopes = {
    MarkdownScope.content,
    MarkdownScope.linkLabel,
    MarkdownScope.tableCell,
    MarkdownScope.heading,
  };

  /// Every scope except [MarkdownScope.linkLabel].
  ///
  /// The right default for anything rendering a [WidgetSpan]: a placeholder
  /// nested inside the link's own placeholder does not paint on iOS.
  static const Set<MarkdownScope> allScopesExceptLinkLabel = {
    MarkdownScope.content,
    MarkdownScope.tableCell,
    MarkdownScope.heading,
  };

  /// The nesting contexts this component is allowed to render in.
  ///
  /// Defaults to [allScopes], so existing components keep their behaviour.
  /// Override it to opt out of a context — most commonly
  /// [allScopesExceptLinkLabel].
  Set<MarkdownScope> get scopes => allScopes;

  /// The built-in block components of the legacy regex pipeline.
  ///
  /// This list exists to be spread into a custom `components` list, and
  /// passing `components` selects the legacy pipeline: the document is
  /// rendered as one text tree, with no incremental segment cache, no
  /// span-level streaming reveal and no lazy sliver. A custom list also
  /// replaces the built-ins wholesale — every component left out of it stops
  /// rendering, which is why callers spread this list into their own.
  ///
  /// Register custom blocks with `blockComponents` instead, which keeps the
  /// modern pipeline.
  @Deprecated('Use blockComponents instead. Will be removed in 2.0.0.')
  static List<MarkdownComponent> get globalComponents => [
    CodeBlockMd(),
    LatexMathMultiLine(),
    NewLines(),
    BlockQuote(),
    TableMd(),
    HTag(),
    UnOrderedList(),
    OrderedList(),
    RadioButtonMd(),
    CheckBoxMd(),
    HrLine(),
    IndentMd(),
  ];

  /// The built-in inline components of the legacy regex pipeline.
  ///
  /// This list exists to be spread into a custom `inlineComponents` list, and
  /// passing `inlineComponents` selects the legacy pipeline: the document is
  /// rendered as one text tree, with no incremental segment cache, no
  /// span-level streaming reveal and no lazy sliver. A custom list also
  /// replaces the built-ins wholesale — every component left out of it stops
  /// rendering, which is why callers spread this list into their own.
  ///
  /// Register custom inline syntax with `inlinePatterns`, or with
  /// `inlineDirectives` for a delimited payload, instead; both keep the
  /// modern pipeline.
  @Deprecated('Use inlinePatterns instead. Will be removed in 2.0.0.')
  static final List<MarkdownComponent> inlineComponents = [
    InlineDirectiveMd(),
    ATagMd(),
    ImageMd(),
    AutolinkMd(),
    TableMd(),
    StrikeMd(),
    BoldMd(),
    ItalicMd(),
    UnderLineMd(),
    LatexMath(),
    LatexMathMultiLine(),
    HighlightedText(),
    SourceTag(),
  ];

  /// Compiled combined regexes, keyed by the joined pattern string.
  ///
  /// Building and compiling the combined pattern is the most expensive part of
  /// [generate], and [generate] recurses once per nested span. The joined
  /// pattern string fully determines the [RegExp], so it is the natural key.
  static final Map<String, RegExp> _combinedRegexCache = {};

  /// Upper bound on [_combinedRegexCache].
  ///
  /// Components may be built from runtime data (a channel list, an emoji
  /// palette), so the set of distinct patterns is not bounded by the package.
  /// The cache is dropped wholesale rather than grown without limit.
  static const int _combinedRegexCacheLimit = 64;
  static final Map<(String, bool, bool, bool), RegExp> _anchoredRegexCache = {};

  static RegExp _anchoredRegexFor(RegExp expression) {
    final key = (
      expression.pattern,
      expression.isMultiLine,
      expression.isDotAll,
      expression.isCaseSensitive,
    );
    final cached = _anchoredRegexCache[key];
    if (cached != null) return cached;
    if (_anchoredRegexCache.length >= _combinedRegexCacheLimit) {
      _anchoredRegexCache.clear();
    }
    return _anchoredRegexCache[key] = RegExp(
      '^(?:${expression.pattern})\$',
      multiLine: expression.isMultiLine,
      dotAll: expression.isDotAll,
      caseSensitive: expression.isCaseSensitive,
    );
  }

  static RegExp _combinedRegexFor(List<MarkdownComponent> components) {
    final pattern = components.map<String>((e) => e.exp.pattern).join("|");
    // The combined regex carries one set of flags for every alternative, so a
    // single case-insensitive component makes the whole alternation
    // case-insensitive. Without this its matches never reach the dispatch loop
    // at all — the combined regex simply does not find them.
    final caseSensitive = components.every((e) => e.exp.isCaseSensitive);
    final key = caseSensitive ? pattern : 'i:$pattern';
    final cached = _combinedRegexCache[key];
    if (cached != null) {
      return cached;
    }
    if (_combinedRegexCache.length >= _combinedRegexCacheLimit) {
      _combinedRegexCache.clear();
    }
    return _combinedRegexCache[key] = RegExp(
      pattern,
      multiLine: true,
      dotAll: true,
      caseSensitive: caseSensitive,
    );
  }

  /// Generate widget for markdown widget
  static List<InlineSpan> generate(
    BuildContext context,
    String text,
    final GptMarkdownConfig config,
    bool includeGlobalComponents,
  ) {
    var components =
        includeGlobalComponents
            ? config.components ?? MarkdownComponent.globalComponents
            : config.inlineComponents ?? MarkdownComponent.inlineComponents;

    // Consumer patterns are matched ahead of the built-ins, and only in the
    // inline pass. The global pass resolves block structure (headings, lists,
    // tables); everything it does not claim comes straight back here with
    // [includeGlobalComponents] false, so inline patterns still see all of it.
    final inlinePatterns = config.inlinePatterns;
    if (!includeGlobalComponents &&
        inlinePatterns != null &&
        inlinePatterns.isNotEmpty) {
      components = [...inlinePatterns.map(InlinePatternMd.new), ...components];
    }

    // Filter *before* the combined regex is built, not just in the dispatch
    // loop below. Filtering only the dispatch loop would leave the combined
    // regex claiming text that no component then handles.
    final scope = config.scope;
    components = components
        .where((e) => e.scopes.contains(scope))
        .toList(growable: false);

    List<InlineSpan> spans = [];
    if (components.isEmpty) {
      // An empty pattern matches everywhere and would consume the text.
      return [TextSpan(text: text, style: config.style)];
    }
    final combinedRegex = _combinedRegexFor(components);
    text.splitMapJoin(
      combinedRegex,
      onMatch: (p0) {
        String element = p0[0] ?? "";
        for (var each in components) {
          final exp = _anchoredRegexFor(each.exp);
          if (exp.hasMatch(element)) {
            spans.add(each.span(context, element, config));
            return "";
          }
        }
        // The combined regex matched but no single component claims the whole
        // match. Show the source text rather than dropping it silently.
        assert(() {
          debugPrint(
            'gpt_markdown: no component claimed "$element"; '
            'rendering it as plain text.',
          );
          return true;
        }());
        spans.add(TextSpan(text: element, style: config.style));
        return "";
      },
      onNonMatch: (p0) {
        if (p0.isEmpty) {
          return "";
        }
        if (includeGlobalComponents) {
          var newSpans = generate(context, p0, config.copyWith(), false);
          spans.addAll(newSpans);
          return "";
        }
        spans.add(TextSpan(text: p0, style: config.style));
        return "";
      },
    );

    return spans;
  }

  InlineSpan span(
    BuildContext context,
    String text,
    final GptMarkdownConfig config,
  );

  RegExp get exp;
  bool get inline;
}

/// Inline component of the legacy regex pipeline.
///
/// A subclass is reachable only through `inlineComponents`, which selects the
/// legacy pipeline: the document is rendered as one text tree, with no
/// incremental segment cache, no span-level streaming reveal and no lazy
/// sliver, so a streaming reply re-parses and re-lays-out the whole message on
/// every append. Use [InlinePattern] for host syntax that is still text, or
/// [InlineDirective] for a delimited payload the parser must not read; both
/// work on either pipeline.
///
/// Before:
///
/// ```dart
/// class ShoutMd extends InlineMd {
///   @override
///   RegExp get exp => RegExp(r'!![A-Za-z]+!!');
///
///   @override
///   InlineSpan span(
///     BuildContext context,
///     String text,
///     GptMarkdownConfig config,
///   ) {
///     return TextSpan(
///       text: text.replaceAll('!!', '').toUpperCase(),
///       style: config.style?.copyWith(fontWeight: FontWeight.bold),
///     );
///   }
/// }
///
/// GptMarkdown(
///   text,
///   inlineComponents: [ShoutMd(), ...MarkdownComponent.inlineComponents],
/// )
/// ```
///
/// After:
///
/// ```dart
/// GptMarkdown(
///   text,
///   inlinePatterns: [
///     InlinePattern(
///       pattern: RegExp(r'!![A-Za-z]+!!'),
///       builder: (context, match, style) => TextSpan(
///         text: match[0]!.replaceAll('!!', '').toUpperCase(),
///         style: style.copyWith(fontWeight: FontWeight.bold),
///       ),
///     ),
///   ],
/// )
/// ```
@Deprecated(
  'Use InlinePattern, or InlineDirective for a delimited payload. '
  'Will be removed in 2.0.0.',
)
abstract class InlineMd extends MarkdownComponent {
  @override
  bool get inline => true;

  @override
  InlineSpan span(
    BuildContext context,
    String text,
    final GptMarkdownConfig config,
  );
}

/// A masked [InlineDirective], put back as the host's span.
///
/// The directive was lifted out of the source before parsing, leaving an inert
/// sentinel; this is the regex pipeline's half of putting it back. Registered
/// first so nothing else can claim the sentinel.
///
/// The modern pipeline unmasks directives itself, so no caller should name
/// this type; [InlineDirective] is the API.
@Deprecated(
  'Built-in of the legacy regex pipeline; there is no replacement. '
  'Will be removed in 2.0.0.',
)
class InlineDirectiveMd extends InlineMd {
  @override
  Set<MarkdownScope> get scopes => MarkdownComponent.allScopes;

  @override
  RegExp get exp => RegExp(inlineDirectiveMaskPattern);

  @override
  InlineSpan span(
    BuildContext context,
    String text,
    final GptMarkdownConfig config,
  ) {
    final directives = config.inlineDirectives;
    final match = exp.firstMatch(text.trim());
    final decoded =
        match == null || directives == null
            ? null
            : decodeInlineDirectiveMask(match[0]!, directives.length);
    if (decoded == null || directives == null) {
      // A sentinel that is not one of this document's directives renders as
      // the text it is, rather than being mistaken for a widget.
      return TextSpan(text: text, style: config.style);
    }
    return _scaleInlineSpanWidgets(
      directives[decoded.index].builder(
        context,
        decoded.payload,
        config.style ?? const TextStyle(),
      ),
    );
  }
}

/// Block component of the legacy regex pipeline.
///
/// A subclass is reachable only through `components`, which selects the legacy
/// pipeline: the document is rendered as one text tree, with no incremental
/// segment cache, no span-level streaming reveal and no lazy sliver, so a
/// streaming reply re-parses and re-lays-out the whole message on every
/// append. Register the block with [MarkdownBlockComponent] instead, using
/// [FencedBlockSyntax] or a [MarkdownBlockSyntax] subclass for the syntax; the
/// parsed node is cached, so a rebuild does not run the syntax again.
///
/// Before:
///
/// ```dart
/// class CalloutMd extends BlockMd {
///   @override
///   String get expString => r':::(\w+)\n([\s\S]*?)\n:::';
///
///   @override
///   Widget build(
///     BuildContext context,
///     String text,
///     GptMarkdownConfig config,
///   ) {
///     final match = exp.firstMatch(text);
///     return Row(
///       children: [
///         Icon(
///           match?.group(1) == 'warning' ? Icons.warning : Icons.info,
///         ),
///         Flexible(child: Text(match?.group(2) ?? '')),
///       ],
///     );
///   }
/// }
///
/// GptMarkdown(
///   text,
///   components: [CalloutMd(), ...MarkdownComponent.globalComponents],
/// )
/// ```
///
/// After:
///
/// ```dart
/// GptMarkdown(
///   text,
///   blockComponents: [
///     MarkdownBlockComponent(
///       syntax: const FencedBlockSyntax(
///         type: 'callout',
///         opening: ':::warning',
///       ),
///       builder: (context, node, config) => Row(
///         children: [
///           const Icon(Icons.warning),
///           Flexible(child: Text(node.body)),
///         ],
///       ),
///     ),
///   ],
/// )
/// ```
@Deprecated(
  'Use MarkdownBlockComponent with blockComponents instead. '
  'Will be removed in 2.0.0.',
)
abstract class BlockMd extends MarkdownComponent {
  @override
  bool get inline => false;

  @override
  RegExp get exp =>
      RegExp(r'^\ *?' + expString + r"$", dotAll: true, multiLine: true);

  String get expString;

  @override
  InlineSpan span(
    BuildContext context,
    String text,
    final GptMarkdownConfig config,
  ) {
    var matches = RegExp(r'^(?<spaces>\ \ +).*').firstMatch(text);
    var spaces = matches?.namedGroup('spaces');
    var length = spaces?.length ?? 0;
    var child = build(context, text, config);
    length = min(length, 4);
    if (length > 0) {
      child = UnorderedListView(
        spacing: length * 1.0,
        textDirection: config.textDirection,
        child: child,
      );
    }
    child = Row(
      mainAxisSize: MainAxisSize.min,
      children: [Flexible(child: child)],
    );
    return scaledWidgetSpan(child: child, config: config);
  }

  Widget build(
    BuildContext context,
    String text,
    final GptMarkdownConfig config,
  );
}

/// Indent component
///
/// A built-in of the legacy regex pipeline's `components` list; the modern
/// pipeline handles indentation in its own block parser and never builds this
/// component.
@Deprecated(
  'Built-in of the legacy regex pipeline; there is no replacement. '
  'Will be removed in 2.0.0.',
)
class IndentMd extends BlockMd {
  @override
  String get expString => (r"^(\ \ +)([^\n]+)$");
  @override
  Widget build(
    BuildContext context,
    String text,
    final GptMarkdownConfig config,
  ) {
    var match = this.exp.firstMatch(text);
    var conf = config.copyWith();
    return Directionality(
      textDirection: config.textDirection,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: config.getRich(
              TextSpan(
                children: MarkdownComponent.generate(
                  context,
                  match?[2]?.trim() ?? "",
                  conf,
                  false,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Heading component
///
/// A built-in of the legacy regex pipeline's `components` list; the modern
/// pipeline parses headings itself.
@Deprecated(
  'Built-in of the legacy regex pipeline; there is no replacement. '
  'Will be removed in 2.0.0.',
)
class HTag extends BlockMd {
  @override
  String get expString => (r"(?<hash>#{1,6})\ (?<data>[^\n]+?)$");
  @override
  Widget build(
    BuildContext context,
    String text,
    final GptMarkdownConfig config,
  ) {
    var match = this.exp.firstMatch(text.trim());
    final hashes = match?.namedGroup('hash');
    return headingWidget(
      context,
      config,
      level: hashes == null ? 1 : hashes.length,
      buildChildren:
          (conf) => MarkdownComponent.generate(
            context,
            "${match?.namedGroup('data')}",
            conf,
            false,
          ),
    );
  }
}

/// Blank-line separator of the legacy regex pipeline.
///
/// A built-in of the legacy regex pipeline's `components` list; the modern
/// pipeline splits blocks itself.
@Deprecated(
  'Built-in of the legacy regex pipeline; there is no replacement. '
  'Will be removed in 2.0.0.',
)
class NewLines extends InlineMd {
  @override
  RegExp get exp => RegExp(r"\n\n+");
  @override
  InlineSpan span(
    BuildContext context,
    String text,
    final GptMarkdownConfig config,
  ) {
    return TextSpan(
      text: "\n\n",
      style: TextStyle(
        fontSize: config.style?.fontSize ?? 14,
        height: 1.15,
        color: config.style?.color,
      ),
    );
  }
}

/// Horizontal line component
///
/// A built-in of the legacy regex pipeline's `components` list; the modern
/// pipeline parses horizontal rules itself.
@Deprecated(
  'Built-in of the legacy regex pipeline; there is no replacement. '
  'Will be removed in 2.0.0.',
)
class HrLine extends BlockMd {
  @override
  String get expString => (r"⸻|((--)[-]+)$");
  @override
  Widget build(
    BuildContext context,
    String text,
    final GptMarkdownConfig config,
  ) {
    return hrWidget(context, config);
  }
}

/// Checkbox component
///
/// A built-in of the legacy regex pipeline's `components` list; the modern
/// pipeline parses task list items itself.
@Deprecated(
  'Built-in of the legacy regex pipeline; there is no replacement. '
  'Will be removed in 2.0.0.',
)
class CheckBoxMd extends BlockMd {
  @override
  String get expString => (r"\[((?:\x|\ ))\]\ (\S[^\n]*?)$");

  @override
  Widget build(
    BuildContext context,
    String text,
    final GptMarkdownConfig config,
  ) {
    var match = this.exp.firstMatch(text.trim());
    return checkboxWidget(
      context,
      config,
      checked: "${match?[1]}" == "x",
      label: MdWidget(context, "${match?[2]}", false, config: config),
    );
  }
}

/// Radio Button component
///
/// A built-in of the legacy regex pipeline's `components` list; the modern
/// pipeline parses radio options itself.
@Deprecated(
  'Built-in of the legacy regex pipeline; there is no replacement. '
  'Will be removed in 2.0.0.',
)
class RadioButtonMd extends BlockMd {
  @override
  String get expString => (r"\(((?:\x|\ ))\)\ (\S[^\n]*)$");

  @override
  Widget build(
    BuildContext context,
    String text,
    final GptMarkdownConfig config,
  ) {
    var match = this.exp.firstMatch(text.trim());
    return radioWidget(
      context,
      config,
      selected: "${match?[1]}" == "x",
      label: MdWidget(context, "${match?[2]}", false, config: config),
    );
  }
}

/// Block quote component
///
/// A built-in of the legacy regex pipeline's `components` list; the modern
/// pipeline parses block quotes itself.
@Deprecated(
  'Built-in of the legacy regex pipeline; there is no replacement. '
  'Will be removed in 2.0.0.',
)
class BlockQuote extends InlineMd {
  @override
  bool get inline => false;

  @override
  RegExp get exp => RegExp(
    r"(?:(?:^)\ *>[^\n]+)(?:(?:\n)\ *>[^\n]+)*",
    dotAll: true,
    multiLine: true,
  );

  @override
  InlineSpan span(
    BuildContext context,
    String text,
    final GptMarkdownConfig config,
  ) {
    var match = exp.firstMatch(text);
    var dataBuilder = StringBuffer();
    var m = match?[0] ?? '';
    for (var each in m.split('\n')) {
      if (each.startsWith(RegExp(r'\ *>'))) {
        var subString = each.trimLeft().substring(1);
        if (subString.startsWith(' ')) {
          subString = subString.substring(1);
        }
        dataBuilder.writeln(subString);
      } else {
        dataBuilder.writeln(each);
      }
    }
    var data = dataBuilder.toString().trim();

    return blockQuoteSpan(
      context,
      config,
      buildContent:
          (conf) => conf.getRich(
            TextSpan(
              children: MarkdownComponent.generate(context, data, conf, true),
            ),
          ),
    );
  }
}

/// Unordered list component
///
/// A built-in of the legacy regex pipeline's `components` list; the modern
/// pipeline parses unordered lists itself.
@Deprecated(
  'Built-in of the legacy regex pipeline; there is no replacement. '
  'Will be removed in 2.0.0.',
)
class UnOrderedList extends BlockMd {
  @override
  String get expString => (r"(?:\-|\*)\ ([^\n]+)$");

  @override
  Widget build(
    BuildContext context,
    String text,
    final GptMarkdownConfig config,
  ) {
    var match = this.exp.firstMatch(text);

    var child = MdWidget(context, "${match?[1]?.trim()}", true, config: config);

    return unorderedListItem(context, config, child);
  }
}

/// Ordered list component
///
/// A built-in of the legacy regex pipeline's `components` list; the modern
/// pipeline parses ordered lists itself.
@Deprecated(
  'Built-in of the legacy regex pipeline; there is no replacement. '
  'Will be removed in 2.0.0.',
)
class OrderedList extends BlockMd {
  @override
  String get expString => (r"([0-9]+)\.\ ([^\n]+)$");

  @override
  Widget build(
    BuildContext context,
    String text,
    final GptMarkdownConfig config,
  ) {
    var match = this.exp.firstMatch(text);

    var no = "${match?[1]}".trim();

    var child = MdWidget(context, "${match?[2]}".trim(), true, config: config);
    return orderedListItem(context, config, no, child);
  }
}

/// Builds the span for one run of inline `` `code` ``.
///
/// Shared by [HighlightedText] and the plusparse renderer so the two parsers
/// cannot drift apart on the thing a reader sees most often.
InlineSpan inlineCodeSpan(
  BuildContext context,
  String code,
  GptMarkdownConfig config,
) {
  // A plain TextSpan, tagged so the paragraph paints a rounded chip behind
  // it — see `custom_widgets/inline_code.dart`. Keeping it out of a
  // WidgetSpan is what lets inline code wrap across lines, stay selectable,
  // sit on the surrounding baseline, and appear inside a link label.
  // Three sources, narrowest first: the widget's own `inlineCodeStyle`, then
  // the style sheet (widget sheet over theme sheet, already merged by
  // `resolvedStyleSheet`), then the theme's standalone `inlineCode`. The sheet
  // used to be skipped entirely, so `GptMarkdownStyleSheet(inlineCode: ...)`
  // merged, lerped and compared like every other style and then changed
  // nothing on screen.
  // Whole objects, narrowest first — not a field-by-field merge. Merging would
  // pull the theme's `fontFamilyPackage` in behind a caller's own
  // `fontFamily`, and the package prefix would then be applied to a family
  // that does not ship here. Unset fields are filled by `resolve` below.
  final codeStyle = (config.inlineCodeStyle ??
          resolvedStyleSheet(context, config).inlineCode ??
          GptMarkdownTheme.of(context).inlineCode)
      .resolve(Theme.of(context).colorScheme);
  final textStyle = codeStyle.applyTo(config.style ?? const TextStyle());

  final builder = config.inlineCodeBuilder;
  if (builder != null) {
    return builder(context, code, textStyle, codeStyle);
  }

  final legacyBuilder = config.highlightBuilder;
  if (legacyBuilder != null) {
    // Kept so 1.1.x code compiles. Wrapped on the baseline rather than at
    // the old hardcoded `PlaceholderAlignment.middle`, which sat visibly off
    // the surrounding text.
    return baselineWidgetSpan(
      legacyBuilder(context, code, config.style ?? textStyle),
    );
  }

  return CodeTextSpan(text: code, codeStyle: codeStyle, style: textStyle);
}

/// Inline code component of the legacy regex pipeline.
///
/// A built-in of the legacy regex pipeline's `inlineComponents` list; the
/// modern pipeline parses inline code itself.
@Deprecated(
  'Built-in of the legacy regex pipeline; there is no replacement. '
  'Will be removed in 2.0.0.',
)
class HighlightedText extends InlineMd {
  @override
  RegExp get exp => RegExp(r"`(?!`)(.+?)(?<!`)`(?!`)");

  @override
  InlineSpan span(
    BuildContext context,
    String text,
    final GptMarkdownConfig config,
  ) {
    var match = exp.firstMatch(text.trim());
    return inlineCodeSpan(context, match?[1] ?? "", config);
  }
}

/// Bold text component
///
/// A built-in of the legacy regex pipeline's `inlineComponents` list; the
/// modern pipeline parses bold text itself.
@Deprecated(
  'Built-in of the legacy regex pipeline; there is no replacement. '
  'Will be removed in 2.0.0.',
)
class BoldMd extends InlineMd {
  @override
  RegExp get exp =>
      RegExp(r"(?<!\*)\*\*(?<!\s)(.+?)(?<!\s)\*\*(?!\*)", dotAll: true);

  @override
  InlineSpan span(
    BuildContext context,
    String text,
    final GptMarkdownConfig config,
  ) {
    var match = exp.firstMatch(text.trim());
    var conf = config.copyWith(
      style:
          config.style?.copyWith(fontWeight: FontWeight.bold) ??
          const TextStyle(fontWeight: FontWeight.bold),
    );
    return TextSpan(
      children: MarkdownComponent.generate(
        context,
        "${match?[1]}",
        conf,
        false,
      ),
      style: conf.style,
    );
  }
}

/// Strikethrough text component of the legacy regex pipeline.
///
/// A built-in of the legacy regex pipeline's `inlineComponents` list; the
/// modern pipeline parses strikethrough itself.
@Deprecated(
  'Built-in of the legacy regex pipeline; there is no replacement. '
  'Will be removed in 2.0.0.',
)
class StrikeMd extends InlineMd {
  @override
  RegExp get exp => RegExp(r"(?<!\*)\~\~(?<!\s)(.+?)(?<!\s)\~\~(?!\*)");

  @override
  InlineSpan span(
    BuildContext context,
    String text,
    final GptMarkdownConfig config,
  ) {
    var match = exp.firstMatch(text.trim());
    var conf = config.copyWith(
      style:
          config.style?.copyWith(
            decoration: TextDecoration.lineThrough,
            decorationColor: config.style?.color,
          ) ??
          const TextStyle(decoration: TextDecoration.lineThrough),
    );
    return TextSpan(
      children: MarkdownComponent.generate(
        context,
        "${match?[1]}",
        conf,
        false,
      ),
      style: conf.style,
    );
  }
}

/// Italic text component
///
/// A built-in of the legacy regex pipeline's `inlineComponents` list; the
/// modern pipeline parses italic text itself.
@Deprecated(
  'Built-in of the legacy regex pipeline; there is no replacement. '
  'Will be removed in 2.0.0.',
)
class ItalicMd extends InlineMd {
  @override
  RegExp get exp =>
      RegExp(r"(?:(?<!\*)\*(?<!\s)(.+?)(?<!\s)\*(?!\*))", dotAll: true);

  @override
  InlineSpan span(
    BuildContext context,
    String text,
    final GptMarkdownConfig config,
  ) {
    var match = exp.firstMatch(text.trim());
    var data = match?[1] ?? match?[2];
    var conf = config.copyWith(
      style: (config.style ?? const TextStyle()).copyWith(
        fontStyle: FontStyle.italic,
      ),
    );
    return TextSpan(
      children: MarkdownComponent.generate(context, "$data", conf, false),
      style: conf.style,
    );
  }
}

/// Block LaTeX component of the legacy regex pipeline.
///
/// A built-in of the legacy regex pipeline's component lists; the modern
/// pipeline parses display maths itself.
@Deprecated(
  'Built-in of the legacy regex pipeline; there is no replacement. '
  'Will be removed in 2.0.0.',
)
class LatexMathMultiLine extends BlockMd {
  @override
  String get expString => (r"\ *\\\[((?:.)*?)\\\]");
  @override
  RegExp get exp => RegExp(expString, dotAll: true, multiLine: true);

  @override
  Widget build(
    BuildContext context,
    String text,
    final GptMarkdownConfig config,
  ) {
    var p0 = exp.firstMatch(text.trim());
    return latexWidget(
      context,
      config,
      tex: p0?[1] ?? p0?[2] ?? '',
      inline: false,
    );
  }
}

/// Inline LaTeX component of the legacy regex pipeline.
///
/// A built-in of that pipeline's `inlineComponents` list; the modern pipeline
/// parses inline maths itself.
@Deprecated(
  'Built-in of the legacy regex pipeline; there is no replacement. '
  'Will be removed in 2.0.0.',
)
class LatexMath extends InlineMd {
  @override
  RegExp get exp => RegExp(
    [
      r"\\\((.*?)\\\)",
      // r"(?<!\\)\$((?:\\.|[^$])*?)\$(?!\\)",
    ].join("|"),
    dotAll: true,
  );

  @override
  InlineSpan span(
    BuildContext context,
    String text,
    final GptMarkdownConfig config,
  ) {
    var p0 = exp.firstMatch(text.trim());
    p0?.group(0);
    String mathText = p0?[1]?.toString() ?? "";
    return scaledWidgetSpan(
      config: config,
      child: latexWidget(context, config, tex: mathText, inline: true),
    );
  }
}

/// source text component
///
/// A built-in of the legacy regex pipeline's `inlineComponents` list; the
/// modern pipeline parses `[1]` citation chips itself.
@Deprecated(
  'Built-in of the legacy regex pipeline; there is no replacement. '
  'Will be removed in 2.0.0.',
)
class SourceTag extends InlineMd {
  @override
  RegExp get exp => RegExp(r"(?:【.*?)?\[(\d+?)\]");

  @override
  InlineSpan span(
    BuildContext context,
    String text,
    final GptMarkdownConfig config,
  ) {
    var match = exp.firstMatch(text.trim());
    var content = match?[1];
    if (content == null) {
      return const TextSpan();
    }
    return sourceTagSpan(context, content, config);
  }
}

/// Link text component
///
/// A built-in of the legacy regex pipeline's `inlineComponents` list; the
/// modern pipeline parses links itself.
@Deprecated(
  'Built-in of the legacy regex pipeline; there is no replacement. '
  'Will be removed in 2.0.0.',
)
class ATagMd extends InlineMd {
  @override
  RegExp get exp => RegExp(r"(?<!\!)\[.*?\]\([^\s]*\)");

  /// CommonMark forbids links inside link labels, and the label is rendered
  /// inside this component's own [WidgetSpan] — a second one nested in it does
  /// not paint on iOS.
  @override
  Set<MarkdownScope> get scopes => MarkdownComponent.allScopesExceptLinkLabel;

  @override
  InlineSpan span(
    BuildContext context,
    String text,
    final GptMarkdownConfig config,
  ) {
    var bracketCount = 0;
    var start = 1;
    var end = 0;
    for (var i = 0; i < text.length; i++) {
      if (text[i] == '[') {
        bracketCount++;
      } else if (text[i] == ']') {
        bracketCount--;
        if (bracketCount == 0) {
          end = i;
          break;
        }
      }
    }

    if (end + 1 >= text.length || text[end + 1] != '(') {
      // Malformed link. Show the source text instead of deleting it.
      return TextSpan(text: text, style: config.style);
    }

    // First try to find the basic pattern
    // final basicMatch = RegExp(r'(?<!\!)\[(.*)\]\(').firstMatch(text.trim());
    // if (basicMatch == null) {
    //   return const TextSpan();
    // }

    final linkText = text.substring(start, end);
    final urlStart = end + 2;

    // Now find the balanced closing parenthesis
    int parenCount = 0;
    int urlEnd = urlStart;

    for (int i = urlStart; i < text.length; i++) {
      final char = text[i];

      if (char == '(') {
        parenCount++;
      } else if (char == ')') {
        if (parenCount == 0) {
          // This is the closing parenthesis of the link
          urlEnd = i;
          break;
        } else {
          parenCount--;
        }
      }
    }

    if (urlEnd == urlStart) {
      // No closing parenthesis found. Show the source text instead of
      // deleting it.
      return TextSpan(text: text, style: config.style);
    }

    final url = text.substring(urlStart, urlEnd).trim();

    var ending = text.substring(urlEnd + 1);

    var endingSpans = MarkdownComponent.generate(
      context,
      ending,
      config,
      false,
    );

    final child = buildLinkSpan(context, config, url: url, label: linkText);
    var textSpan = TextSpan(children: [child, ...endingSpans]);
    return textSpan;
  }
}

/// The style sheet in force: the widget's, merged over the theme's, field by
/// field, with anything still unset resolved to the package default.
///
/// Kept in one place so every component resolves its style the same way and a
/// widget override never discards the rest of the theme.
GptMarkdownStyleSheet resolvedStyleSheet(
  BuildContext context,
  GptMarkdownConfig config,
) {
  final widgetSheet = config.styleSheet ?? const GptMarkdownStyleSheet();
  return widgetSheet.merge(GptMarkdownTheme.of(context).styleSheet);
}

/// A [WidgetSpan] for an inline widget.
///
/// Note for anyone touching text scaling: a paragraph lays inline children out
/// in *scaled* space — it divides their constraints by the scale factor and
/// multiplies the reported size back. At a 3x setting a block widget is
/// therefore given a third of the width, wraps into a narrow column and
/// reserves far more height than it needs. Compensating for that inside the
/// child was tried and produced overlapping text; the fix belongs in how
/// blocks are composed, not in a wrapper. See CHANGELOG.
WidgetSpan scaledWidgetSpan({
  required Widget child,
  required GptMarkdownConfig config,
  PlaceholderAlignment alignment = PlaceholderAlignment.baseline,
  TextBaseline? baseline = TextBaseline.alphabetic,
}) {
  return WidgetSpan(
    alignment: alignment,
    baseline: baseline,
    child: MarkdownTextScaling.wrap(child, enabled: false),
  );
}

/// Builds the span for a link, shared by [ATagMd] and [AutolinkMd].
///
/// [label] is rendered through [MarkdownComponent.generate] in the
/// [MarkdownScope.linkLabel] scope when [parseLabel] is true. Autolinks pass
/// false: their label *is* the URL, and running it back through the inline
/// components would let `ItalicMd` eat the underscores out of a path such as
/// `https://example.com/a_b_c`.
InlineSpan buildLinkSpan(
  BuildContext context,
  GptMarkdownConfig config, {
  required String url,
  required String label,
  bool parseLabel = true,
  List<InlineSpan> Function(GptMarkdownConfig conf)? buildLabelSpans,
}) {
  final theme = GptMarkdownTheme.of(context);
  // `LinkStyle.resolve` cannot reach these — it is handed a `ColorScheme` and
  // the defaults live on `GptMarkdownTheme`. Resolve here so a builder is
  // handed a `LinkStyle` whose fields are genuinely filled in.
  final linkStyleSpec = (resolvedStyleSheet(context, config).link ??
          const LinkStyle())
      .resolve(Theme.of(context).colorScheme);
  final baseColor = linkStyleSpec.color ?? theme.linkColor;
  final hoverColor = linkStyleSpec.hoverColor ?? theme.linkHoverColor;
  final decoration = linkStyleSpec.decoration ?? TextDecoration.underline;
  final resolvedLinkStyle = linkStyleSpec.copyWith(
    color: baseColor,
    hoverColor: hoverColor,
    decoration: decoration,
  );

  List<InlineSpan> labelSpans(TextStyle style) {
    final conf = config.copyWith(style: style, scope: MarkdownScope.linkLabel);
    // The plusparse renderer already holds the label's parsed children, so it
    // supplies them rather than having the text re-parsed.
    final custom = buildLabelSpans;
    if (custom != null) {
      return custom(conf);
    }
    if (!parseLabel) {
      return [TextSpan(text: label, style: style)];
    }
    return MarkdownComponent.generate(context, label, conf, false);
  }

  final linkTextStyle = (config.style ?? const TextStyle()).copyWith(
    color: baseColor,
    decorationColor: baseColor,
    decoration: decoration,
    decorationThickness: resolvedLinkStyle.decorationThickness,
    fontWeight: resolvedLinkStyle.fontWeight,
  );

  final onLinkTap = config.onLinkTap;
  final onTap = onLinkTap == null ? null : () => onLinkTap(url, label);

  final builder = config.inlineLinkBuilder;
  if (builder != null) {
    final details = LinkBuildDetails(
      context: context,
      config: config,
      style: linkTextStyle,
      url: url,
      label: label,
      labelSpans: labelSpans(linkTextStyle),
      linkStyle: resolvedLinkStyle,
      isAutolink: !parseLabel,
      onTap: onTap,
    );
    final span = builder(details);
    assert(
      onTap == null ||
          // `[](url)` has no label, so there is genuinely nothing to tap and
          // nothing wrong. Without this the package's own recommended
          // `defaultSpan()` trips its own assert on valid Markdown.
          span.toPlainText(includePlaceholders: false).isEmpty ||
          _hasReachableTap(span),
      'inlineLinkBuilder returned a span with nothing that can be tapped for '
      '"$url". A GestureRecognizer only fires on a TextSpan that carries text, '
      'and a plain TextSpan carries no tap at all. Return '
      'details.defaultSpan(), a TappableTextSpan/LinkTextSpan, or '
      'details.asWidgetSpan() for a widget.',
    );
    return span;
  }

  final legacyBuilder = config.linkBuilder;
  if (legacyBuilder != null) {
    // Kept so 1.2.x code compiles: a Widget still has to go in a placeholder,
    // and the tap still has to be a GestureDetector around it.
    return scaledWidgetSpan(
      config: config,
      child: GestureDetector(
        // Always non-null, as it has been since 1.1: a null callback makes
        // `GestureDetector` transparent, so a link would start passing taps
        // through to whatever wraps it for anyone who has no `onLinkTap`.
        onTap: () => onTap?.call(),
        child: legacyBuilder(
          context,
          TextSpan(children: labelSpans(linkTextStyle), style: linkTextStyle),
          url,
          config.style ?? const TextStyle(),
        ),
      ),
    );
  }

  // Default rendering — a span, not a widget.
  //
  // A `WidgetSpan` link sits off the text baseline, cannot wrap across lines
  // (the whole label jumps to the next one), is skipped by text selection, and
  // is one opaque character to the streaming reveal. As a span the label is
  // real text: it wraps mid-label, selects with the sentence around it, and
  // reveals character by character.
  //
  // The tap cannot ride on this span's own recognizer — a recognizer only
  // fires on a span that carries its own `text`, and this one carries
  // `children`. `LinkTextSpan` is resolved by text range instead; see
  // `InlineTapTargets`.
  //
  // Hover is likewise resolved once per paragraph rather than by a
  // `StatefulWidget` per link, which is what `LinkButton` used to do.
  return LinkTextSpan.wrapping(
    children: labelSpans(linkTextStyle),
    url: url,
    linkStyle: resolvedLinkStyle,
    style: linkTextStyle,
    hoverStyle: TextStyle(color: hoverColor, decorationColor: hoverColor),
    onTap: onTap,
  );
}

/// Whether a tap can reach anything in [root].
///
/// True when the tree holds a [TappableTextSpan] with a measurable range, a
/// [TextSpan] leaf carrying its own recognizer, or any placeholder — a
/// placeholder owns its own gestures, so the package cannot tell whether it is
/// tappable and does not guess. Debug only.
bool _hasReachableTap(InlineSpan root) {
  if (collectInlineTapRuns(root).isNotEmpty) {
    return true;
  }
  var reachable = false;
  void visit(InlineSpan span) {
    if (reachable) {
      return;
    }
    if (span is! TextSpan) {
      reachable = true;
      return;
    }
    if (span.recognizer != null && (span.text?.isNotEmpty ?? false)) {
      reachable = true;
      return;
    }
    for (final child in span.children ?? const <InlineSpan>[]) {
      visit(child);
    }
  }

  visit(root);
  return reachable;
}

/// Image component
///
/// A built-in of the legacy regex pipeline's `inlineComponents` list; the
/// modern pipeline parses images itself.
@Deprecated(
  'Built-in of the legacy regex pipeline; there is no replacement. '
  'Will be removed in 2.0.0.',
)
class ImageMd extends InlineMd {
  @override
  RegExp get exp => RegExp(r"\!\[[^\[\]]*\]\([^\s]*\)");

  /// An image is not meaningful as a link label, and nesting its [WidgetSpan]
  /// inside the link's own one does not paint on iOS.
  @override
  Set<MarkdownScope> get scopes => MarkdownComponent.allScopesExceptLinkLabel;

  @override
  InlineSpan span(
    BuildContext context,
    String text,
    final GptMarkdownConfig config,
  ) {
    // First try to find the basic pattern
    final basicMatch = RegExp(r'\!\[([^\[\]]*)\]\(').firstMatch(text.trim());
    if (basicMatch == null) {
      return const TextSpan();
    }

    final altText = basicMatch.group(1) ?? '';
    final urlStart = basicMatch.end;

    // Now find the balanced closing parenthesis
    int parenCount = 0;
    int urlEnd = urlStart;

    for (int i = urlStart; i < text.length; i++) {
      final char = text[i];

      if (char == '(') {
        parenCount++;
      } else if (char == ')') {
        if (parenCount == 0) {
          // This is the closing parenthesis of the image
          urlEnd = i;
          break;
        } else {
          parenCount--;
        }
      }
    }

    if (urlEnd == urlStart) {
      // No closing parenthesis found
      return const TextSpan();
    }

    final url = text.substring(urlStart, urlEnd).trim();

    double? height;
    double? width;
    if (altText.isNotEmpty) {
      var size = RegExp(r"^([0-9]+)?x?([0-9]+)?").firstMatch(altText.trim());
      width = double.tryParse(size?[1]?.toString().trim() ?? 'a');
      height = double.tryParse(size?[2]?.toString().trim() ?? 'a');
    }

    return imageSpan(context, config, url: url, width: width, height: height);
  }
}

/// Table component
///
/// A built-in of the legacy regex pipeline's component lists; the modern
/// pipeline parses tables itself.
@Deprecated(
  'Built-in of the legacy regex pipeline; there is no replacement. '
  'Will be removed in 2.0.0.',
)
class TableMd extends BlockMd {
  /// A table cannot be a link label.
  @override
  Set<MarkdownScope> get scopes => MarkdownComponent.allScopesExceptLinkLabel;

  @override
  String get expString =>
      (r"(((\|[^\n\|]+\|)((([^\n\|]+\|)+)?)\ *)(\n\ *(((\|[^\n\|]+\|)(([^\n\|]+\|)+)?))\ *)+)$");
  @override
  Widget build(
    BuildContext context,
    String text,
    final GptMarkdownConfig config,
  ) {
    final tableStyle = (resolvedStyleSheet(context, config).table ??
            const TableStyle())
        .resolve(Theme.of(context).colorScheme);
    final tableRadius = tableStyle.borderRadius;
    final List<Map<int, String>> value =
        text
            .split('\n')
            .map<Map<int, String>>(
              (e) =>
                  e
                      .trim()
                      .split('|')
                      .where((element) => element.isNotEmpty)
                      .toList()
                      .asMap(),
            )
            .toList();

    // Check if table has a header and separator row
    bool hasHeader = value.length >= 2;
    List<TextAlign> columnAlignments = [];

    if (hasHeader) {
      // Parse alignment from the separator row (second row)
      var separatorRow = value[1];
      columnAlignments = List.generate(separatorRow.length, (index) {
        String separator = separatorRow[index] ?? "";
        separator = separator.trim();

        // Check for alignment indicators
        bool hasLeftColon = separator.startsWith(':');
        bool hasRightColon = separator.endsWith(':');

        if (hasLeftColon && hasRightColon) {
          return TextAlign.center;
        } else if (hasRightColon) {
          return TextAlign.right;
        } else if (hasLeftColon) {
          return TextAlign.left;
        } else {
          return TextAlign.left; // Default alignment
        }
      });
    }

    int maxCol = 0;
    for (final each in value) {
      if (maxCol < each.keys.length) {
        maxCol = each.keys.length;
      }
    }

    if (maxCol == 0) {
      return Text("", style: config.style);
    }

    // Ensure we have alignment for all columns
    while (columnAlignments.length < maxCol) {
      columnAlignments.add(TextAlign.left);
    }

    var tableBuilder = config.tableBuilder;

    if (tableBuilder != null) {
      var customTable =
          List<CustomTableRow?>.generate(value.length, (index) {
            var isHeader = index == 0;
            var row = value[index];
            if (row.isEmpty) {
              return null;
            }
            if (index == 1) {
              return null;
            }
            var fields = List<CustomTableField>.generate(maxCol, (index) {
              var field = row[index];
              return CustomTableField(
                data: field ?? "",
                alignment: columnAlignments[index],
              );
            });
            return CustomTableRow(isHeader: isHeader, fields: fields);
          }).nonNulls.toList();
      return tableBuilder(
        context,
        customTable,
        config.style ?? const TextStyle(),
        config,
      );
    }

    return _TableViewport(
      child: Table(
        textDirection: config.textDirection,
        defaultColumnWidth:
            tableStyle.columnWidth ?? const CustomTableColumnWidth(),
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        border: TableBorder.all(
          width: tableStyle.borderWidth ?? 1,
          color:
              tableStyle.borderColor ?? Theme.of(context).colorScheme.onSurface,
          borderRadius:
              tableRadius == null
                  ? BorderRadius.zero
                  : BorderRadius.all(tableRadius),
        ),
        children:
            value
                .asMap()
                .entries
                .where((entry) {
                  // Skip the separator row (second row) from rendering
                  if (hasHeader && entry.key == 1) {
                    return false;
                  }
                  return true;
                })
                .map<TableRow>((entry) {
                  final isHeader = hasHeader && entry.key == 0;
                  // Stripes count data rows, so the header never takes one
                  // and the first row under it is always unstriped. The
                  // separator row is already filtered out above, so the key
                  // is the source row index: data rows start at 2 with a
                  // header and at 0 without.
                  final stripe = tableStyle.rowStripeColor;
                  final dataIndex = hasHeader ? entry.key - 2 : entry.key;
                  return TableRow(
                    decoration:
                        isHeader
                            ? BoxDecoration(
                              color:
                                  tableStyle.headerBackground ??
                                  Theme.of(
                                    context,
                                  ).colorScheme.surfaceContainerHighest,
                            )
                            : (stripe != null && dataIndex.isOdd)
                            ? BoxDecoration(color: stripe)
                            : null,
                    children: List.generate(maxCol, (index) {
                      var e = entry.value;
                      String data = e[index] ?? "";
                      if (RegExp(r"^:?--+:?$").hasMatch(data.trim()) ||
                          data.trim().isEmpty) {
                        return const SizedBox();
                      }

                      // Apply alignment based on column alignment
                      Widget content = Padding(
                        padding:
                            tableStyle.cellPadding ??
                            const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                        child: MdWidget(
                          context,
                          (e[index] ?? "").trim(),
                          false,
                          config: config.copyWith(
                            scope: MarkdownScope.tableCell,
                          ),
                        ),
                      );
                      // Merged into the ambient style rather than replacing
                      // it, so setting only `fontWeight` keeps the document's
                      // family, size and colour.
                      final headerStyle = tableStyle.headerTextStyle;
                      if (isHeader && headerStyle != null) {
                        content = DefaultTextStyle.merge(
                          style: headerStyle,
                          child: content,
                        );
                      }

                      // Only a column that pulls its content off the leading
                      // edge needs an alignment box. A left-aligned cell is
                      // already flush left: the table hands it a tight width
                      // and the text starts at the leading edge on its own.
                      // The box is not free — content-sized columns lay every
                      // cell out twice, once to measure and once for real, so
                      // a redundant wrapper is two extra layouts per cell.
                      switch (columnAlignments[index]) {
                        case TextAlign.center:
                          content = Center(child: content);
                          break;
                        case TextAlign.right:
                          content = Align(
                            alignment: Alignment.centerRight,
                            child: content,
                          );
                          break;
                        case TextAlign.left:
                        default:
                          break;
                      }

                      return content;
                    }),
                  );
                })
                .toList(),
      ),
    );
  }
}

/// Fenced code block component of the legacy regex pipeline.
///
/// A built-in of the legacy regex pipeline's `components` list; the modern
/// pipeline parses fenced code itself.
@Deprecated(
  'Built-in of the legacy regex pipeline; there is no replacement. '
  'Will be removed in 2.0.0.',
)
class CodeBlockMd extends BlockMd {
  @override
  String get expString => r"```(.*?)\n((.*?)(:?\n\s*?```)|(.*)(:?\n```)?)$";
  @override
  Widget build(
    BuildContext context,
    String text,
    final GptMarkdownConfig config,
  ) {
    String codes = this.exp.firstMatch(text)?[2] ?? "";
    String name = this.exp.firstMatch(text)?[1] ?? "";
    codes = codes.replaceAll(r"```", "");
    return codeBlockWidget(
      context,
      config,
      name: name,
      code: codes,
      closed: text.endsWith("```"),
    );
  }
}

/// `<u>` underline component of the legacy regex pipeline.
///
/// A built-in of the legacy regex pipeline's `inlineComponents` list; the
/// modern pipeline parses `<u>` spans itself.
@Deprecated(
  'Built-in of the legacy regex pipeline; there is no replacement. '
  'Will be removed in 2.0.0.',
)
class UnderLineMd extends InlineMd {
  @override
  RegExp get exp =>
      RegExp(r"<u>(.*?)(?:</u>|$)", multiLine: true, dotAll: true);

  @override
  InlineSpan span(
    BuildContext context,
    String text,
    final GptMarkdownConfig config,
  ) {
    var match = exp.firstMatch(text.trim());
    var conf = config.copyWith(
      style: (config.style ?? const TextStyle()).copyWith(
        decoration: TextDecoration.underline,
        decorationColor: config.style?.color,
      ),
    );
    return TextSpan(
      children: MarkdownComponent.generate(
        context,
        "${match?[1]}",
        conf,
        false,
      ),
      style: conf.style,
    );
  }
}

class CustomTableField {
  final String data;
  final TextAlign alignment;

  CustomTableField({required this.data, this.alignment = TextAlign.left});
}

class CustomTableRow {
  final bool isHeader;
  final List<CustomTableField> fields;

  CustomTableRow({this.isHeader = false, required this.fields});
}
