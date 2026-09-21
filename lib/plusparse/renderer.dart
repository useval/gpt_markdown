part of '../gpt_markdown.dart';

/// Renders a plusparse [MdDocument] AST into the same `InlineSpan` tree the
/// regex pipeline (`MarkdownComponent.generate`) produces — same custom
/// widgets ([CodeField], [UnorderedListView], [LinkButton], [CustomCb], …),
/// same theme handling, same config builder hooks. Parsing is a single pass
/// over the text instead of recursive combined-regex scanning, which is what
/// makes re-rendering streaming LLM output cheap.
class PlusparseRenderer {
  PlusparseRenderer._();

  /// Parses [text] and renders it to spans. When [inlineOnly] is true (the
  /// old `includeGlobalComponents: false` mode used for nested content such
  /// as table cells), a single-paragraph document is unwrapped to its inline
  /// spans instead of being treated as a block.
  static List<InlineSpan> render(
    BuildContext context,
    String text,
    GptMarkdownConfig config, {
    bool inlineOnly = false,
  }) {
    // The incremental view masks earlier, before it segments; masking again is
    // a no-op because a masked directive no longer holds its own delimiters.
    final directives = config.inlineDirectives;
    if (directives != null && directives.isNotEmpty) {
      text = maskInlineDirectives(
        text,
        directives,
        blockRegistry: config.blockRegistry,
      );
    }
    final patterns = config.inlinePatterns;
    if (patterns != null && patterns.isNotEmpty) {
      text = maskInlinePatterns(
        text,
        patterns,
        blockRegistry: config.blockRegistry,
      );
    }
    return renderDocument(
      context,
      Plusparse.parse(text, blockRegistry: config.blockRegistry),
      config,
      inlineOnly: inlineOnly,
    );
  }

  /// Renders an existing syntax tree without parsing again. The document is
  /// independent of Flutter themes; callers may retain it across style changes.
  /// This does not mask inline extensions or normalize source; use [render]
  /// when starting from raw Markdown with syntax-override patterns/directives.
  static List<InlineSpan> renderDocument(
    BuildContext context,
    MdDocument doc,
    GptMarkdownConfig config, {
    bool inlineOnly = false,
  }) {
    if (inlineOnly &&
        doc.children.length == 1 &&
        doc.children.first is MdParagraph) {
      return _inlineSpans(
        context,
        (doc.children.first as MdParagraph).children,
        config,
      );
    }
    return _blockSpans(context, doc.children, config);
  }

  // ---------------------------------------------------------------------
  // Block level
  // ---------------------------------------------------------------------

  /// The paragraph-break span the regex pipeline's `NewLines` component emits.
  static TextSpan _paragraphBreak(GptMarkdownConfig config) => TextSpan(
    text: "\n\n",
    style: TextStyle(
      fontSize: config.style?.fontSize ?? 14,
      height: 1.15,
      color: config.style?.color,
    ),
  );

