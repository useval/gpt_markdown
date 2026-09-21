import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:gpt_markdown/custom_widgets/bidi_rich_text.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

/// A builder function for the ordered list.
typedef OrderedListBuilder =
    Widget Function(
      BuildContext context,
      String no,
      Widget child,
      GptMarkdownConfig config,
    );

/// A builder function for the unordered list.
typedef UnOrderedListBuilder =
    Widget Function(
      BuildContext context,
      Widget child,
      GptMarkdownConfig config,
    );

/// A builder function for the source tag.
@Deprecated(
  'Use InlineSourceTagBuilder via GptMarkdown.inlineSourceTagBuilder. '
  'This returns a Widget, which the package has to wrap in a WidgetSpan: it '
  'sits off the baseline, cannot wrap across lines, is skipped by text '
  'selection, is one opaque character to the streaming reveal, and does not '
  'paint on iOS inside a link label. It is also handed an empty TextStyle '
  'rather than the resolved one whenever the style sheet leaves '
  'SourceTagStyle.textStyle unset, and its positional parameters cannot grow. '
  'Will be removed in 2.0.0.',
)
typedef SourceTagBuilder =
    Widget Function(BuildContext context, String content, TextStyle textStyle);

/// A builder function for the code block.
typedef CodeBlockBuilder =
    Widget Function(
      BuildContext context,
      String name,
      String code,
      bool closed,
    );

/// A builder function for the LaTeX.
typedef LatexBuilder =
    Widget Function(
      BuildContext context,
      String tex,
      TextStyle textStyle,
      bool inline,
    );

/// A builder function for the link.
@Deprecated(
  'Use InlineLinkBuilder via GptMarkdown.inlineLinkBuilder. '
  'This returns a Widget, which the package has to wrap in a WidgetSpan: the '
  'label sits off the baseline, cannot wrap across lines, is skipped by text '
  'selection, is one opaque character to the streaming reveal, and does not '
  'paint on iOS inside a link label. Its four positional parameters are the '
  'other half of the problem — the resolved LinkStyle, whether the link is an '
  'autolink, and a link title have nowhere to go without breaking every '
  'caller. Will be removed in 2.0.0.',
)
typedef LinkBuilder =
    Widget Function(
      BuildContext context,
      InlineSpan text,
      String url,
      TextStyle style,
    );

/// A builder function for the table.
typedef TableBuilder =
    Widget Function(
      BuildContext context,
      List<CustomTableRow> tableRows,
      TextStyle textStyle,
      GptMarkdownConfig config,
    );

/// A builder function for the highlight.
@Deprecated(
  'Use InlineCodeBuilder via GptMarkdown.inlineCodeBuilder. '
  'This returns a Widget, which the package has to wrap in a WidgetSpan: it '
  'sits off the baseline, cannot wrap across lines, is skipped by text '
  'selection, and does not paint on iOS inside a link label. '
  'Will be removed in 2.0.0.',
)
typedef HighlightBuilder =
    Widget Function(BuildContext context, String text, TextStyle style);

/// Builds the span for one run of inline `` `code` ``.
///
/// [code] is the text between the backticks, [style] is the resolved code
/// [TextStyle] (monospace, sized and coloured per [InlineCodeStyle]), and
/// [codeStyle] is the resolved [InlineCodeStyle] itself, so a builder can reuse
/// the chip colours it would have been drawn with.
///
/// Return a [CodeTextSpan] to keep the painted chip, any other [TextSpan] to
/// drop it, or [baselineWidgetSpan] when a widget is genuinely required:
///
/// ```dart
/// inlineCodeBuilder: (context, code, style, codeStyle) => CodeTextSpan(
///   text: code,
///   codeStyle: codeStyle.copyWith(
///     backgroundColor: code.startsWith('TODO') ? Colors.amber : null,
///   ),
///   style: style,
/// ),
/// ```
///
/// Returning an [InlineSpan] rather than a [Widget] is what keeps inline code
/// on the text baseline, wrapping across lines, and selectable.
typedef InlineCodeBuilder =
    InlineSpan Function(
      BuildContext context,
      String code,
      TextStyle style,
      InlineCodeStyle codeStyle,
    );

/// Builds the widget for a `#` heading.
///
/// [level] is 1 to 6, [content] is the rendered heading text, and [style] is
/// the resolved [HeadingStyle]. A builder owns the whole heading, including
/// the rule an h1 draws by default — check `style.showDivider` if you want to
/// keep that behaviour.
typedef HeadingBuilder =
    Widget Function(
      BuildContext context,
      int level,
      Widget content,
      HeadingStyle style,
    );

