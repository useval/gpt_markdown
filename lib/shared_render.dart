part of 'gpt_markdown.dart';

/// Rendering shared by the two parsers.
///
/// The regex pipeline ([MarkdownComponent.generate]) and the plusparse
/// renderer disagree about how a block's *content* is produced — one re-runs
/// components over a substring, the other already holds a parsed AST — but
/// everything after that point is identical: resolve the style, hand off to a
/// caller-supplied builder if there is one, otherwise build the default
/// widget. Keeping that half here means a change to a default, a style field
/// or a builder hook lands on both paths at once.
///
/// Each function takes the content as a already-built [Widget] or as a
/// callback, which is the only part the two parsers need to supply themselves.

/// The horizontal rule, honouring [GptMarkdownConfig.hrBuilder] and
/// [HrStyle].
Widget hrWidget(BuildContext context, GptMarkdownConfig config) {
  final gptTheme = GptMarkdownTheme.of(context);
  final style = (resolvedStyleSheet(context, config).hr ?? const HrStyle())
      .resolve(Theme.of(context).colorScheme);
  final builder = config.hrBuilder;
  if (builder != null) {
    return builder(context, style);
  }
  final padding = style.padding;
  return CustomDivider(
    height: style.thickness ?? gptTheme.hrLineThickness,
    color: style.color ?? gptTheme.hrLineColor,
    padding: padding is EdgeInsets ? padding : gptTheme.hrLinePadding,
  );
}

/// A task-list checkbox with [label] beside it, honouring
/// [GptMarkdownConfig.checkboxBuilder], [CheckboxStyle] and
/// [GptMarkdownConfig.onCheckboxChanged].
Widget checkboxWidget(
  BuildContext context,
  GptMarkdownConfig config, {
  required bool checked,
  required Widget label,
}) {
  final style = (resolvedStyleSheet(context, config).checkbox ??
          const CheckboxStyle())
      .resolve(Theme.of(context).colorScheme);
  final builder = config.checkboxBuilder;
  if (builder != null) {
    return builder(context, checked, label, style);
  }
  return CustomCb(
    scalesItsOwnText: config.blocksRenderDirectly,
    value: checked,
    textDirection: config.textDirection,
    spacing: style.gapAfterBox ?? 5,
    style: style,
    onChanged: config.onCheckboxChanged,
    child: label,
  );
}

/// A radio option with [label] beside it, honouring
/// [GptMarkdownConfig.radioOptionBuilder] and [CheckboxStyle].
Widget radioWidget(
  BuildContext context,
  GptMarkdownConfig config, {
  required bool selected,
  required Widget label,
}) {
  final style = (resolvedStyleSheet(context, config).checkbox ??
          const CheckboxStyle())
      .resolve(Theme.of(context).colorScheme);
  final builder = config.radioOptionBuilder;
  if (builder != null) {
    return builder(context, selected, label, style);
  }
  return CustomRb(
    scalesItsOwnText: config.blocksRenderDirectly,
    value: selected,
    textDirection: config.textDirection,
    spacing: style.gapAfterBox ?? 5,
    style: style,
    onChanged: config.onCheckboxChanged,
    child: label,
  );
}

