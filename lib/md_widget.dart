part of 'gpt_markdown.dart';

/// It creates a markdown widget closed to each other.
///
/// Deprecated because it is the renderer for the legacy regex pipeline, which
/// [GptMarkdown] no longer selects by default. Building it directly costs the
/// three things the plusparse path provides: there is no incremental segment
/// cache, so the whole source is re-split and re-parsed on every text change;
/// there is no span-level reveal, because a reveal here falls back to
/// [StreamingMarkdown] re-slicing the source instead of restyling spans that
/// already exist; and there is no viewport laziness, because inside
/// [SliverGptMarkdown] this path becomes one `SliverToBoxAdapter` holding the
/// entire document.
///
/// It remains what the legacy path builds internally — [GptMarkdown] reaches
/// it whenever `components`, `inlineComponents` or `incremental: false` is
/// passed — so it keeps working unchanged until it is removed.
///
/// Before:
///
/// ```dart
/// MdWidget(
///   context,
///   '# Title',
///   true,
///   config: GptMarkdownConfig(style: Theme.of(context).textTheme.bodyMedium),
/// )
/// ```
///
/// After:
///
/// ```dart
/// GptMarkdown('# Title', style: Theme.of(context).textTheme.bodyMedium)
/// ```
@Deprecated('Use GptMarkdown instead. Will be removed in 2.0.0.')
class MdWidget extends StatefulWidget {
  const MdWidget(
    this.context,
    this.exp,
    this.includeGlobalComponents, {
    super.key,
    required this.config,
    this.isRoot = false,
  });

  /// isRoot
  final bool isRoot;

  /// The expression to be displayed.
  final String exp;
  final BuildContext context;

  /// Whether to include global components.
  final bool includeGlobalComponents;

  /// The configuration of the markdown widget.
  final GptMarkdownConfig config;

  @override
  State<MdWidget> createState() => _MdWidgetState();
}

class _MdWidgetState extends State<MdWidget> {
  List<InlineSpan> list = [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Colours are resolved while the spans are built, not while they are
    // painted: link colours come from `GptMarkdownTheme`, inline code and
    // headings from the ambient `ColorScheme`. So an inherited change — a
    // light/dark switch, a new `GptMarkdownTheme`, a text-direction change —
    // has to regenerate them. Without this the widget rebuilds happily and
    // keeps painting the previous theme's colours.
    //
    // This also covers the first build: `didChangeDependencies` runs after
    // `initState` and before `build`.
    _generate();
  }

  @override
  void didUpdateWidget(covariant MdWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.exp != widget.exp ||
        !oldWidget.config.isSame(widget.config)) {
      _generate();
    }
  }

  /// Regenerates the spans.
  ///
  /// Uses this element's own `context`, not [MdWidget.context]. Components
  /// resolve their colours through the context handed to them, and an
  /// inherited lookup registers the dependency on *that* element — so passing
  /// an ancestor's context would mean this widget is never notified when the
  /// theme changes.
  void _generate() {
    list = MarkdownComponent.generate(
      context,
      widget.exp,
      widget.config,
      widget.includeGlobalComponents,
    );
  }

  @override
  Widget build(BuildContext context) {
    return widget.config.getRich(
      TextSpan(children: list, style: widget.config.style?.copyWith()),
      isRoot: widget.isRoot,
    );
  }
}

/// A custom table column width.
///
/// Stateless, so every instance is interchangeable — and it declares that,
/// which matters more than it looks. `RenderTable.defaultColumnWidth`'s setter
/// short-circuits on `==` before calling `markNeedsLayout`. Without an
/// equality this class inherits identity, a fresh instance is allocated on
/// every build, the comparison always fails, and the table re-measures every
/// cell on every rebuild — a full extra layout pass per cell, for a table that
/// has not changed.
class CustomTableColumnWidth extends TableColumnWidth {
  /// Creates the default column width.
  const CustomTableColumnWidth();

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is CustomTableColumnWidth;

  @override
  int get hashCode => (CustomTableColumnWidth).hashCode;

  @override
  double maxIntrinsicWidth(Iterable<RenderBox> cells, double containerWidth) {
    double width = 50;
    for (var each in cells) {
      width = max(width, _measure(each));
      // The result is clamped to the container, and measuring more cells can
      // only make `width` larger — so once it is already at the clamp, the
      // rest of the column is a layout pass per cell for an answer that
      // cannot change.
      if (width >= containerWidth) {
        return containerWidth;
      }
    }
    return min(containerWidth, width);
  }

  /// The widest [cell] wants to be.
  ///
  /// Lays the cell out rather than asking for an intrinsic, for two reasons,
  /// both measured rather than assumed:
  ///
  ///  * `LayoutBuilder` cannot answer an intrinsic — producing one would mean
  ///    running its callback speculatively against constraints it has not been
  ///    given. It throws when asserts are on and quietly returns zero when they
  ///    are not, so a consumer whose cell holds one would get a crash in
  ///    development and a collapsed column in production.
  ///  * it is not even faster. `getMaxIntrinsicWidth` on a paragraph lays the
  ///    text out at unbounded width anyway, and the table still lays the cell
  ///    out afterwards for real — so it buys a second pass, not a cheaper one.
  ///    Measured at 5924 and 7039 us against 5263 and 4545 for four tables.
  ///
  /// The measurement is the price of sizing columns to their content.
  /// `TableStyle.columnWidth` opts out of it — a `FlexColumnWidth` divides the
  /// width proportionally and measures nothing.
  static double _measure(RenderBox cell) {
    cell.layout(const BoxConstraints(), parentUsesSize: true);
    return cell.size.width;
  }

  @override
  double minIntrinsicWidth(Iterable<RenderBox> cells, double containerWidth) {
    return 50;
  }
}