/// Builds the widget for a task-list checkbox and its label.
///
/// [checked] is the state parsed from the source, [content] is the rendered
/// label, and [style] is the resolved [CheckboxStyle]. Wire taps through
/// `GptMarkdown.onCheckboxChanged` — the source text is the model, so nothing
/// changes state on its own.
typedef CheckboxBuilder =
    Widget Function(
      BuildContext context,
      bool checked,
      Widget content,
      CheckboxStyle style,
    );

/// Builds the widget for a radio option and its label.
///
/// [selected] is the state parsed from the source, [content] is the rendered
/// label, and [style] is the resolved [CheckboxStyle].
typedef RadioOptionBuilder =
    Widget Function(
      BuildContext context,
      bool selected,
      Widget content,
      CheckboxStyle style,
    );

/// Builds the widget for a horizontal rule.
///
/// [style] is the resolved [HrStyle], so a builder can follow the theme's
/// thickness and colour rather than restating them.
typedef HrBuilder = Widget Function(BuildContext context, HrStyle style);

/// Builds the widget for a blockquote.
///
/// [content] is the already-rendered quoted content, and [style] is the
/// resolved [BlockQuoteStyle] — reuse its colours rather than hard-coding your
/// own, so the quote still follows the theme.
typedef BlockQuoteBuilder =
    Widget Function(
      BuildContext context,
      Widget content,
      BlockQuoteStyle style,
    );

/// A builder function for the image.
///
/// [width] and [height] come from the image alt text when parsed as `WxH`
/// (for example `![100x200](url)`); otherwise they are null.
typedef ImageBuilder =
    Widget Function(
      BuildContext context,
      String imageUrl,
      double? width,
      double? height,
    );

/// What an inline builder is told about the construct it is rendering.
///
/// Every span-returning builder in this package receives one of these instead
/// of a positional argument list. That is the whole point of the shape: a
/// positional parameter cannot be added later without breaking every
/// consumer, and this package has already had to deprecate two builders over
/// exactly that. A field can be added here at any time and nothing that
/// compiles today stops compiling.
///
/// The type is `base`, so no code outside this package can implement it, and
/// each subclass is `final`. That is what makes "a new field is not a breaking
/// change" a guarantee rather than a hope — there is no consumer
/// implementation a new member could leave incomplete.
///
/// **The additive contract.** Every constructor parameter added from 1.3.0 on
/// is optional and defaulted, so a builder written against 1.3.0 keeps
/// compiling and keeps behaving the same. New *appearance* knobs go on
/// [LinkStyle] or [SourceTagStyle], not here. The meaning of an existing field
/// never changes.
abstract base class InlineBuildDetails {
  /// Creates the details common to every inline builder.
  const InlineBuildDetails({
    required this.context,
    required this.config,
    required this.style,
  });

  /// The element this construct is being built in.
  final BuildContext context;

  /// The configuration in force at this point in the document.
  ///
  /// Read [GptMarkdownConfig.scope] from it to tell a link in a table cell
  /// from one in ordinary content, and [GptMarkdownConfig.textDirection] or
  /// [GptMarkdownConfig.textScaler] when a widget of your own needs them.
  /// [TableBuilder] and [OrderedListBuilder] already take a whole config for
  /// the same reason.
  final GptMarkdownConfig config;

  /// The text style in effect for this construct, fully resolved.
  ///
  /// A builder never has to guess a default: this is what the construct would
  /// have been drawn with, its own style already applied over the surrounding
  /// one.
  final TextStyle style;
}

/// What the link builder is told about one `[label](url)` or autolink.
final class LinkBuildDetails extends InlineBuildDetails {
  /// Creates link details.
  const LinkBuildDetails({
    required super.context,
    required super.config,
    required super.style,
    required this.url,
    required this.label,
    required this.linkStyle,
    this.labelSpans = const <InlineSpan>[],
    this.isAutolink = false,
    this.onTap,
  });

  /// The link target, verbatim from the document — `/docs/a`,
  /// `https://x.dev`, `mailto:a@b.c`. Never resolved or normalised.
  final String url;

  /// The label as plain text.
  ///
  /// This is what [GptMarkdownConfig.onLinkTap] receives as its second
  /// argument. For an autolink it is the URL itself. It is **not** a link
  /// title — Markdown titles are not parsed yet, and when they are they arrive
  /// as a field of their own.
  final String label;

  /// The label, already parsed and styled with [style].
  ///
  /// The parse has happened by the time a builder runs, in the
  /// [MarkdownScope.linkLabel] scope, so `[**bold** link](url)` arrives as the
  /// spans that render it. An autolink's label is one plain run, deliberately:
  /// re-parsing a URL would let `ItalicMd` eat the underscores out of
  /// `https://example.com/a_b_c`.
  final List<InlineSpan> labelSpans;