/// A heading of [level], honouring [GptMarkdownConfig.headingBuilder] and
/// [HeadingStyle].
///
/// [buildChildren] receives the heading-scoped config — the level's text style
/// merged with any [HeadingStyle.textStyle] override, and
/// [MarkdownScope.heading] — and returns the spans for the heading's own
/// content. Each parser supplies that differently.
Widget headingWidget(
  BuildContext context,
  GptMarkdownConfig config, {
  required int level,
  required List<InlineSpan> Function(GptMarkdownConfig conf) buildChildren,
}) {
  // A heading lifted out of the paragraph has to scale itself, from the
  // ambient MediaQuery; inside one, the paragraph already did it.
  final ambient = config.blocksRenderDirectly;
  final theme = GptMarkdownTheme.of(context);
  final headingStyle = (resolvedStyleSheet(context, config).heading ??
          const HeadingStyle())
      .resolve(Theme.of(context).colorScheme);
  final levelStyle =
      [theme.h1, theme.h2, theme.h3, theme.h4, theme.h5, theme.h6][level - 1];
  final override = headingStyle.textStyle;
  final conf = config.copyWith(
    scope: MarkdownScope.heading,
    style:
        override == null
            ? levelStyle
            : (levelStyle ?? const TextStyle()).merge(override),
  );

  final builder = config.headingBuilder;
  if (builder != null) {
    final content = config.getRich(
      TextSpan(children: buildChildren(conf)),
      ambientScaling: ambient,
    );
    return builder(context, level, content, headingStyle);
  }

  final dividerPadding = headingStyle.dividerPadding;
  final rich = config.getRich(
    ambientScaling: ambient,
    TextSpan(
      children: [
        ...buildChildren(conf),
        if (level == 1 &&
            (headingStyle.showDivider ?? theme.autoAddDividerLineAfterH1)) ...[
          const TextSpan(text: "\n ", style: TextStyle(fontSize: 0, height: 0)),
          // Left uncompensated on purpose. The rule is a one-pixel decoration
          // with no text in it, so the paragraph scaling its box is invisible —
          // and compensating it made the space it takes at 1x differ from every
          // other scale.
          WidgetSpan(
            child: CustomDivider(
              height: headingStyle.dividerThickness ?? theme.hrLineThickness,
              color: headingStyle.dividerColor ?? theme.hrLineColor,
              padding:
                  dividerPadding is EdgeInsets
                      ? dividerPadding
                      : theme.hrLinePadding,
            ),
          ),
        ],
      ],
    ),
  );

  final headingPadding = headingStyle.padding;
  if (headingPadding == null) {
    return rich;
  }
  return Padding(padding: headingPadding, child: rich);
}

/// A block quote, honouring [GptMarkdownConfig.blockQuoteBuilder] and
/// [BlockQuoteStyle].
///
/// [buildContent] receives the quote-scoped config — the surrounding style
/// merged with any [BlockQuoteStyle.textStyle] override — and returns the
/// quote's rendered body.
InlineSpan blockQuoteSpan(
  BuildContext context,
  GptMarkdownConfig config, {
  required Widget Function(GptMarkdownConfig conf) buildContent,
}) {
  final style = (resolvedStyleSheet(context, config).blockQuote ??
          const BlockQuoteStyle())
      .resolve(Theme.of(context).colorScheme);

  var quotedConfig = config;
  final textStyle = style.textStyle;
  if (textStyle != null) {
    final base = config.style;
    quotedConfig = config.copyWith(
      style: base == null ? textStyle : base.merge(textStyle),
    );
  }
  final content = buildContent(quotedConfig);

  final builder = config.blockQuoteBuilder;
  final Widget quote =
      builder == null
          ? defaultQuoteWidget(context, content, style, config.textDirection)
          : builder(context, content, style);

  return TextSpan(
    children: [
      BlockWidgetSpan(
        alignment: PlaceholderAlignment.bottom,
        baseline: null,
        child: MarkdownTextScaling.wrap(quote, enabled: false),
        bare: quote,
      ),
    ],
  );
}

/// The default block quote: a bar, optional padding, background and margin.
Widget defaultQuoteWidget(
  BuildContext context,
  Widget content,
  BlockQuoteStyle style,
  TextDirection direction,
) {
  final padding = style.padding;
  final margin = style.margin;
  final background = style.backgroundColor;

  Widget child = content;
  if (padding != null) {
    child = Padding(padding: padding, child: child);
  }
  child = BlockQuoteWidget(
    color: style.barColor ?? Theme.of(context).colorScheme.onSurfaceVariant,
    direction: direction,
    width: style.barWidth ?? 3,
    child: child,
  );
  if (background != null) {
    final radius = style.barRadius;
    child = DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: radius == null ? null : BorderRadius.all(radius),
      ),
      child: child,
    );
  }
  if (margin != null) {
    child = Padding(padding: margin, child: child);
  }
  return Directionality(textDirection: direction, child: child);
}

