part of '../gpt_markdown.dart';

/// The vertical space between two top-level blocks.
///
/// Approximates the "\n\n" paragraph break of the single-text pipeline: one
/// empty line of the default 1.15 line height. Scaled like the text it
/// separates, so the gap does not shrink relative to the type when a reader
/// raises their font size.
///
/// Shared, not duplicated: [_IncrementalMdView] puts it between its own
/// segments, and [GptMarkdown] hands the same value to [StreamingMarkdown] for
/// the seam between the settled prefix and the live tail. Those two have to
/// agree, or content moves when the seam does.
double blockGap(BuildContext context, GptMarkdownConfig config) {
  final scaler = config.textScaler ?? MediaQuery.textScalerOf(context);
  final fontSize = config.style?.fontSize ?? 14;
  final spacing = resolvedStyleSheet(context, config).blockSpacing;
  if (spacing == null) {
    return scaler.scale(fontSize * 1.15);
  }
  // The same arithmetic as [paragraphBreakSpan]: the text there is scaled
  // through its font size, so this scales the font size too rather than the
  // spacing, and the two agree under a non-linear scaler as well.
  return fontSize == 0 ? 0 : scaler.scale(fontSize) * spacing / fontSize;
}

/// Incremental (segment-cached) Markdown view, and the streaming reveal.
///
/// The document is split into top-level segments ([splitStreamSegments]) and
/// each renders as its own `Text.rich` in a column, cached by its source text.
/// Appending to the reply only rebuilds the tail segment — earlier segments
/// keep their exact widget instances, so Flutter skips rebuilding and
/// re-laying-out everything above (LaTeX, tables, lists…). Source updates still
/// compare prefixes and reconcile segment metadata; growing blocks still
/// require parsing. Animation ticks notify only the active reveal window.
///
/// ## The reveal
///
/// When [effect] is animating, this widget also owns the reveal: a ticker, a
/// [RevealEngine], and the per-frame restyling of the characters still
/// arriving.
///
/// It reveals over *spans*, not over the source. Slicing the Markdown source
/// and re-rendering the prefix every frame reparses the tail on every tick and
/// can only ever produce a hard cut — once there are spans the character
/// boundaries are gone. Here the segment's spans are rendered once per text
/// change and cached; a frame's whole job is restyling at most
/// [RevealEngine.fadeWindow] characters in the one segment the reveal head is
/// inside. Every segment behind it is already settled and returns its cached
/// widget untouched.
///
/// Segments beyond the head are not built at all, so the document ends where
/// the animation is and nothing appears below the reading position before it
/// is meant to be seen.
class _IncrementalMdView extends StatefulWidget {
  const _IncrementalMdView({
    required this.text,
    required this.config,
    this.effect = GptMarkdownAnimation.none,
    this.blockAnimation = GptMarkdownBlockAnimation.none,
    this.isStreaming = false,
    this.revealing = false,
    this.charactersPerSecond = 300,
    this.revealFadeSeconds = 0.25,
    this.blockAnimationDuration = const Duration(milliseconds: 200),
    this.blockAnimationCurve = Curves.easeOut,
    this.holdMathDollars = false,
    this.definitions,
  });

  final String text;
  final GptMarkdownConfig config;

  /// How each character arrives.
  final GptMarkdownAnimation effect;

  /// How a block containing a laid-out widget enters.
  final GptMarkdownBlockAnimation blockAnimation;

  /// Whether more text may still arrive.
  final bool isStreaming;

  /// Whether to reveal progressively at all. False renders the whole document
  /// at once, with no ticker and no per-character work.
  final bool revealing;

  final double charactersPerSecond;
  final double revealFadeSeconds;
  final Duration blockAnimationDuration;
  final Curve blockAnimationCurve;

  /// Whether `$…$` in the source is maths, so the reveal holds an unpaired
  /// `$` instead of showing it as prose it will not stay.
  final bool holdMathDollars;

  /// The link and footnote definitions of the document [text] belongs to,
  /// when [text] is only part of it — [SliverGptMarkdown] renders one view
  /// per segment. Null collects them from [text].
  final MarkdownDefinitions? definitions;

  @override
  State<_IncrementalMdView> createState() => _IncrementalMdViewState();
}