  /// The resolved [LinkStyle] — colour, hover colour, decoration, thickness
  /// and weight, with [GptMarkdownTheme] fallbacks already applied.
  ///
  /// Passed alongside [style] so a builder can reach a value a [TextStyle]
  /// cannot carry. `hoverColor` is the one that exists today.
  final LinkStyle linkStyle;

  /// Whether the package found this as a bare URL rather than as `[…](…)`.
  final bool isAutolink;

  /// Invokes [GptMarkdownConfig.onLinkTap] for this link, or null when no
  /// handler is set.
  ///
  /// Hand it to [TappableTextSpan.onTap] — or to [defaultSpan], which does it
  /// for you — rather than calling `onLinkTap` yourself, so the arguments stay
  /// right when they change.
  final VoidCallback? onTap;

  /// [style] recoloured with [LinkStyle.hoverColor], for
  /// [TappableTextSpan.hoverStyle].
  TextStyle get hoverStyle => TextStyle(
    color: linkStyle.hoverColor,
    decorationColor: linkStyle.hoverColor,
  );

  /// Exactly what a link renders as when no builder is given.
  ///
  /// Returning this from [InlineLinkBuilder] is a no-op, which makes it the
  /// safe starting point: keep it, then change one thing.
  ///
  /// [style] replaces the style on the **container** span. It does not
  /// restyle the label, because [labelSpans] were already built with their own
  /// styles — bold inside a link stays bold, and a colour set here does not
  /// reach them. To recolour the label, rebuild it and pass [children]:
  ///
  /// ```dart
  /// inlineLinkBuilder: (link) => link.defaultSpan(
  ///   children: [TextSpan(text: link.label, style: link.style.copyWith(
  ///     color: link.url.startsWith('https://') ? null : Colors.orange,
  ///   ))],
  /// ),
  /// ```
  ///
  /// For a widget instead of a span, see [asWidgetSpan].
  InlineSpan defaultSpan({TextStyle? style, List<InlineSpan>? children}) {
    return LinkTextSpan.wrapping(
      children: children ?? labelSpans,
      url: url,
      linkStyle: linkStyle,
      style: style ?? this.style,
      hoverStyle: hoverStyle,
      onTap: onTap,
    );
  }

  /// [child] in a placeholder wrapped exactly the way the deprecated
  /// [LinkBuilder]'s result is, with [onTap] attached.
  ///
  /// The escape hatch for a link that genuinely has to be a widget. It cannot
  /// wrap across lines, is skipped by text selection, is one opaque character
  /// to the streaming reveal, and does not paint on iOS when nested inside
  /// another placeholder — prefer a span where the design allows.
  InlineSpan asWidgetSpan(
    Widget child, {
    PlaceholderAlignment alignment = PlaceholderAlignment.baseline,
    TextBaseline? baseline = TextBaseline.alphabetic,
  }) {
    final tap = onTap;
    return scaledWidgetSpan(
      config: config,
      alignment: alignment,
      baseline: baseline,
      child: tap == null ? child : GestureDetector(onTap: tap, child: child),
    );
  }
}

/// What the source-tag builder is told about one `[1]` citation chip.
final class SourceTagBuildDetails extends InlineBuildDetails {
  /// Creates source-tag details.
  const SourceTagBuildDetails({
    required super.context,
    required super.config,
    required super.style,
    required this.id,
    required this.sourceTagStyle,
    this.onTap,
  });

  /// The tag's contents — `1` for `[1]`.
  final String id;

  /// The resolved [SourceTagStyle] — fill, text style, size, shape and
  /// padding, with theme and defaults already folded in.
  final SourceTagStyle sourceTagStyle;

  /// Invokes [GptMarkdownConfig.onSourceTagTap] with [id], or null when no
  /// handler is set.
  final VoidCallback? onTap;

  /// The chip the package would have built, as a placeholder span.
  ///
  /// Still a [WidgetSpan]: the default chip is a sized, filled circle with the
  /// number scaled to fit, and there is no text-only equivalent of that.
  /// Return this when you only want to wrap or decorate the stock chip.
  InlineSpan defaultSpan() => defaultSourceTagSpan(this);