/// A placeholder holding a *block* construct rather than an inline one.
///
/// The difference matters to whoever is laying the document out. A block owns
/// its line and can be lifted out of the paragraph entirely — rendered as a
/// sibling widget, skipping both the placeholder and the nested `Text.rich`
/// inside it. An inline image or equation cannot: it is positioned against a
/// text baseline that would no longer exist.
///
/// Marked explicitly because the two are indistinguishable by shape — an image
/// and a block quote are both a lone bottom-aligned `WidgetSpan`, and telling
/// them apart by looking silently swallowed every image in the document.
class BlockWidgetSpan extends WidgetSpan {
  /// Wraps a block-level [child].
  const BlockWidgetSpan({
    required super.child,
    this.bare,
    super.alignment,
    super.baseline,
    super.style,
  });

  /// [child] without the flex wrapper a placeholder needs, for a caller that
  /// is about to render this block as a sibling widget instead of inside a
  /// paragraph.
  ///
  /// Inside a paragraph the wrapper earns its keep. Rendered directly it is
  /// two render objects per block that resolve to the same constraints the
  /// column already hands down, and paint walks every one of them on every
  /// frame — which a streaming reply pays for on every chunk.
  final Widget? bare;
}

/// A citation tag such as `[1]`, honouring
/// [GptMarkdownConfig.inlineSourceTagBuilder], [SourceTagStyle] and
/// [GptMarkdownConfig.onSourceTagTap].
InlineSpan sourceTagSpan(
  BuildContext context,
  String id,
  GptMarkdownConfig config,
) {
  final tagStyle = (resolvedStyleSheet(context, config).sourceTag ??
          const SourceTagStyle())
      .resolve(Theme.of(context).colorScheme);
  final onSourceTagTap = config.onSourceTagTap;
  final onTap = onSourceTagTap == null ? null : () => onSourceTagTap(id);

  final details = SourceTagBuildDetails(
    context: context,
    config: config,
    // The resolved style, not `const TextStyle()`. `SourceTagStyle.textStyle`
    // documents itself as defaulting to the surrounding style; now it does.
    style: tagStyle.textStyle ?? config.style ?? const TextStyle(),
    id: id,
    sourceTagStyle: tagStyle,
    onTap: onTap,
  );

  final builder = config.inlineSourceTagBuilder;
  if (builder != null) {
    final span = builder(details);
    assert(
      onTap == null ||
          span.toPlainText(includePlaceholders: false).isEmpty ||
          _hasReachableTap(span),
      'inlineSourceTagBuilder returned a span with nothing that can be tapped '
      'for "$id". Return details.defaultSpan(), a TappableTextSpan, or '
      'details.asWidgetSpan() for a widget.',
    );
    return span;
  }

  // ignore: deprecated_member_use_from_same_package
  final legacyBuilder = config.sourceTagBuilder;
  if (legacyBuilder != null) {
    // Kept so 1.2.x code compiles, including the empty TextStyle it has always
    // been handed — that is what existing builders were written against.
    return details.asWidgetSpan(
      legacyBuilder(context, id, tagStyle.textStyle ?? const TextStyle()),
    );
  }

  return defaultSourceTagSpan(details);
}