class _IncrementalMdViewState extends State<_IncrementalMdView>
    with SingleTickerProviderStateMixin {
  /// Rendered spans per position and source. Parsed ASTs can be shared by
  /// identical source, but widget spans may own GlobalKeys or controllers
  /// and must never be shared between simultaneous document positions.
  /// Spans, not widgets: the reveal
  /// restyles them every frame, and re-rendering to get them back would put
  /// the parser in the frame loop, which is the cost this whole design exists
  /// to avoid.
  final Map<(int, String), List<InlineSpan>> _spans = {};
  final Map<String, MdDocument> _documents = {};

  /// The definitions every segment was parsed against, and, per segment
  /// source, the labels its parse looked up. A changed definition re-parses
  /// only the segments that asked for it — while a reference definition
  /// streams in, its URL changes on every token.
  MarkdownDefinitions _definitions = MarkdownDefinitions.empty;
  final Map<String, Set<String>> _lookups = {};
  final Map<(int, String), int> _characterCounts = {};
  List<String> _segments = const [];
  List<List<InlineSpan>> _rendered = const [];
  List<int> _starts = const [];
  List<int> _counts = const [];
  bool _prepared = false;
  final _segmentCache = MarkdownSegmentCache();
  final List<ValueNotifier<int>> _segmentFrames = [];
  bool _motionEnabled = true;

  /// Fully settled segment paragraphs, built once and handed back by
  /// identity. The entrance wrapper is applied outside the cache: it is keyed
  /// by position. Repeated source has independent widget/controller ownership.
  final Map<(int, String), Widget> _settled = {};

  /// How long after the last chunk a reply still counts as arriving.
  ///
  /// Long enough to bridge the gap between tokens, short enough that a reader
  /// who stops to look does not wait for the document to become navigable.
  static const Duration _arrivalQuiet = Duration(milliseconds: 250);

  /// Whether text is still arriving by append — the streaming signature,
  /// observed rather than declared. `isStreaming` cannot answer this: it
  /// defaults to true and hosts routinely leave it on for a finished reply.
  bool _arriving = false;
  Timer? _arrivalTimer;

  /// Whether this reply has grown by append since it mounted — whether it is
  /// being streamed here, as opposed to shown whole. Sticky, unlike
  /// [_arriving], so a model pausing mid-formula does not flip the formula
  /// back to raw source; cleared when the text is replaced outright.
  ///
  /// Open formulas are completed only when this is set. `isStreaming` cannot
  /// gate it: it defaults to true, and a finished reply with a stray `\(` or
  /// an unpaired `$` would otherwise render the rest of its line as maths.
  bool _streamedHere = false;

  /// Plain text per segment, for the one semantics label a streaming reply
  /// exposes. Only ever populated while an assistive service is reading, so a
  /// reader who is not using one pays nothing for it.
  final Map<(int, String), String> _plainText = {};

  late RevealEngine _engine = RevealEngine(
    fadeSeconds: widget.revealFadeSeconds,
  );
  Ticker? _ticker;
  Duration _lastElapsed = Duration.zero;

  /// Rendered characters in the whole visible document, from the last build.
  /// The ticker aims at this; a build refreshes it before the next tick.
  int _total = 0;

  /// Whether the reveal should jump straight to the end on the next build.
  ///
  /// Deferred to a build because the target is a property of the *rendered*
  /// document, and nothing has been rendered yet when the state is created.
  /// Always set at mount: whatever the document already holds when this state
  /// is created — history, a re-opened conversation, a message a lazy list
  /// disposed and re-inflated mid-scroll — has been seen, and must appear
  /// whole rather than type itself out again. Only text that arrives *after*
  /// mount animates. (Streaming flags are no help here: `isStreaming` is
  /// commonly still true for a message scrolled back to during a live reply,
  /// and replaying its whole reveal from nothing blanked it for half a
  /// second.)
  bool _snapPending = true;

  /// Rendered characters already present when this state mounted.
  ///
  /// Segments that lie entirely below this were on screen before this element
  /// existed, so they skip their block entrance. Without it, every trip
  /// through a lazy list's cache boundary replayed every table and fence from
  /// opacity zero.
  int _mountOffset = 0;

  /// Releases the inline hold when the stream goes quiet without closing.
  ///
  /// A host that forgets to flip `isStreaming` off after the last chunk would
  /// otherwise leave the final characters behind an unclosed delimiter hidden
  /// forever — the hold only releases when more text arrives, and no more
  /// text is coming. Any new text disarms and re-arms it.
  Timer? _holdRelease;
  bool _holdExpired = false;

  /// High-water mark of the inline hold, as an offset into the whole source.
  ///
  /// The hold can ask to move backwards: `[the docs]` closes and reveals as
  /// prose, then `(` arrives and the whole construct is pending again.
  /// Un-showing text a reader has already read is worse than restyling it
  /// when the construct finally closes, so the hold only ever advances.
  int _holdHighWater = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Theme or other inherited data changed: cached spans and widgets baked in
    // the old values, so drop them.
    _dropCaches();
  }

  @override
  void didUpdateWidget(covariant _IncrementalMdView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.text != oldWidget.text &&
        widget.text.startsWith(oldWidget.text)) {
      _noteArrival();
    }
    if (widget.text != oldWidget.text ||
        widget.definitions != oldWidget.definitions ||
        widget.isStreaming != oldWidget.isStreaming ||
        widget.revealing != oldWidget.revealing ||
        widget.holdMathDollars != oldWidget.holdMathDollars) {
      _prepared = false;
      _holdRelease?.cancel();
      _holdRelease = null;
      _holdExpired = false;
    }
    if (!listEquals(
          oldWidget.config.blockComponents,
          widget.config.blockComponents,
        ) ||
        oldWidget.config.markdownHtml != widget.config.markdownHtml) {
      _documents.clear();
      _lookups.clear();
    }
    if (!oldWidget.config.isSame(widget.config)) {
      _dropCaches();
    }
    if (widget.revealFadeSeconds != oldWidget.revealFadeSeconds) {
      _engine = RevealEngine(fadeSeconds: widget.revealFadeSeconds);
    }

    if (!widget.revealing) {
      _stopTicking();
      _engine.snapToEnd(_total);
      return;
    }

    final extended =
        widget.text.length >= oldWidget.text.length &&
        widget.text.startsWith(oldWidget.text);
    if (!extended) {
      final limit = min(widget.text.length, oldWidget.text.length);
      var shared = 0;
      while (shared < limit &&
          widget.text.codeUnitAt(shared) == oldWidget.text.codeUnitAt(shared)) {
        shared += 1;
      }
      // An edit confined to the tail is a rewrite, not a new reply — the
      // `$…$` → `\(…\)` conversion completing, most likely. The reveal
      // carries on from where it is; resetting here blanked the whole message
      // for a frame and re-typed it on every equation that closed. The
      // tolerance matches the longest run the inline hold can be keeping
      // hidden ([markupDelimiterHold]), because that hold is exactly what
      // confines the rewrite to unseen text.
      //
      // A dollar formula closing is recognised whatever its length: an open
      // formula renders while it streams, so a long `$$…$$` block is on
      // screen, and resetting would retype the message around it.
      //
      // That holds when the formula is the very first thing in the reply,
      // too: there `shared` is 0, and requiring a shared prefix treated the
      // close as a new reply — the reveal reset to nothing and the whole
      // message, formula included, blanked for several frames. The rewrite
      // never shortens the text (`$$` and `\[` are the same length, and the
      // closer was just appended), which a replacement usually does.
      final dollarClosed =
          shared < oldWidget.text.length &&
          shared < widget.text.length &&
          widget.text.length >= oldWidget.text.length &&
          oldWidget.text.codeUnitAt(shared) == 0x24 /* $ */ &&
          widget.text.codeUnitAt(shared) == 0x5C /* \ */;
      final tailEdit =
          dollarClosed ||
          (shared > 0 &&
              oldWidget.text.length - shared <= markupDelimiterHold + 8);
      if (!tailEdit) {
        // A regenerate or a branch switch replaces the text rather than
        // extending it; continuing from the old offset would be meaningless,
        // and the new reply is genuinely unseen, so entrances play again.
        _engine.reset();
        _mountOffset = 0;
        _holdHighWater = 0;
        _streamedHere = false;
        _startTicking();
        return;
      }
    }

    if (widget.isStreaming) {
      _engine.clearFastForward();
      _startTicking();
    } else if (oldWidget.isStreaming) {
      // The reply finished. Nothing more is coming, so land the remainder
      // quickly instead of making the reader wait at the baseline rate.
      _engine.beginFastForward();
      _startTicking();
    }
  }

  @override
  void dispose() {
    _arrivalTimer?.cancel();
    _holdRelease?.cancel();
    _ticker?.dispose();
    for (final frame in _segmentFrames) {
      frame.dispose();
    }
    super.dispose();
  }

  /// Marks the reply as arriving, and schedules the moment it stops being so.
  void _noteArrival() {
    _arriving = true;
    _streamedHere = true;
    _arrivalTimer?.cancel();
    _arrivalTimer = Timer(_arrivalQuiet, () {
      if (!mounted) {
        return;
      }
      setState(() => _arriving = false);
    });
  }

  void _dropCaches() {
    _prepared = false;
    _spans.clear();
    _characterCounts.clear();
    _settled.clear();
    _plainText.clear();
  }

  void _startTicking() {
    if (_ticker?.isActive ?? false) {
      return;
    }
    _ticker ??= createTicker(_onTick);
    _lastElapsed = Duration.zero;
    _ticker!.start();
  }

  void _stopTicking() {
    if (_ticker?.isActive ?? false) {
      _ticker!.stop();
    }
  }

  void _onTick(Duration elapsed) {
    final dt = (elapsed - _lastElapsed).inMicroseconds / 1e6;
    _lastElapsed = elapsed;
    if (dt <= 0) {
      return;
    }
    final before = _engine.revealedFloor;
    // Characters still fading before this tick: those that finish during it
    // need one more build to drop their last step of style.
    final fadingBefore = _engine.fadingFrom;
    final visibleBefore = _visibleCount(before);
    final keepGoing = _engine.tick(dt, _total, widget.charactersPerSecond);
    final after = _engine.revealedFloor;
    final visibleAfter = _visibleCount(after);
    if (!keepGoing) _stopTicking();
    if (!_motionEnabled) return;
    // Only crossing a segment boundary changes the document's child list.
    // Inside a segment, notify just the active reveal/fade window.
    if (visibleBefore != visibleAfter) setState(() {});
    final from = max(0, _visibleCount(fadingBefore) - 1);
    for (var i = from; i < visibleAfter && i < _segmentFrames.length; i++) {
      _segmentFrames[i].value++;
    }
  }

  /// Number of segments whose start precedes the revealed offset.
  int _visibleCount(int revealed) {
    var low = 0;
    var high = _starts.length;
    while (low < high) {
      final mid = (low + high) >> 1;
      if (_starts[mid] < revealed) {
        low = mid + 1;
      } else {
        high = mid;
      }
    }
    return low;
  }

  /// The config blocks are rendered under.
  ///
  /// `blocksRenderDirectly` tells the renderer that a block will be lifted out
  /// of its paragraph — see [_unwrapBlock] — so the block's own content has to
  /// scale itself rather than rely on a paragraph that is no longer there.
  /// Gated on [_clamped], because a line budget is the one case a block still
  /// has to stay inside a paragraph.
  GptMarkdownConfig get _renderConfig => _clamped
      ? widget.config
      : widget.config.copyWith(blocksRenderDirectly: true);

  /// Whether a line budget applies to this document.
  ///
  /// `maxLines` is the obvious one. `overflow: TextOverflow.ellipsis` is the
  /// other, and it is easy to miss: Flutter truncates to a single line when an
  /// ellipsis is asked for and no line count is given, so an ellipsis on its
  /// own is a budget of one. Both have to keep the document in one paragraph —
  /// a budget cannot be shared across a column of them.
  bool get _clamped =>
      widget.config.maxLines != null ||
      widget.config.overflow == TextOverflow.ellipsis;

  List<InlineSpan> _spansFor(BuildContext context, String segment, int index) {
    return _spans[(index, segment)] ??= PlusparseRenderer.renderDocument(
      context,
      _documents[segment] ??= Plusparse.parse(
        segment,
        blockRegistry: widget.config.blockRegistry,
        html: widget.config.markdownHtml,
        definitions: _definitions.recording(_lookups[segment] = <String>{}),
      ),
      _renderConfig,
    );
  }

  /// Wraps [spans] as a root paragraph.
  ///
  /// `isRoot` matters: without it the text renders at `TextScaler.noScaling`
  /// and a raised system font size has no effect at all.
  /// The block widget [spans] is nothing but a wrapper around, or null.
  ///
  /// A block construct is emitted as a `WidgetSpan` so it can sit inside the
  /// single-paragraph pipeline. Here it does not need to: a segment is already
  /// its own child of the column, so wrapping the widget in a placeholder and
  /// a second `Text.rich` around it buys nothing and costs a great deal. The
  /// paragraph has to lay the placeholder's child out as its own `RenderBox`
  /// before it can shape a line, and the nested `Text.rich` is a second full
  /// text-shaping pass — measured at 145 µs per block against 5 µs for the
  /// widget on its own.
  ///
  /// Only a [BlockWidgetSpan] is unwrapped. An inline image or inline equation
  /// is also a lone `WidgetSpan` and must keep its paragraph — it is aligned
  /// against a text baseline that would no longer exist. The two are not
  /// distinguishable by shape, which is why the renderer marks them.
  Widget? _unwrapBlock(List<InlineSpan> spans) {
    if (spans.length != 1) {
      return null;
    }
    var span = spans.first;
    // The reveal wraps a block to keep its text reachable; the widget inside
    // has already had the reveal's transform applied, so unwrapping after the
    // fact is safe.
    if (span is RevealableSpan) {
      final children = span.children;
      if (children == null || children.length != 1) {
        return null;
      }
      span = children.first;
    }
    // A block quote carries its bar and inset in a plain `TextSpan` wrapper.
    if (span is TextSpan && span.text == null) {
      final children = span.children;
      if (children == null || children.length != 1) {
        return null;
      }
      span = children.first;
    }
    if (span is! BlockWidgetSpan) {
      return null;
    }
    // The flex wrapper `_blockSpan` adds is for the placeholder case: a
    // paragraph hands a widget span tight-ish constraints, and the flex is
    // what lets a block size to its content there rather than claim the full
    // width — stripping it made a bullet list four times wider. A column
    // child already gets loose constraints, so here the wrapper resolves to
    // the same size and only adds two render objects for paint to walk on
    // every frame. `bare` is the same block without it.
    return span.bare ?? span.child;
  }

  /// Every block in [spans], if that is *all* [spans] holds.
  ///
  /// A list is one segment of many blocks — one per item — separated by the
  /// line breaks that used to do the spacing inside a paragraph. Stacking them
  /// gets each item out of its placeholder too, which is where most of a
  /// list's cost is.
  ///
  /// Returns null the moment anything that is not a block or a separator shows
  /// up, so a paragraph with an inline image in it is never mistaken for one.
  List<Widget>? _unwrapBlocks(List<InlineSpan> spans) {
    if (spans.length < 2) {
      return null;
    }
    final widgets = <Widget>[];
    for (final span in spans) {
      final block = _unwrapBlock(<InlineSpan>[span]);
      if (block != null) {
        widgets.add(block);
        continue;
      }
      // A separator: the "\n" or "\n\n" the renderer puts between blocks.
      // It carries no content, so dropping it loses nothing — the column
      // stacks what it separated.
      //
      // Recognised by what it holds, not by its shape. While the reveal is
      // fading it in, the same "\n" arrives rebuilt as a span with children.
      // Testing for a childless span rejected it, so a list the fade was still
      // passing over fell back to one paragraph of placeholders — a few pixels
      // taller — and everything below jumped up when the fade moved on.
      if (span is TextSpan &&
          span.toPlainText(includeSemanticsLabels: false).trim().isEmpty) {
        continue;
      }
      return null;
    }
    return widgets.length < 2 ? null : widgets;
  }

  Widget _paragraph(List<InlineSpan> spans) {
    // A line budget is the one thing a column of widgets cannot honour: N
    // paragraphs cannot share one budget, so a clamped preview would get N
    // times its allowance. Keep the single-paragraph path for those.
    if (!_clamped) {
      final block = _unwrapBlock(spans);
      if (block != null) {
        return block;
      }
      final blocks = _unwrapBlocks(spans);
      if (blocks != null) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: blocks,
        );
      }
    }
    return _richParagraph(spans);
  }

  Widget _richParagraph(List<InlineSpan> spans) => widget.config.getRich(
    TextSpan(children: spans, style: widget.config.style?.copyWith()),
    isRoot: true,
  );

  /// Whether the character reveal cannot animate this segment's content, so a
  /// block entrance has to stand in for it.
  ///
  /// The renderer wraps block-level constructs — headings, lists, quotes,
  /// tables, fences, block maths, rules, images — in widget spans, and a
  /// widget span is one opaque character to the reveal. Those arrive whole
  /// however the reveal is configured, which is a step change in layout unless
  /// something eases them in.
  ///
  /// The test is whether any *text* survives to be revealed, not whether a
  /// widget is present anywhere. A paragraph holding a link or inline maths
  /// contains a widget span too, but its prose still reveals character by
  /// character — giving it an entrance as well would play two animations over
  /// the same content. Measured across every construct the renderer emits,
  /// content the reveal can reach carries an order of magnitude more text than
  /// placeholders, and content it cannot carries essentially none.
  static bool _isAtomic(List<InlineSpan> spans) {
    var text = 0;
    var placeholders = 0;
    void walk(InlineSpan span) {
      // A revealable block publishes the text inside its widget; that text is
      // what the reveal will animate, so it is what decides this. Walking its
      // rendered children instead would find only the opaque widget and
      // conclude — wrongly — that a heading or a list item cannot be revealed.
      if (span is RevealableSpan) {
        span.content.forEach(walk);
        return;
      }
      if (span is! TextSpan) {
        placeholders += 1;
        return;
      }
      text += span.text?.length ?? 0;
      span.children?.forEach(walk);
    }

    spans.forEach(walk);
    return placeholders > 0 && text <= placeholders;
  }

  /// The segments to show, with the tail trimmed back to markup that has
  /// finished arriving.
  ///
  /// A construct is literal text until its closing delimiter lands, so
  /// revealing characters the moment they arrive means showing them in the
  /// wrong form and restyling them a moment later — `` `npm install` `` turns
  /// monospace after the reader has already read it, and the line reflows
  /// around the chip. Holding the head behind the unterminated construct costs
  /// a little latency and means every character is final when it appears.
  ///
  /// Maths is the exception: an open formula is closed for the parser and
  /// renders as far as it has arrived ([completeOpenMath]), so an equation
  /// grows with the stream instead of appearing whole when its closer lands.
  /// The renderer draws incomplete input, and the completion holds back a
  /// command name still being typed, so no cut paints raw TeX.
  ///
  /// Only the last segment can be incomplete, and only while more is coming.
  /// A fence is left alone: it is opaque to begin with, and
  /// [splitStreamSegments] already keeps it whole.
  List<String> _visibleSegments(String source, List<String> segments) {
    if (!widget.isStreaming || segments.isEmpty) {
      return segments;
    }
    final last = segments.last;
    // Custom blocks own their incomplete-input policy; inline delimiters in
    // their opaque bodies must never be held or completed by the Markdown
    // reveal. Asked only when it could matter: matching is not free, and it
    // runs on every rebuild.
    bool isCustomBlock() =>
        widget.config.blockRegistry?.match(last.split('\n'), 0) != null;
    final revealing = widget.revealing && !_holdExpired;
    if (revealing && isCustomBlock()) {
      return segments;
    }
    List<String> withTail(String tail) => [
      ...segments.sublist(0, segments.length - 1),
      if (tail.trim().isNotEmpty) tail,
    ];
    if (!_holdExpired) {
      // A fence whose opening line is still arriving waits for the whole
      // line. Its info string is the code block's language label: shown
      // early, the label read `Code`, then `d`, `da`, `dart` as it streamed.
      final opener = _partialFenceOpener(last);
      if (opener != null) {
        _armHoldRelease();
        return withTail(last.substring(0, opener));
      }
    }
    // An open fence streams as itself — its backticks are not inline
    // delimiters, and its body must not be withheld. Except its closer while
    // it arrives: a lone ` or `` on the last line is the fence closing, not
    // code, and shown it flashed as a stray backtick under the last line.
    if (_hasOpenFence(last)) {
      final lineStart = last.lastIndexOf('\n') + 1;
      if (!_holdExpired && _fenceRun.hasMatch(last.substring(lineStart))) {
        _armHoldRelease();
        return withTail(last.substring(0, lineStart));
      }
      return segments;
    }
    if (widget.blockAnimation != GptMarkdownBlockAnimation.none &&
        !_holdExpired) {
      // A table still gaining rows waits until it is whole. Its entrance
      // plays once, when it first appears — shown as soon as its header
      // formed, the entrance animated a header alone and every row after it
      // landed instantly, so the animation was barely seen. A table that
      // stops growing is released by the quiet-stream timer.
      final table = _openTableStart(last);
      if (table != null) {
        _armHoldRelease();
        return withTail(last.substring(0, table));
      }
    }
    // Fences that have already closed are opaque to the inline scanner too:
    // only the prose after the last one is scanned, or a closed fence's
    // backticks would be read as inline code and the prose after it would
    // stream unheld.
    final scanFrom = _afterLastFence(last);
    final math = _streamedHere
        ? completeOpenMath(
            last.substring(scanFrom),
            dollarsAreMath: widget.holdMathDollars,
          )
        : null;
    final mathStart = math == null ? last.length : scanFrom + math.start;
    String completedTail() => last.substring(0, mathStart) + math!.completed;

    if (!revealing) {
      return math == null || isCustomBlock()
          ? segments
          : withTail(completedTail());
    }
    // Block maths with nothing drawable yet waits, rather than flashing the
    // bare `\[`.
    if (math == null &&
        last.trimLeft().startsWith(r'\[') &&
        !last.contains(r'\]')) {
      _armHoldRelease();
      return segments.sublist(0, segments.length - 1);
    }
    // Everything before an open formula follows the usual hold.
    var safe =
        scanFrom +
        inlineSafeLength(
          last.substring(scanFrom, mathStart),
          holdMathDollars: widget.holdMathDollars,
          html: widget.config.markdownHtml,
        );
    // The hold never moves backwards. Offsets are kept against the whole
    // source so the mark survives the tail segment closing and a new one
    // opening.
    final tailStart = source.lastIndexOf(last);
    if (tailStart >= 0) {
      final floor = _holdHighWater - tailStart;
      if (floor > safe) {
        safe = min(floor, last.length);
      }
      // Never into an open formula: its source is never shown raw.
      safe = min(safe, mathStart);
      _holdHighWater = tailStart + safe;
    }
    if (math != null && safe >= mathStart) {
      return withTail(completedTail());
    }
    if (safe >= last.length) {
      return segments;
    }
    _armHoldRelease();
    return withTail(last.substring(0, safe));
  }

  /// Adopts [definitions], dropping every cached parse and render that looked
  /// up a label whose definition changed.
  void _updateDefinitions(MarkdownDefinitions definitions) {
    if (definitions == _definitions) {
      return;
    }
    final changed = definitions.changedKeys(_definitions);
    _definitions = definitions;
    final stale = <String>{
      for (final entry in _lookups.entries)
        if (entry.value.any(changed.contains)) entry.key,
    };
    if (stale.isEmpty) {
      return;
    }
    _documents.removeWhere((key, _) => stale.contains(key));
    _lookups.removeWhere((key, _) => stale.contains(key));
    bool hit((int, String) key) => stale.contains(key.$2);
    _spans.removeWhere((key, _) => hit(key));
    _characterCounts.removeWhere((key, _) => hit(key));
    _settled.removeWhere((key, _) => hit(key));
    _plainText.removeWhere((key, _) => hit(key));
  }

  /// Arms the quiet-stream release, once per stretch of unchanged text.
  void _armHoldRelease() {
    _holdRelease ??= Timer(const Duration(milliseconds: 1500), () {
      if (mounted) {
        setState(() {
          _holdExpired = true;
          _prepared = false;
        });
      }
    });
  }

  /// Where the fence opener on [segment]'s last, still-arriving line begins,
  /// or null.
  ///
  /// Only an opener: a line inside an already-open fence is code.
  static int? _partialFenceOpener(String segment) {
    final lineStart = segment.lastIndexOf('\n') + 1;
    final line = segment.substring(lineStart);
    if (fenceOpen(unquoted(line)) == null) return null;
    final before = lineStart == 0 ? '' : segment.substring(0, lineStart - 1);
    if (before.isNotEmpty && openFenceAfter(before.split('\n')) != null) {
      return null;
    }
    return lineStart;
  }

  /// Where a pipe table that runs to the end of [segment] begins, or null.
  ///
  /// The table has its delimiter row and every line after its header is a
  /// table row, so more rows may still be coming. Text after the table means
  /// it is finished.
  static int? _openTableStart(String segment) {
    final lines = segment.split('\n');
    var offset = 0;
    for (var i = 0; i < lines.length - 1; i++) {
      final line = lines[i];
      if (line.trimLeft().startsWith('|') &&
          _tableDelimiter.hasMatch(lines[i + 1])) {
        final rest = lines.skip(i + 2);
        final open = rest.every(
          (l) => l.isEmpty || l.trimLeft().startsWith('|'),
        );
        return open ? offset : null;
      }
      offset += line.length + 1;
    }
    return null;
  }

  /// A line that is nothing but the start of a fence: backticks or tildes.
  static final RegExp _fenceRun = RegExp(r'^\s*(`+|~+)$');

  static final RegExp _tableDelimiter = RegExp(
    r'^\s*\|?\s*:?-+:?\s*(\|\s*:?-+:?\s*)*\|?\s*$',
  );

  /// Whether [segment] contains a fence that has not closed yet.
  ///
  /// The same fence rules [splitStreamSegments] and the parser use, so they
  /// all agree about what is inside a fence.
  static bool _hasOpenFence(String segment) =>
      openFenceAfter(segment.split('\n')) != null;

  /// Offset just past the last line that closes a fence in [segment], or 0.
  static int _afterLastFence(String segment) {
    FenceOpen? open;
    var depth = 0;
    var after = 0;
    var offset = 0;
    for (final line in segment.split('\n')) {
      final lineEnd = offset + line.length;
      final current = open;
      final lineDepth = quoteDepth(line);
      if (current != null && lineDepth >= depth) {
        if (isFenceClose(unquoted(line), current)) {
          open = null;
          after = lineEnd < segment.length ? lineEnd + 1 : segment.length;
        }
      } else {
        // A quoted fence also closes when its quote ends.
        if (current != null) {
          after = offset;
        }
        open = fenceOpen(unquoted(line));
        depth = lineDepth;
      }
      offset = lineEnd + 1;
    }
    return after;
  }

  /// Wraps [child] in its one-shot entrance, when the segment has one.
  ///
  /// Keyed by position, not by text: the tail's source changes with every
  /// chunk, and a text key would remount the entrance and replay it on every
  /// keystroke. Position is append-only while a reply grows, so the key holds
  /// exactly as long as the block does.
  ///
  /// A segment already on screen when this state mounted plays nothing: its
  /// reader has seen it, and a lazy list re-creating this state on scroll
  /// must not replay what did not move.
  Widget _entrance(int index, int start, List<InlineSpan> spans, Widget child) {
    if (widget.blockAnimation == GptMarkdownBlockAnimation.none ||
        start < _mountOffset ||
        !_isAtomic(spans)) {
      return child;
    }
    return GptMarkdownBlockEntrance(
      key: ValueKey<int>(index),
      animation: widget.blockAnimation,
      duration: widget.blockAnimationDuration,
      curve: widget.blockAnimationCurve,
      child: child,
    );
  }

  // Source work belongs to source updates, never to the animation clock.
  // Retain hidden spans too: visibility is not a cache invalidation signal.
  void _prepareDocument(BuildContext context) {
    if (_prepared) return;
    final patterns = widget.config.inlinePatterns;
    final source = patterns == null || patterns.isEmpty
        ? widget.text
        : maskInlinePatterns(
            widget.text,
            patterns,
            blockRegistry: widget.config.blockRegistry,
          );
    // One segment when a line budget is in play — see [_clamped]. Splitting
    // is what makes an append cheap, but every segment becomes its own
    // paragraph and the budget is applied to each, so a two-line preview of a
    // five paragraph reply rendered ten lines, silently, with no overflow mark
    // and no error. A clamped preview is a static excerpt rather than a
    // streaming reply, so it gives up incremental parsing to get its clamp
    // back.
    _segments = !_clamped
        ? _visibleSegments(
            source,
            _segmentCache.update(
              source,
              blockRegistry: widget.config.blockRegistry,
              html: widget.config.markdownHtml,
            ),
          )
        : <String>[source];
    _updateDefinitions(
      widget.definitions ??
          MarkdownDefinitions.collect(
            source,
            blockRegistry: widget.config.blockRegistry,
            html: widget.config.markdownHtml,
          ),
    );
    final live = _segments.toSet();
    _documents.removeWhere((key, _) => !live.contains(key));
    _lookups.removeWhere((key, _) => !live.contains(key));
    bool removed((int, String) key) =>
        key.$1 >= _segments.length || _segments[key.$1] != key.$2;
    _spans.removeWhere((key, _) => removed(key));
    _characterCounts.removeWhere((key, _) => removed(key));
    _settled.removeWhere((key, _) => removed(key));
    _plainText.removeWhere((key, _) => removed(key));
    _rendered = [];
    _starts = [];
    _counts = [];
    var offset = 0;
    for (var index = 0; index < _segments.length; index++) {
      final spans = _spansFor(context, _segments[index], index);
      final count = _characterCounts[(index, _segments[index])] ??=
          countRevealCharacters(spans);
      _rendered.add(spans);
      _starts.add(offset);
      _counts.add(count);
      offset += count;
    }
    _total = offset;
    final frameCount = widget.revealing ? _segments.length : 0;
    while (_segmentFrames.length < frameCount) {
      _segmentFrames.add(ValueNotifier<int>(0));
    }
    while (_segmentFrames.length > frameCount) {
      _segmentFrames.removeLast().dispose();
    }
    _prepared = true;
  }

  /// The colour `wave`'s crest lands in: the theme accent's hue, made vivid
  /// and kept clearly apart from the text in lightness.
  ///
  /// The accent as the theme gives it is not enough. Material 3's dark
  /// `primary` is a pastel by design — `#BCC2FF` against `#E4E1E9` text, a
  /// lightness gap of 0.03 — so a crest in it is near-white on near-white
  /// and `wave` reads as a plain fade. Light text gets a crest well below
  /// it, dark text one well above, and either way a saturated one.
  static Color _waveCrest(Color accent, Color text) {
    final hsl = HSLColor.fromColor(accent);
    final textLightness = HSLColor.fromColor(text).lightness;
    final lightness = textLightness > 0.5
        ? min(hsl.lightness, textLightness - 0.3).clamp(0.45, 1.0)
        : max(hsl.lightness, textLightness + 0.35).clamp(0.0, 0.6);
    return hsl
        .withSaturation(max(hsl.saturation, 0.75))
        .withLightness(lightness.toDouble())
        .toColor()
        .withValues(alpha: accent.a);
  }

  Widget _buildSegment(BuildContext context, int index) {
    final segment = _segments[index];
    final spans = _rendered[index];
    final start = _starts[index];
    final end = start + _counts[index];
    final revealing = widget.revealing && _motionEnabled;
    final settled = _engine.revealedFloor >= _total && !_engine.tailStillFading;
    final fading = revealing && widget.effect.animatesCharacters && !settled;
    final revealed = revealing ? _engine.revealedFloor : _total;
    // Exactly the characters still mid-entrance; everything behind them is
    // finished and its segment can hand back its cached settled widget.
    final settledBelow = fading ? _engine.fadingFrom : revealed;
    final Widget paragraph;
    if (end <= settledBelow) {
      paragraph = _settled[(index, segment)] ??= _paragraph(spans);
    } else {
      final textColor =
          widget.config.style?.color ??
          DefaultTextStyle.of(context).style.color ??
          Theme.of(context).colorScheme.onSurface;
      paragraph = _paragraph(
        applyReveal(
          spans: spans,
          revealed: revealed - start,
          effect: widget.effect,
          progressFor: (offset) => _engine.progressFor(start + offset),
          defaultColor: textColor,
          window: revealed - settledBelow,
          // What `wave`'s crest lands in, and what `blurIn` scales its blur
          // by. Read only while a segment is mid-reveal; a settled document
          // never gets here.
          accent: widget.effect == GptMarkdownAnimation.wave
              ? _waveCrest(Theme.of(context).colorScheme.primary, textColor)
              : null,
          fontSize:
              (widget.config.textScaler ?? MediaQuery.textScalerOf(context))
                  .scale(
                    widget.config.style?.fontSize ??
                        DefaultTextStyle.of(context).style.fontSize ??
                        14,
                  ),
        ),
      );
    }
    return _entrance(index, start, spans, paragraph);
  }

  @override
  Widget build(BuildContext context) {
    _prepareDocument(context);
    final gap = blockGap(context, widget.config);

    // A reader who has already seen this reply should not watch it type
    // itself out again — and the blocks it contains have no entrance left to
    // make.
    if (_snapPending) {
      _snapPending = false;
      _mountOffset = _total;
      _engine.snapToEnd(_total);
    }

    // Reduced motion is a preference about movement, not about content: the
    // document still renders, it just renders whole.
    final revealing =
        widget.revealing && !MediaQuery.disableAnimationsOf(context);
    // Once the last character has finished arriving there is nothing to style,
    // and the document should be exactly what it would have been without an
    // animation — one span per run, not one per character. Anything else keeps
    // a finished reply shaping as hundreds of separate runs, which moves its
    // wrapping and breaks a construct that styles a continuous stretch.
    _motionEnabled = revealing;
    final revealed = revealing ? _engine.revealedFloor : _total;
    final children = <Widget>[];
    final count = _visibleCount(revealed);
    for (var i = 0; i < count; i++) {
      // A segment that renders nothing — only reference definitions, or only
      // an HTML comment — takes no row. As an empty row it still received a
      // gap on each side, and a reply ending in a block of definitions showed
      // a large blank band where they were.
      if (_rendered[i].isEmpty) {
        continue;
      }
      children.add(
        revealing
            ? ValueListenableBuilder<int>(
                valueListenable: _segmentFrames[i],
                builder: (context, _, _) => _buildSegment(context, i),
              )
            : _buildSegment(context, i),
      );
    }

    // The ticker is armed here rather than in `initState` because the target
    // is a property of the *rendered* document: how many characters a source
    // produces is only known once it has been rendered, and on the first build
    // that has just happened for the first time. Arming it earlier would aim
    // the reveal at zero and stop it before it began.
    //
    // Starting a ticker during build is safe: it schedules a callback, it does
    // not call back synchronously.
    if (revealing &&
        (_engine.revealedFloor < _total || _engine.tailStillFading)) {
      _startTicking();
    } else if (!revealing) {
      _stopTicking();
    }

    final column = Column(
      mainAxisSize: MainAxisSize.min,
      // `spacing`, not a `SizedBox` between every pair. Interleaving gaps
      // doubles the number of children the framework has to walk and lay out
      // on every rebuild, and a streaming reply rebuilds on every chunk — a
      // long answer was reconciling ~560 children where ~280 carry content.
      spacing: gap,
      // start, not stretch: stretch forces every segment to the maximum width
      // the parent offers, so a two-word answer laid claim to the whole
      // column. The single-text pipeline sizes to its content, and so should
      // this — a paragraph that needs the width still takes it, because its
      // own text wraps into it.
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
    // Mid-reveal, the document is one live block of text rather than
    // something to navigate: every block already on screen otherwise
    // re-publishes its semantics on every frame, which is an announcement
    // storm for anyone listening and, because an attached assistive service
    // keeps the semantics pipeline alive, about half the per-chunk cost of a
    // long reply.
    //
    // The gate is text observably still arriving — a reveal in flight, or a
    // source that just grew by append and has not gone quiet. It is
    // deliberately *not* `isStreaming`, which defaults to true and which
    // hosts routinely leave on: tying it to the flag would collapse the
    // semantics of every document that never touches it.
    //
    // Nothing is hidden while it holds: the text so far is the label. The
    // structure — headings, links, list items as separate nodes — mounts the
    // moment the reveal lands.
    //
    // The wrappers stay in the tree either way; only their arguments flip.
    // Returning the bare column once the reply went quiet changed the widget
    // type at the root, so the whole document was torn down and re-inflated:
    // every block entrance re-armed and played again from nothing (a finished
    // table faded in a second time, a `growIn` block collapsed and regrew),
    // table scroll offsets reset, and SVG images blanked for a frame. A model
    // that paused for longer than [_arrivalQuiet] did it twice mid-stream.
    // With `container: false` and no label the `Semantics` adds no node, so
    // the settled tree is the same as with no wrapper at all.
    final animating =
        _arriving ||
        (revealing &&
            (_engine.revealedFloor < _total || _engine.tailStillFading));
    return Semantics(
      container: animating,
      label: animating && MediaQuery.accessibleNavigationOf(context)
          ? _semanticsLabel()
          : null,
      child: ExcludeSemantics(excluding: animating, child: column),
    );
  }

  /// The reply so far as one string, for [build]'s streaming semantics label.
  ///
  /// Per-segment text is cached alongside the spans it came from, so a chunk
  /// only converts the segment it landed in.
  String _semanticsLabel() {
    final buffer = StringBuffer();
    for (var index = 0; index < _segments.length; index++) {
      final text = _plainText[(index, _segments[index])] ??= TextSpan(
        children: _rendered[index],
      ).toPlainText(includeSemanticsLabels: false, includePlaceholders: false);
      if (text.trim().isEmpty) {
        continue;
      }
      if (buffer.isNotEmpty) {
        buffer.write('\n');
      }
      buffer.write(text);
    }
    return buffer.toString();
  }
}