  /// [chip] in a placeholder aligned and padded exactly the way the default
  /// chip is — centred on the line box, with [SourceTagStyle.padding] around
  /// it — and wired to [onTap].
  ///
  /// This is the realistic migration for a custom citation chip: it reproduces
  /// the wrapping `sourceTagSpan` applies, which a hand-written [WidgetSpan]
  /// does not.
  InlineSpan asWidgetSpan(
    Widget chip, {
    PlaceholderAlignment alignment = PlaceholderAlignment.middle,
  }) {
    final tap = onTap;
    return scaledWidgetSpan(
      config: config,
      alignment: alignment,
      baseline: null,
      child: Padding(
        padding: sourceTagStyle.padding ?? const EdgeInsets.all(2),
        child: tap == null ? chip : GestureDetector(onTap: tap, child: chip),
      ),
    );
  }
}

/// Builds the span for one `[label](url)` link or autolink.
///
/// [details] carries the URL, the already-parsed label spans, the resolved
/// [TextStyle] and [LinkStyle], and a tap callback already bound to
/// [GptMarkdown.onLinkTap] — see [LinkBuildDetails]. It is the only parameter
/// this signature will ever have: new information arrives as a new field on
/// [LinkBuildDetails], never as a new argument here.
///
/// Return [LinkBuildDetails.defaultSpan] to keep the stock link and change
/// only its style, a [LinkTextSpan] to build it yourself, or
/// [LinkBuildDetails.asWidgetSpan] when a widget is genuinely required:
///
/// ```dart
/// inlineLinkBuilder: (link) => LinkTextSpan.wrapping(
///   children: [
///     if (link.url.endsWith('.pdf'))
///       const WidgetSpan(child: Icon(Icons.picture_as_pdf, size: 14)),
///     ...link.labelSpans,
///   ],
///   url: link.url,
///   linkStyle: link.linkStyle,
///   style: link.style,
///   hoverStyle: link.hoverStyle,
///   onTap: link.onTap,
/// ),
/// ```
///
/// Do **not** attach a [GestureRecognizer] to a span that has children and no
/// text of its own — it can never fire. Use [TappableTextSpan]: the package
/// resolves those by text range at the paragraph, which works for a whole
/// subtree, covers a [WidgetSpan] inside the label, and owns the recognizer's
/// lifetime.
///
/// Returning an [InlineSpan] rather than a [Widget] is what keeps a link on
/// the text baseline, wrapping across lines, selectable, visible to the
/// streaming reveal, and painting on iOS inside another placeholder.
typedef InlineLinkBuilder = InlineSpan Function(LinkBuildDetails details);

/// Builds the span for one `[1]` citation chip.
///
/// [details] carries the chip's contents, the resolved [TextStyle] and
/// [SourceTagStyle], and a tap callback already bound to
/// [GptMarkdown.onSourceTagTap] — see [SourceTagBuildDetails]. As with
/// [InlineLinkBuilder], new information arrives as a new field, never as a new
/// argument.
///
/// The stock chip is a genuine widget, so [SourceTagBuildDetails.defaultSpan]
/// returns a [WidgetSpan] and [SourceTagBuildDetails.asWidgetSpan] wraps one
/// of your own with the same alignment, padding and tap handling:
///
/// ```dart
/// inlineSourceTagBuilder: (tag) => tag.asWidgetSpan(
///   CitationChip(id: tag.id, style: tag.sourceTagStyle),
/// ),
/// ```
///
/// Returning a [TappableTextSpan] instead keeps the citation on the baseline,
/// wrapping and selectable, and lets it appear inside a link label without
/// nesting one placeholder in another:
///
/// ```dart
/// inlineSourceTagBuilder: (tag) => TappableTextSpan(
///   text: '[${tag.id}]',
///   onTap: tag.onTap,
///   style: tag.style.copyWith(
///     fontFeatures: const [FontFeature.superscripts()],
///   ),
/// ),
/// ```
typedef InlineSourceTagBuilder =
    InlineSpan Function(SourceTagBuildDetails details);