/// The stock `[1]` chip: a filled circle with the number scaled to fit.
///
/// Split out so [SourceTagBuildDetails.defaultSpan] can return it, and so a
/// builder that only wants to wrap the stock chip does not have to restate it.
InlineSpan defaultSourceTagSpan(SourceTagBuildDetails details) {
  final style = details.sourceTagStyle;
  final size = style.size ?? 20;
  return details.asWidgetSpan(
    SizedBox(
      width: size,
      height: size,
      child: Material(
        color:
            style.backgroundColor ??
            Theme.of(details.context).colorScheme.onInverseSurface,
        shape:
            style.shape == BoxShape.rectangle
                ? const RoundedRectangleBorder()
                : const OvalBorder(),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            details.id,
            style: style.textStyle,
            textDirection: details.config.textDirection,
          ),
        ),
      ),
    ),
  );
}

/// A fenced code block, honouring [GptMarkdownConfig.codeBuilder],
/// [CodeBlockStyle] and [GptMarkdownConfig.onCodeCopy].
Widget codeBlockWidget(
  BuildContext context,
  GptMarkdownConfig config, {
  required String name,
  required String code,
  required bool closed,
}) {
  final style = (resolvedStyleSheet(context, config).codeBlock ??
          const CodeBlockStyle())
      .resolve(Theme.of(context).colorScheme);
  return config.codeBuilder?.call(context, name, code, closed) ??
      CodeField(
        scalesItsOwnText: config.blocksRenderDirectly,
        name: name,
        codes: code,
        highlightCode: closed || (style.highlightWhileStreaming ?? true),
        style: style,
        onCopy: config.onCodeCopy,
      );
}

/// One bullet-list item, honouring [GptMarkdownConfig.unOrderedListBuilder]
/// and [ListStyle].
Widget unorderedListItem(
  BuildContext context,
  GptMarkdownConfig config,
  Widget child,
) {
  final builder = config.unOrderedListBuilder;
  if (builder != null) {
    return builder(context, child, config.copyWith());
  }
  final style = (resolvedStyleSheet(context, config).list ?? const ListStyle())
      .resolve(Theme.of(context).colorScheme);
  final fontSize =
      config.style?.fontSize ??
      DefaultTextStyle.of(context).style.fontSize ??
      kDefaultFontSize;
  return UnorderedListView(
    scalesItsOwnText: config.blocksRenderDirectly,
    bulletColor:
        style.bulletColor ??
        config.style?.color ??
        DefaultTextStyle.of(context).style.color,
    padding: style.indent ?? 7,
    spacing: style.gapAfterMarker ?? 10,
    bulletSize: style.bulletSize ?? 0.3 * fontSize,
    bulletShape: style.bulletShape ?? BoxShape.circle,
    textDirection: config.textDirection,
    child: child,
  );
}

/// One numbered-list item, honouring [GptMarkdownConfig.orderedListBuilder]
/// and [ListStyle]. [no] is the number without its trailing dot.
Widget orderedListItem(
  BuildContext context,
  GptMarkdownConfig config,
  String no,
  Widget child,
) {
  final builder = config.orderedListBuilder;
  if (builder != null) {
    return builder(context, no, child, config.copyWith());
  }
  final style = (resolvedStyleSheet(context, config).list ?? const ListStyle())
      .resolve(Theme.of(context).colorScheme);
  final marker = style.markerTextStyle;
  final base = (config.style ?? const TextStyle()).copyWith(
    fontWeight: FontWeight.w100,
  );
  return OrderedListView(
    scalesItsOwnText: config.blocksRenderDirectly,
    no: "$no.",
    textDirection: config.textDirection,
    style: marker == null ? base : base.merge(marker),
    // 6 is what `OrderedListView` used before this was configurable; the
    // bullet list uses different numbers, so neither is a shared default.
    padding: style.indent ?? 6,
    spacing: style.gapAfterMarker ?? 6,
    child: child,
  );
}