  /// Replicates `BlockMd.span`'s wrapping of a block widget.
  static InlineSpan _blockSpan(Widget child) => BlockWidgetSpan(
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(child: MarkdownTextScaling.wrap(child, enabled: false)),
      ],
    ),
    bare: child,
    alignment: PlaceholderAlignment.baseline,
    baseline: TextBaseline.alphabetic,
  );

  /// A block widget whose inner text the streaming reveal can still reach.
  ///
  /// [content] is the text the block wraps, built once for counting.
  /// [wrap] builds the widget from a transform to apply to that text — the
  /// identity transform for a static render, the reveal while streaming. The
  /// widget is built by the same code either way, so nothing about its
  /// appearance depends on whether a reveal is running.
  static InlineSpan _revealableBlock({
    required List<InlineSpan> content,
    required Widget Function(SpanTransform transform) wrap,
  }) {
    InlineSpan build(SpanTransform transform) => RevealableSpan(
      content: content,
      rebuild: build,
      children: [_blockSpan(wrap(transform))],
    );
    return build(_identity);
  }

  static List<InlineSpan> _identity(List<InlineSpan> spans) => spans;

  static List<InlineSpan> _blockSpans(
    BuildContext context,
    List<MdNode> blocks,
    GptMarkdownConfig config, {
    String separator = "\n\n",
  }) {
    final spans = <InlineSpan>[];
    for (final node in blocks) {
      if (spans.isNotEmpty) {
        spans.add(
          separator == "\n\n"
              ? _paragraphBreak(config)
              : TextSpan(text: separator, style: config.style),
        );
      }
      spans.addAll(_block(context, node, config));
    }
    return spans;
  }

  static List<InlineSpan> _block(
    BuildContext context,
    MdNode node,
    GptMarkdownConfig config,
  ) {
    switch (node) {
      case MdCustomBlock():
        final builder = config.blockRenderers[node.type];
        return [
          _blockSpan(
            builder == null
                ? Text(node.body, style: config.style)
                : builder(context, node, config),
          ),
        ];
      case MdParagraph(:final children):
        return _inlineSpans(context, children, config);
      case MdHeading(:final level, :final children):
        List<InlineSpan>? content;
        InlineSpan heading(SpanTransform transform) {
          final child = headingWidget(
            context,
            config,
            level: level,
            buildChildren:
                (conf) => transform(
                  content ??= _inlineSpans(context, children, conf),
                ),
          );
          return RevealableSpan(
            content: content!,
            rebuild: heading,
            children: [_blockSpan(child)],
          );
        }
        return [heading(_identity)];
      case MdHorizontalRule():
        return [_blockSpan(hrWidget(context, config))];
      case MdCodeBlock(:final language, :final code, :final closed):
        return [
          _blockSpan(
            codeBlockWidget(
              context,
              config,
              name: language,
              code: code,
              closed: closed,
            ),
          ),
        ];
      case MdBlockLatex(:final tex):
        return [
          _blockSpan(latexWidget(context, config, tex: tex, inline: false)),
        ];
      case MdBlockQuote(:final children):
        // Build once under the actual quote style. Counting an independently
        // rendered copy used to double the work at EVERY nesting level.
        List<InlineSpan>? content;
        InlineSpan quote(SpanTransform transform) {
          final child = blockQuoteSpan(
            context,
            config,
            buildContent:
                (conf) => conf.getRich(
                  TextSpan(
                    children: transform(
                      content ??= _blockSpans(
                        context,
                        children,
                        conf.copyWith(blocksRenderDirectly: false),
                      ),
                    ),
                  ),
                  ambientScaling: conf.blocksRenderDirectly,
                ),
          );
          return RevealableSpan(
            content: content!,
            rebuild: quote,
            children: [child],
          );
        }
        return [quote(_identity)];
      case MdCheckbox(:final checked, :final children):
        // Built once and used for both the reveal's character count and the
        // rendered label: `wrap` is handed the same `config` here, so a second
        // build produced an identical list. Headings and block quotes do need
        // two, because their `wrap` re-renders under a different config.
        final labelSpans = _inlineSpans(context, children, config);
        return [
          _revealableBlock(
            content: labelSpans,
            wrap:
                (transform) => checkboxWidget(
                  context,
                  config,
                  checked: checked,
                  label: config.getRich(
                    TextSpan(children: transform(labelSpans)),
                    ambientScaling: config.blocksRenderDirectly,
                  ),
                ),
          ),
        ];
      case MdRadio(:final selected, :final children):
        final labelSpans = _inlineSpans(context, children, config);
        return [
          _revealableBlock(
            content: labelSpans,
            wrap:
                (transform) => radioWidget(
                  context,
                  config,
                  selected: selected,
                  label: config.getRich(
                    TextSpan(children: transform(labelSpans)),
                    ambientScaling: config.blocksRenderDirectly,
                  ),
                ),
          ),
        ];
      case MdUnorderedList(:final items):
        return _list(context, items, config, ordered: false, start: 1);
      case MdOrderedList(:final start, :final items):
        return _list(context, items, config, ordered: true, start: start);
      case MdTable():
        return [_table(context, node, config)];
      // Inline nodes reaching block position (defensive; parser does not
      // produce this) render as inline content.
      default:
        return _inlineSpans(context, [node], config);
    }
  }

  static List<InlineSpan> _list(
    BuildContext context,
    List<MdListItem> items,
    GptMarkdownConfig config, {
    required bool ordered,
    required int start,
  }) {
    final spans = <InlineSpan>[];
    for (var i = 0; i < items.length; i++) {
      if (spans.isNotEmpty) {
        spans.add(TextSpan(text: "\n", style: config.style));
      }
      // An item's children are its inline content followed by any nested
      // blocks (e.g. a nested list); render them into one rich child.
      final item = items[i];
      final inline = <MdNode>[];
      final nested = <MdNode>[];
      for (final n in item.children) {
        (_isInline(n) && nested.isEmpty ? inline : nested).add(n);
      }
      List<InlineSpan> body(GptMarkdownConfig conf) => [
        ..._inlineSpans(context, inline, conf),
        if (nested.isNotEmpty) ...[
          // Only when there is something to separate. A task list item is a
          // block node (the checkbox) with no inline content at all, and an
          // unconditional break put it on the line below its own bullet.
          if (inline.isNotEmpty) TextSpan(text: "\n", style: conf.style),
          // These blocks remain placeholders in the item paragraph; only
          // the outer item was lifted into the widget tree.
          ..._blockSpans(
            context,
            nested,
            conf.copyWith(blocksRenderDirectly: false),
            separator: "\n",
          ),
        ],
      ];

      final number = ordered ? "${item.number ?? (start + i)}" : null;
      // Same config both times, so build the item body once.
      final itemBody = body(config);
      spans.add(
        _revealableBlock(
          content: itemBody,
          wrap: (transform) {
            final itemChild = config.getRich(
              TextSpan(children: transform(itemBody)),
              ambientScaling: config.blocksRenderDirectly,
            );
            return number == null
                ? unorderedListItem(context, config, itemChild)
                : orderedListItem(context, config, number, itemChild);
          },
        ),
      );
    }
    return spans;
  }

  static bool _isInline(MdNode n) => switch (n) {
    MdText() ||
    MdBold() ||
    MdItalic() ||
    MdStrike() ||
    MdUnderline() ||
    MdInlineCode() ||
    MdInlineLatex() ||
    MdLink() ||
    MdImage() ||
    MdSourceTag() ||
    MdLineBreak() => true,
    _ => false,
  };

  static InlineSpan _table(
    BuildContext context,
    MdTable node,
    GptMarkdownConfig config,
  ) {
    final rows = [node.header, ...node.rows];
    var maxCol = 0;
    for (final row in rows) {
      maxCol = max(maxCol, row.cells.length);
    }
    if (maxCol == 0) {
      return TextSpan(text: "", style: config.style);
    }

    final columnAlignments = List<TextAlign>.generate(maxCol, (i) {
      final align = i < node.aligns.length ? node.aligns[i] : MdAlign.none;
      return switch (align) {
        MdAlign.center => TextAlign.center,
        MdAlign.right => TextAlign.right,
        _ => TextAlign.left,
      };
    });

    // A left-aligned cell no longer sits in an alignment box, so its text
    // fills the column and its own `textAlign` is what places it. An unset
    // `textAlign` already starts at the leading edge, which is exactly what
    // that column wants — so only a caller who set one needs overriding, and
    // the common table allocates nothing here. A centred or right-aligned
    // column keeps its box and shrink-wraps inside it, where `textAlign` has
    // nothing left to do.
    final ambientAlign = config.textAlign;
    final leftConfig =
        (ambientAlign == null ||
                ambientAlign == TextAlign.left ||
                ambientAlign == TextAlign.start)
            ? config
            : config.copyWith(textAlign: TextAlign.left);

    final tableBuilder = config.tableBuilder;
    if (tableBuilder != null) {
      final customTable = List<CustomTableRow>.generate(rows.length, (index) {
        final row = rows[index];
        final fields = List<CustomTableField>.generate(maxCol, (col) {
          return CustomTableField(
            data:
                col < row.cells.length
                    ? _plainText(row.cells[col].content)
                    : "",
            alignment: columnAlignments[col],
          );
        });
        return CustomTableRow(isHeader: index == 0, fields: fields);
      });
      return _blockSpan(
        tableBuilder(
          context,
          customTable,
          config.style ?? const TextStyle(),
          config,
        ),
      );
    }

    final tableStyle = (resolvedStyleSheet(context, config).table ??
            const TableStyle())
        .resolve(Theme.of(context).colorScheme);
    final tableRadius = tableStyle.borderRadius;
    return _blockSpan(
      _TableViewport(
        child: Table(
          textDirection: config.textDirection,
          defaultColumnWidth:
              tableStyle.columnWidth ?? const CustomTableColumnWidth(),
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          border: TableBorder.all(
            width: tableStyle.borderWidth ?? 1,
            color:
                tableStyle.borderColor ??
                Theme.of(context).colorScheme.onSurface,
            borderRadius:
                tableRadius == null
                    ? BorderRadius.zero
                    : BorderRadius.all(tableRadius),
          ),
          children: List<TableRow>.generate(rows.length, (index) {
            final row = rows[index];
            final isHeader = index == 0;
            // Stripes count data rows, so the header never takes one and the
            // first row under it is always unstriped.
            final stripe = tableStyle.rowStripeColor;
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
                      : (stripe != null && index.isEven)
                      ? BoxDecoration(color: stripe)
                      : null,
              children: List<Widget>.generate(maxCol, (col) {
                final cell = col < row.cells.length ? row.cells[col] : null;
                if (cell == null || cell.content.isEmpty) {
                  return const SizedBox();
                }
                final cellConfig =
                    columnAlignments[col] == TextAlign.left
                        ? leftConfig
                        : config;
                Widget content = Padding(
                  padding:
                      tableStyle.cellPadding ??
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: cellConfig.getRich(
                    ambientScaling: config.blocksRenderDirectly,
                    TextSpan(
                      children: _inlineSpans(context, cell.content, cellConfig),
                    ),
                  ),
                );
                // Merged into the ambient style rather than replacing it, so
                // setting only `fontWeight` keeps the document's family, size
                // and colour. `getRich` renders the span as given and does not
                // apply `config.style`, so the header style has to arrive as
                // an inherited default rather than through the config.
                final headerStyle = tableStyle.headerTextStyle;
                if (isHeader && headerStyle != null) {
                  content = DefaultTextStyle.merge(
                    style: headerStyle,
                    child: content,
                  );
                }
                // Only a column that pulls its content off the leading edge
                // needs an alignment box. A left-aligned cell is already
                // flush left. The box is not free: content-sized columns lay
                // every cell out twice, once to measure and once for real, so
                // a redundant wrapper is two extra layouts per cell on top of
                // one more render object for paint to walk.
                switch (columnAlignments[col]) {
                  case TextAlign.center:
                    content = Center(child: content);
                    break;
                  case TextAlign.right:
                    content = Align(
                      alignment: Alignment.centerRight,
                      child: content,
                    );
                    break;
                  default:
                    break;
                }
                return content;
              }),
            );
          }),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Inline level
  // ---------------------------------------------------------------------

  static List<InlineSpan> _inlineSpans(
    BuildContext context,
    List<MdNode> nodes,
    GptMarkdownConfig config,
  ) {
    final spans = <InlineSpan>[];
    for (final node in nodes) {
      spans.add(_inline(context, node, config));
    }
    return spans;
  }

  /// Runs a run of plain text through the consumer-facing inline syntaxes:
  /// [GptMarkdownConfig.inlinePatterns] first, then autolinking.
  ///
  /// Patterns are regex components, so they are dispatched by
  /// [MarkdownComponent.generate] with a component list holding nothing else —
  /// which is what keeps their scope filtering, boundary rules and precedence
  /// identical to the regex pipeline instead of reimplemented here. Autolinks
  /// used to go the same way and no longer do; see [_plainTextSpans].
  static List<InlineSpan> _textSpans(
    BuildContext context,
    String text,
    GptMarkdownConfig config,
  ) {
    // A masked directive is inert text to everything upstream; this is where
    // it becomes a span again. Done first so the host's builder receives the
    // payload before inline patterns or autolinking can touch it.
    List<InlineSpan> withPatterns(String rest) {
      // Patterns were lifted out before parsing so they could beat the
      // built-in interpretation of the same text; this puts them back.
      final patterns = config.inlinePatterns;
      if (patterns == null || patterns.isEmpty) {
        return _plainTextSpans(context, rest, config);
      }
      return expandInlinePatterns(
        context,
        rest,
        patterns,
        config,
        (plain) => _plainTextSpans(context, plain, config),
      );
    }

    final directives = config.inlineDirectives;
    if (directives != null && directives.isNotEmpty) {
      return expandInlineDirectives(
        context,
        text,
        directives,
        config.style ?? const TextStyle(),
        withPatterns,
      );
    }
    return withPatterns(text);
  }

  /// Autolinks one run of plain text.
  ///
  /// Patterns have already been expanded by the caller, so the only
  /// consumer-facing syntax left here is autolinking.
  ///
  /// This was the last thing on the plusparse path that ran the legacy
  /// combined regex, and it was the most expensive: the autolink pattern is a
  /// six-way alternation, so proving that a paragraph of ordinary prose holds
  /// no link meant backtracking at every word. [autolinkSpans] finds the same
  /// candidates with a character scan and hands each one to the same
  /// [AutolinkMd] resolution code; `test/regression/autolink_parity_test.dart`
  /// holds the two paths against each other.
  static List<InlineSpan> _plainTextSpans(
    BuildContext context,
    String text,
    GptMarkdownConfig config,
  ) {
    if (!config.autolink) {
      return [TextSpan(text: text, style: config.style)];
    }
    final patterns = config.inlinePatterns;
    if (patterns != null && patterns.isNotEmpty) {
      // Not the scanner: a pattern and an autolink decide precedence between
      // them through one combined regex — patterns are listed first, so the
      // earliest match wins and a tie goes to the pattern — and splitting the
      // dispatch in two would decide it by which half ran first instead.
      //
      // This is also the only place a pattern can still be claimed at all.
      // Masking lifts pattern matches out of the *source* before parsing, but
      // a run is not always a substring of it: `RegExp(r'^b$')` matches the
      // `b` that `a**b**c` parses to and never matches the source, so this
      // dispatch is what renders it. `test/regression/autolink_parity_test`
      // pins that case.
      return MarkdownComponent.generate(
        context,
        text,
        config.copyWith(inlineComponents: [AutolinkMd()]),
        false,
      );
    }
    return autolinkSpans(context, text, config);
  }

  static InlineSpan _inline(
    BuildContext context,
    MdNode node,
    GptMarkdownConfig config,
  ) {
    // Contexts a placeholder must not appear in. A link label is already
    // rendered inside the link's own `WidgetSpan`, and a second one nested in
    // it does not paint on iOS.
    if (config.scope == MarkdownScope.linkLabel) {
      switch (node) {
        case MdImage(:final alt, :final url):
          return TextSpan(text: '![$alt]($url)', style: config.style);
        case MdLink(:final children):
          // CommonMark forbids a link inside a link label; render the label's
          // own content and drop the nested link.
          return TextSpan(
            children: _inlineSpans(context, children, config),
            style: config.style,
          );
        default:
          break;
      }
    }

    switch (node) {
      case MdText(:final text):
        return TextSpan(
          children: _textSpans(context, text, config),
          style: config.style,
        );
      case MdLineBreak():
        return TextSpan(text: "\n", style: config.style);
      case MdBold(:final children):
        final conf = config.copyWith(
          style:
              config.style?.copyWith(fontWeight: FontWeight.bold) ??
              const TextStyle(fontWeight: FontWeight.bold),
        );
        return TextSpan(
          children: _inlineSpans(context, children, conf),
          style: conf.style,
        );
      case MdItalic(:final children):
        final conf = config.copyWith(
          style: (config.style ?? const TextStyle()).copyWith(
            fontStyle: FontStyle.italic,
          ),
        );
        return TextSpan(
          children: _inlineSpans(context, children, conf),
          style: conf.style,
        );
      case MdStrike(:final children):
        final conf = config.copyWith(
          style:
              config.style?.copyWith(
                decoration: TextDecoration.lineThrough,
                decorationColor: config.style?.color,
              ) ??
              const TextStyle(decoration: TextDecoration.lineThrough),
        );
        return TextSpan(
          children: _inlineSpans(context, children, conf),
          style: conf.style,
        );
      case MdUnderline(:final children):
        final conf = config.copyWith(
          style: (config.style ?? const TextStyle()).copyWith(
            decoration: TextDecoration.underline,
            decorationColor: config.style?.color,
          ),
        );
        return TextSpan(
          children: _inlineSpans(context, children, conf),
          style: conf.style,
        );
      case MdInlineCode(:final text):
        return inlineCodeSpan(context, text, config);
      case MdInlineLatex(:final tex):
        return WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: latexWidget(context, config, tex: tex, inline: true),
        );
      case MdLink(:final children, :final url):
        return _link(context, children, url, config);
      case MdImage(:final url, :final width, :final height):
        return imageSpan(
          context,
          config,
          url: url,
          width: width,
          height: height,
        );
      case MdSourceTag(:final id):
        return sourceTagSpan(context, id, config);
      // Block nodes in inline position (nested content) fall back to their
      // block rendering.
      default:
        final blocks = _block(context, node, config);
        return blocks.length == 1 ? blocks.first : TextSpan(children: blocks);
    }
  }

  static InlineSpan _link(
    BuildContext context,
    List<MdNode> children,
    String url,
    GptMarkdownConfig config,
  ) {
    return buildLinkSpan(
      context,
      config,
      url: url,
      label: _plainText(children),
      buildLabelSpans: (conf) => _inlineSpans(context, children, conf),
    );
  }

  static String _plainText(List<MdNode> nodes) {
    final out = StringBuffer();
    for (final n in nodes) {
      switch (n) {
        case MdText(:final text):
          out.write(text);
        case MdInlineCode(:final text):
          out.write(text);
        case MdInlineLatex(:final tex):
          out.write(tex);
        case MdSourceTag(:final id):
          out.write(id);
        case MdBold(:final children):
        case MdItalic(:final children):
        case MdStrike(:final children):
        case MdUnderline(:final children):
        case MdLink(:final children, url: _):
          out.write(_plainText(children));
        default:
          break;
      }
    }
    return out.toString();
  }
}