/// A configuration class for the GPT Markdown component.
///
/// The [GptMarkdownConfig] class is used to configure the GPT Markdown component.
/// It takes a [style] parameter to set the style of the text,
/// a [textDirection] parameter to set the direction of the text,
/// and an optional [onLinkTap] parameter to handle link clicks.
class GptMarkdownConfig {
  const GptMarkdownConfig({
    this.style,
    this.textDirection = TextDirection.ltr,
    this.onLinkTap,
    this.textAlign,
    this.textScaler,
    this.latexWorkaround,
    this.latexBuilder,
    this.followLinkColor = false,
    this.codeBuilder,
    this.inlineSourceTagBuilder,
    @Deprecated('Use inlineSourceTagBuilder. Will be removed in 2.0.0.')
    this.sourceTagBuilder,
    this.inlineDirectives,
    this.inlineCodeBuilder,
    @Deprecated('Use inlineCodeBuilder. Will be removed in 2.0.0.')
    this.highlightBuilder,
    this.orderedListBuilder,
    this.unOrderedListBuilder,
    this.blocksRenderDirectly = false,
    this.inlineLinkBuilder,
    @Deprecated('Use inlineLinkBuilder. Will be removed in 2.0.0.')
    this.linkBuilder,
    this.imageBuilder,
    this.maxLines,
    this.overflow,
    this.components,
    this.inlineComponents,
    this.inlinePatterns,
    this.blockComponents,
    this.tableBuilder,
    this.inlineCodeStyle,
    this.styleSheet,
    this.blockQuoteBuilder,
    this.headingBuilder,
    this.checkboxBuilder,
    this.radioOptionBuilder,
    this.hrBuilder,
    this.onCheckboxChanged,
    this.onCodeCopy,
    this.onImageTap,
    this.onSourceTagTap,
    this.autolink = true,
    this.autolinkSchemes = const <String>{},
    this.scope = MarkdownScope.content,
  });

  static final _registries = Expando<MarkdownBlockRegistry>();
  static final _renderers = Expando<Map<String, MarkdownBlockBuilder>>();

  /// Components must be treated as immutable after registration.
  MarkdownBlockRegistry? get blockRegistry {
    final components = blockComponents;
    if (components == null || components.isEmpty) return null;
    return _registries[components] ??= MarkdownBlockRegistry(
      components.map((component) => component.syntax),
    );
  }

  Map<String, MarkdownBlockBuilder> get blockRenderers {
    final components = blockComponents;
    if (components == null || components.isEmpty) return const {};
    return _renderers[components] ??= {
      for (final component in components)
        component.syntax.type: component.builder,
    };
  }

  /// The direction of the text.
  final TextDirection textDirection;

  /// The style of the text.
  final TextStyle? style;

  /// The alignment of the text.
  final TextAlign? textAlign;

  /// The text scaler.
  final TextScaler? textScaler;

  /// The callback function to handle link clicks.
  final void Function(String url, String title)? onLinkTap;

  /// The LaTeX workaround.
  final String Function(String tex)? latexWorkaround;

  /// The LaTeX builder.
  final LatexBuilder? latexBuilder;

  /// Builds the span for a `[1]` citation chip, replacing the default chip.
  ///
  /// Wins over [sourceTagBuilder] when both are set.
  final InlineSourceTagBuilder? inlineSourceTagBuilder;

  /// Builds a widget for a `[1]` citation chip.
  ///
  /// Used only when [inlineSourceTagBuilder] is null. The result is wrapped
  /// in a [WidgetSpan] centred on the line box, which is the shape that made
  /// this hook a problem — and it is handed an empty [TextStyle] rather than
  /// the resolved one.
  @Deprecated('Use inlineSourceTagBuilder. Will be removed in 2.0.0.')
  final SourceTagBuilder? sourceTagBuilder;

  /// Host-defined inline regions the parser must not look inside.
  ///
  /// See [InlineDirective].
  final List<InlineDirective>? inlineDirectives;

  /// Whether to follow the link color.
  final bool followLinkColor;

  /// The code builder.
  final CodeBlockBuilder? codeBuilder;

  /// The Ordered List builder.
  final OrderedListBuilder? orderedListBuilder;

  /// The Unordered List builder.
  final UnOrderedListBuilder? unOrderedListBuilder;

  /// The maximum number of lines.
  final int? maxLines;

  /// The overflow.
  final TextOverflow? overflow;

  /// Builds the span for inline `` `code` ``, overriding the default chip.
  final InlineCodeBuilder? inlineCodeBuilder;

  /// Builds a widget for inline `` `code` ``.
  ///
  /// Used only when [inlineCodeBuilder] is null. The result is wrapped in a
  /// baseline-aligned [WidgetSpan], which is the shape that made this hook a
  /// problem — prefer [inlineCodeBuilder], or [GptMarkdown.inlineCodeStyle]
  /// when you only want to restyle.
  @Deprecated('Use inlineCodeBuilder. Will be removed in 2.0.0.')
  final HighlightBuilder? highlightBuilder;

  /// Whether a block construct is rendered as a sibling widget rather than as
  /// a placeholder inside a paragraph.
  ///
  /// A block's own content normally opts out of text scaling, because the
  /// paragraph holding its placeholder has already scaled it — scaling twice
  /// was the bug that produced overlapping text. Lift the block out of the
  /// paragraph and there is nothing left to scale it, so it has to scale
  /// itself. Set by the layout, not by a consumer.
  final bool blocksRenderDirectly;