/// An image, honouring [GptMarkdownConfig.imageBuilder], [ImageStyle] and
/// [GptMarkdownConfig.onImageTap].
InlineSpan imageSpan(
  BuildContext context,
  GptMarkdownConfig config, {
  required String url,
  double? width,
  double? height,
}) {
  // Resolved before the image is built, not after: `fit` decides how the
  // bytes are drawn, so it has to be in hand at construction time. It used to
  // be resolved below, purely for the border and padding, which is why `fit`,
  // `maxWidth` and `maxHeight` were settable and inert.
  final imageStyle = (resolvedStyleSheet(context, config).image ??
          const ImageStyle())
      .resolve(Theme.of(context).colorScheme);

  final builder = config.imageBuilder;
  final Widget image;
  if (builder != null) {
    image = builder(context, url, width, height);
  } else {
    image = SizedBox(
      width: width,
      height: height,
      child: Image(
        image: NetworkImage(url),
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) {
            return child;
          }
          final total = loadingProgress.expectedTotalBytes;
          return CustomImageLoading(
            progress:
                total == null
                    ? 1
                    : loadingProgress.cumulativeBytesLoaded / total,
          );
        },
        fit: imageStyle.fit ?? BoxFit.fill,
        errorBuilder: (context, error, stackTrace) => const CustomImageError(),
      ),
    );
  }

  Widget decorated = image;
  // A ceiling, not a size: an image smaller than the bound keeps its own
  // dimensions. Applied before the rounding and padding so the clip follows
  // the constrained box rather than the original.
  final maxWidth = imageStyle.maxWidth;
  final maxHeight = imageStyle.maxHeight;
  if (maxWidth != null || maxHeight != null) {
    decorated = ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: maxWidth ?? double.infinity,
        maxHeight: maxHeight ?? double.infinity,
      ),
      child: decorated,
    );
  }
  final imageRadius = imageStyle.borderRadius;
  if (imageRadius != null) {
    decorated = ClipRRect(
      borderRadius: BorderRadius.all(imageRadius),
      child: decorated,
    );
  }
  final imagePadding = imageStyle.padding;
  if (imagePadding != null) {
    decorated = Padding(padding: imagePadding, child: decorated);
  }
  final onImageTap = config.onImageTap;
  if (onImageTap != null) {
    decorated = GestureDetector(onTap: () => onImageTap(url), child: decorated);
  }
  return scaledWidgetSpan(
    config: config,
    alignment: PlaceholderAlignment.bottom,
    baseline: null,
    child: decorated,
  );
}

/// Rendered maths, honouring [GptMarkdownConfig.latexBuilder],
/// [GptMarkdownConfig.latexWorkaround] and [LatexStyle].
///
/// [inline] picks between an inline formula and a display block; only the
/// block form takes [LatexStyle]'s padding, background and horizontal scroll.
Widget latexWidget(
  BuildContext context,
  GptMarkdownConfig config, {
  required String tex,
  required bool inline,
}) {
  final workaround = config.latexWorkaround ?? (String tex) => tex;
  final builder =
      config.latexBuilder ??
      (BuildContext context, String tex, TextStyle textStyle, bool inline) =>
          SelectableAdapter(
            selectedText: tex,
            child: Math.tex(
              tex,
              textStyle: textStyle,
              mathStyle: MathStyle.display,
              textScaleFactor: 1,
              settings: const TexParserSettings(strict: Strict.ignore),
              options: MathOptions(
                sizeUnderTextStyle: MathSize.large,
                color:
                    config.style?.color ??
                    Theme.of(context).colorScheme.onSurface,
                fontSize: MarkdownTextScaling.fontSize(
                  context,
                  textStyle.fontSize ??
                      Theme.of(context).textTheme.bodyMedium?.fontSize ??
                      14,
                ),
                mathFontOptions: FontOptions(
                  fontFamily: "Main",
                  fontWeight: config.style?.fontWeight ?? FontWeight.normal,
                  fontShape: FontStyle.normal,
                ),
                textFontOptions: FontOptions(
                  fontFamily: "Main",
                  fontWeight: config.style?.fontWeight ?? FontWeight.normal,
                  fontShape: FontStyle.normal,
                ),
                style: MathStyle.display,
              ),
              onErrorFallback:
                  (err) => Text(
                    workaround(tex),
                    textDirection: config.textDirection,
                    style: textStyle.copyWith(
                      color:
                          (!kDebugMode)
                              ? null
                              : Theme.of(context).colorScheme.error,
                    ),
                  ),
            ),
          );

  final latexStyle = (resolvedStyleSheet(context, config).latex ??
          const LatexStyle())
      .resolve(Theme.of(context).colorScheme);
  final override = latexStyle.textStyle;
  final base = config.style ?? const TextStyle();
  // Build below the boundary so custom builders and the math engine read the
  // effective scaler, including when this formula is nested inside a block.
  Widget maths = MarkdownTextScaling.wrap(
    Builder(
      builder:
          (mathContext) => builder(
            mathContext,
            workaround(tex),
            override == null ? base : base.merge(override),
            inline,
          ),
    ),
    enabled: !inline && config.blocksRenderDirectly,
  );
  if (inline) {
    return maths;
  }

  if (latexStyle.scrollBlockHorizontally ?? false) {
    // Rendered maths cannot wrap, so a wide formula overflows a phone.
    maths = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: maths,
    );
  }
  final background = latexStyle.backgroundColor;
  if (background != null) {
    final radius = latexStyle.borderRadius;
    maths = DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: radius == null ? null : BorderRadius.all(radius),
      ),
      child: maths,
    );
  }
  final padding = latexStyle.padding;
  if (padding != null) {
    maths = Padding(padding: padding, child: maths);
  }
  return maths;
}