  /// Builds the span for a link, replacing the default rendering.
  ///
  /// Wins over [linkBuilder] when both are set.
  final InlineLinkBuilder? inlineLinkBuilder;

  /// Builds a widget for a link.
  ///
  /// Used only when [inlineLinkBuilder] is null. The result is wrapped in a
  /// [WidgetSpan], which is the shape that made this hook a problem — prefer
  /// [inlineLinkBuilder], or [GptMarkdown.styleSheet]'s [LinkStyle] when you
  /// only want to restyle.
  @Deprecated('Use inlineLinkBuilder. Will be removed in 2.0.0.')
  final LinkBuilder? linkBuilder;

  /// The image builder.
  final ImageBuilder? imageBuilder;

  /// The list of components.
  final List<MarkdownComponent>? components;

  /// The list of inline components.
  final List<MarkdownComponent>? inlineComponents;

  /// App-specific inline syntaxes. See [GptMarkdown.inlinePatterns].
  final List<InlinePattern>? inlinePatterns;

  /// Modern block syntax extensions. Legacy component lists take precedence.
  final List<MarkdownBlockComponent>? blockComponents;

  /// Overrides the themed inline `code` style for this widget only.
  final InlineCodeStyle? inlineCodeStyle;

  /// Per-component appearance for this widget. See [GptMarkdown.styleSheet].
  final GptMarkdownStyleSheet? styleSheet;

  /// Replaces the whole blockquote widget.
  final BlockQuoteBuilder? blockQuoteBuilder;

  /// Replaces the whole heading widget.
  final HeadingBuilder? headingBuilder;

  /// Replaces the whole checkbox row.
  final CheckboxBuilder? checkboxBuilder;

  /// Replaces the whole radio row.
  final RadioOptionBuilder? radioOptionBuilder;

  /// Replaces the horizontal rule.
  final HrBuilder? hrBuilder;

  /// Called when a task-list checkbox is tapped.
  ///
  /// Only fires when `CheckboxStyle.interactive` is set — Markdown checkboxes
  /// are a rendering of the source text, so they are read-only by default.
  final void Function(bool value)? onCheckboxChanged;

  /// Called with the code after a code block's copy button is used.
  final void Function(String code)? onCodeCopy;

  /// Called with the image URL when an image is tapped.
  final void Function(String url)? onImageTap;

  /// Called with the tag content when a `[1]` citation chip is tapped.
  final void Function(String content)? onSourceTagTap;

  /// Whether bare URLs, `www.` hosts, emails and `<...>` autolinks are linked.
  final bool autolink;

  /// Extra URL schemes linked without `<>`. See [GptMarkdown.autolinkSchemes].
  final Set<String> autolinkSchemes;

  /// The nesting context the current text is being rendered in.
  ///
  /// Set by the components that recurse — [ATagMd] renders its label with
  /// [MarkdownScope.linkLabel], [TableMd] renders cells with
  /// [MarkdownScope.tableCell], and so on. Components whose
  /// [MarkdownComponent.scopes] excludes the current scope are skipped.
  final MarkdownScope scope;

  /// The table builder.
  final TableBuilder? tableBuilder;