/// Owns the horizontal scroll state of one mounted table.
class _TableViewport extends StatefulWidget {
  const _TableViewport({required this.child});
  final Widget child;
  @override
  State<_TableViewport> createState() => _TableViewportState();
}

class _TableViewportState extends State<_TableViewport> {
  final _controller = ScrollController();
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// The strip reserved under the table for the bar, and the bar's own
  /// thickness — the same number, so the bar fills the strip exactly. Material
  /// would otherwise hold a 2px `crossAxisMargin` off the edge, leaving a gap
  /// under the bar; that is set to zero below.
  static const double _barStrip = 8;

  @override
  Widget build(BuildContext context) {
    // A horizontal scrollable never gets a scrollbar from the ambient
    // behaviour — `MaterialScrollBehavior.buildScrollbar` returns the child
    // unchanged for `Axis.horizontal` on every platform — so this widget is
    // the only reason one appears, and it is on us to decide where.
    //
    // On a touch device, nowhere: a finger already knows how to drag a table
    // sideways, and the bar has no gesture of its own to offer. Drawn, it
    // overlaps the bottom row, because a scrollbar paints inside the viewport
    // it belongs to.
    switch (Theme.of(context).platform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
      case TargetPlatform.fuchsia:
        return SingleChildScrollView(
          controller: _controller,
          scrollDirection: Axis.horizontal,
          child: widget.child,
        );
      case TargetPlatform.linux:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
        // A pointer has no such affordance, so the bar earns its place — but
        // it gets a strip of its own rather than the last row's. The strip is
        // exactly the bar's height: no gap under it.
        return ScrollbarTheme(
          // `crossAxisMargin` is not a `Scrollbar` argument; it only reaches
          // the painter through the theme. Material defaults it to 2, which
          // holds the bar off the viewport edge and leaves a gap beneath it.
          data: ScrollbarThemeData(
            crossAxisMargin: 0,
            mainAxisMargin: 0,
            thickness: const WidgetStatePropertyAll<double>(_barStrip),
          ),
          child: Scrollbar(
            controller: _controller,
            child: SingleChildScrollView(
              controller: _controller,
              scrollDirection: Axis.horizontal,
              child: Padding(
                padding: const EdgeInsets.only(bottom: _barStrip),
                child: widget.child,
              ),
            ),
          ),
        );
    }
  }
}