  /// A copy of the configuration with the specified parameters.
  GptMarkdownConfig copyWith({
    TextStyle? style,
    TextDirection? textDirection,
    final void Function(String url, String title)? onLinkTap,
    final TextAlign? textAlign,
    final TextScaler? textScaler,
    final String Function(String tex)? latexWorkaround,
    final LatexBuilder? latexBuilder,
    final InlineSourceTagBuilder? inlineSourceTagBuilder,
    @Deprecated('Use inlineSourceTagBuilder. Will be removed in 2.0.0.')
    final SourceTagBuilder? sourceTagBuilder,
    final List<InlineDirective>? inlineDirectives,
    final bool? followLinkColor,
    final CodeBlockBuilder? codeBuilder,
    final int? maxLines,
    final TextOverflow? overflow,
    final InlineCodeBuilder? inlineCodeBuilder,
    @Deprecated('Use inlineCodeBuilder. Will be removed in 2.0.0.')
    final HighlightBuilder? highlightBuilder,
    final bool? blocksRenderDirectly,
    final InlineLinkBuilder? inlineLinkBuilder,
    @Deprecated('Use inlineLinkBuilder. Will be removed in 2.0.0.')
    final LinkBuilder? linkBuilder,
    final ImageBuilder? imageBuilder,
    final OrderedListBuilder? orderedListBuilder,
    final UnOrderedListBuilder? unOrderedListBuilder,
    final List<MarkdownComponent>? components,
    final List<MarkdownComponent>? inlineComponents,
    final List<InlinePattern>? inlinePatterns,
    final List<MarkdownBlockComponent>? blockComponents,
    final TableBuilder? tableBuilder,
    final InlineCodeStyle? inlineCodeStyle,
    final GptMarkdownStyleSheet? styleSheet,
    final BlockQuoteBuilder? blockQuoteBuilder,
    final HeadingBuilder? headingBuilder,
    final CheckboxBuilder? checkboxBuilder,
    final RadioOptionBuilder? radioOptionBuilder,
    final HrBuilder? hrBuilder,
    final void Function(bool value)? onCheckboxChanged,
    final void Function(String code)? onCodeCopy,
    final void Function(String url)? onImageTap,
    final void Function(String content)? onSourceTagTap,
    final bool? autolink,
    final Set<String>? autolinkSchemes,
    final MarkdownScope? scope,
  }) {
    return GptMarkdownConfig(
      style: style ?? this.style,
      textDirection: textDirection ?? this.textDirection,
      onLinkTap: onLinkTap ?? this.onLinkTap,
      textAlign: textAlign ?? this.textAlign,
      textScaler: textScaler ?? this.textScaler,
      latexWorkaround: latexWorkaround ?? this.latexWorkaround,
      latexBuilder: latexBuilder ?? this.latexBuilder,
      followLinkColor: followLinkColor ?? this.followLinkColor,
      codeBuilder: codeBuilder ?? this.codeBuilder,
      inlineSourceTagBuilder:
          inlineSourceTagBuilder ?? this.inlineSourceTagBuilder,
      // ignore: deprecated_member_use_from_same_package
      sourceTagBuilder: sourceTagBuilder ?? this.sourceTagBuilder,
      inlineDirectives: inlineDirectives ?? this.inlineDirectives,
      maxLines: maxLines ?? this.maxLines,
      overflow: overflow ?? this.overflow,
      inlineCodeBuilder: inlineCodeBuilder ?? this.inlineCodeBuilder,
      // ignore: deprecated_member_use_from_same_package
      highlightBuilder: highlightBuilder ?? this.highlightBuilder,
      blocksRenderDirectly: blocksRenderDirectly ?? this.blocksRenderDirectly,
      inlineLinkBuilder: inlineLinkBuilder ?? this.inlineLinkBuilder,
      // ignore: deprecated_member_use_from_same_package
      linkBuilder: linkBuilder ?? this.linkBuilder,
      imageBuilder: imageBuilder ?? this.imageBuilder,
      orderedListBuilder: orderedListBuilder ?? this.orderedListBuilder,
      unOrderedListBuilder: unOrderedListBuilder ?? this.unOrderedListBuilder,
      components: components ?? this.components,
      inlineComponents: inlineComponents ?? this.inlineComponents,
      inlinePatterns: inlinePatterns ?? this.inlinePatterns,
      blockComponents: blockComponents ?? this.blockComponents,
      tableBuilder: tableBuilder ?? this.tableBuilder,
      inlineCodeStyle: inlineCodeStyle ?? this.inlineCodeStyle,
      styleSheet: styleSheet ?? this.styleSheet,
      blockQuoteBuilder: blockQuoteBuilder ?? this.blockQuoteBuilder,
      headingBuilder: headingBuilder ?? this.headingBuilder,
      checkboxBuilder: checkboxBuilder ?? this.checkboxBuilder,
      radioOptionBuilder: radioOptionBuilder ?? this.radioOptionBuilder,
      hrBuilder: hrBuilder ?? this.hrBuilder,
      onCheckboxChanged: onCheckboxChanged ?? this.onCheckboxChanged,
      onCodeCopy: onCodeCopy ?? this.onCodeCopy,
      onImageTap: onImageTap ?? this.onImageTap,
      onSourceTagTap: onSourceTagTap ?? this.onSourceTagTap,
      autolink: autolink ?? this.autolink,
      autolinkSchemes: autolinkSchemes ?? this.autolinkSchemes,
      scope: scope ?? this.scope,
    );
  }

  /// A method to get a rich text widget from an inline span.
  ///
  /// Paragraphs that mix right-to-left text with two or more inline widgets
  /// (LaTeX, images, links) are rendered with [BidiText], which works around
  /// https://github.com/flutter/flutter/issues/54400 — the engine otherwise
  /// lays those inline widgets out left to right and they come out reversed.
  /// Everything else keeps using a plain [Text].
  Widget getRich(
    InlineSpan span, {
    bool isRoot = false,
    bool ambientScaling = false,
  }) {
    // A nested paragraph sits inside a `WidgetSpan`, and a paragraph lays its
    // inline children out in scaled space — it hands them `maxWidth / scale`
    // and multiplies the reported size back. A child that scales its own text
    // as well is counted twice, so nested paragraphs opt out.
    //
    // Passing `textScaler` here would defeat that: an explicit scaler on a
    // `Text` wins over the ambient `MediaQuery`, so the paragraph would scale
    // itself again despite the `withNoTextScaling` wrapper below.
    //
    // [ambientScaling] is the third case: a block lifted out of the paragraph
    // entirely. It has to scale, so it cannot opt out — but it must scale from
    // the ambient `MediaQuery`, which `GptMarkdown` has already set from
    // `textScaler`. Descendant blocks inside this paragraph must switch
    // blocksRenderDirectly off: their placeholder already supplies scaling.
    final scaleFromAmbient = ambientScaling && !isRoot;
    final effectiveScaler =
        scaleFromAmbient ? null : (isRoot ? textScaler : TextScaler.noScaling);
    final codeRuns = collectInlineCodeRuns(span);
    // A tap target is resolved by the paragraph's render object, so a
    // paragraph holding one has to go through BidiText. Missing this renders
    // the span as ordinary text with no tap and no error.
    final tapRuns = collectInlineTapRuns(span);
    final needsBidi = needsBidiPlaceholderFix(span);
    if (codeRuns.isEmpty && tapRuns.isEmpty && !needsBidi) {
      // Nothing to decorate and no placeholders to reorder — the stock widget
      // does the job, and stays the hot path for ordinary paragraphs.
      final Widget child = Text.rich(
        span,
        textDirection: textDirection,
        textScaler: effectiveScaler,
        textAlign: textAlign,
        maxLines: maxLines,
        overflow: overflow,
      );
      if (isRoot || scaleFromAmbient) {
        return child;
      }
      return MarkdownTextScaling.wrap(child, enabled: false);
    }
    final child = BidiText(
      span,
      bidiEnabled: needsBidi,
      inlineCodeRuns: codeRuns,
      inlineTapRuns: tapRuns,
      textDirection: textDirection,
      textScaler: effectiveScaler,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
    );
    if (isRoot || scaleFromAmbient) {
      return child;
    }
    return MarkdownTextScaling.wrap(child, enabled: false);
  }

  /// A method to check if the configuration is the same.
  bool isSame(GptMarkdownConfig other) {
    return style == other.style &&
        textAlign == other.textAlign &&
        textScaler == other.textScaler &&
        maxLines == other.maxLines &&
        overflow == other.overflow &&
        followLinkColor == other.followLinkColor &&
        scope == other.scope &&
        autolink == other.autolink &&
        blocksRenderDirectly == other.blocksRenderDirectly &&
        // Value types, so comparing them is cheap and a runtime change to any
        // of them regenerates the spans. Getting this wrong is silent: the
        // widget rebuilds with the new config and keeps rendering the old
        // output.
        setEquals(autolinkSchemes, other.autolinkSchemes) &&
        inlineCodeStyle == other.inlineCodeStyle &&
        styleSheet == other.styleSheet &&
        // `InlinePattern` holds a builder closure and has no value equality,
        // so this falls back to element identity. A consumer that rebuilds the
        // list inline pays a regeneration per rebuild — the safe direction.
        listEquals(inlinePatterns, other.inlinePatterns) &&
        listEquals(blockComponents, other.blockComponents) &&
        // Same reasoning: `MarkdownComponent` has no value equality, so these
        // compare by element identity. Swapping a component list at runtime
        // used to be ignored outright.
        listEquals(components, other.components) &&
        listEquals(inlineComponents, other.inlineComponents) &&
        // The rest are closures. They are recreated on every build by any
        // consumer that writes them inline, so comparing them would defeat the
        // cache entirely — a change to one of these needs a key or a remount.
        // latexWorkaround == other.latexWorkaround &&
        // latexBuilder == other.latexBuilder &&
        // sourceTagBuilder == other.sourceTagBuilder &&
        // inlineSourceTagBuilder == other.inlineSourceTagBuilder &&
        // codeBuilder == other.codeBuilder &&
        // orderedListBuilder == other.orderedListBuilder &&
        // unOrderedListBuilder == other.unOrderedListBuilder &&
        // linkBuilder == other.linkBuilder &&
        // inlineLinkBuilder == other.inlineLinkBuilder &&
        // imageBuilder == other.imageBuilder &&
        // inlineCodeBuilder == other.inlineCodeBuilder &&
        // onLinkTap == other.onLinkTap &&
        textDirection == other.textDirection;
  }
}
