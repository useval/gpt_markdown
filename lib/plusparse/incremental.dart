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
  return scaler.scale((config.style?.fontSize ?? 14) * 1.15);
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
    )) {
      _documents.clear();
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
      final tailEdit =
          shared > 0 &&
          oldWidget.text.length - shared <= markupDelimiterHold + 8;
      if (!tailEdit) {
        // A regenerate or a branch switch replaces the text rather than
        // extending it; continuing from the old offset would be meaningless,
        // and the new reply is genuinely unseen, so entrances play again.
        _engine.reset();
        _mountOffset = 0;
        _holdHighWater = 0;
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
    final visibleBefore = _visibleCount(before);
    final keepGoing = _engine.tick(dt, _total, widget.charactersPerSecond);
    final after = _engine.revealedFloor;
    final visibleAfter = _visibleCount(after);
    if (!keepGoing) _stopTicking();
    if (!_motionEnabled) return;
    // Only crossing a segment boundary changes the document's child list.
    // Inside a segment, notify just the active reveal/fade window.
    if (visibleBefore != visibleAfter) setState(() {});
    final from = max(
      0,
      _visibleCount(max(0, before - RevealEngine.fadeWindow)) - 1,
    );
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
  GptMarkdownConfig get _renderConfig =>
      _clamped
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
      if (span is TextSpan &&
          span.children == null &&
          (span.text ?? '').trim().isEmpty) {
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
  /// Only the last segment can be incomplete, and only while more is coming.
  /// A fence or block maths is left alone: those are opaque to begin with, and
  /// [splitStreamSegments] already keeps them whole.
  List<String> _visibleSegments(String source, List<String> segments) {
    if (!widget.isStreaming ||
        !widget.revealing ||
        _holdExpired ||
        segments.isEmpty) {
      return segments;
    }
    final last = segments.last;
    final opener = last.trimLeft();
    // Custom blocks own their incomplete-input policy; inline delimiters in
    // their opaque bodies must never be held by the Markdown reveal.
    if (widget.config.blockRegistry?.match(last.split('\n'), 0) != null) {
      return segments;
    }
    // Block maths is opaque: whole or nothing. An unterminated `\[` hands
    // partial tex to the renderer, which paints the raw source on any cut
    // landing mid-command — the equation flickered rendered <-> raw several
    // times while it streamed. So a closed block shows and an open one waits.
    if (opener.startsWith(r'\[')) {
      if (last.contains(r'\]')) {
        return segments;
      }
      _armHoldRelease();
      return segments.sublist(0, segments.length - 1);
    }
    // An open fence streams as itself — its backticks are not inline
    // delimiters, and its body must not be withheld.
    if (_hasOpenFence(last)) {
      return segments;
    }
    // Fences that have already closed are opaque to the inline scanner too:
    // only the prose after the last one is scanned, or a closed fence's
    // backticks would be read as inline code and the prose after it would
    // stream unheld.
    final scanFrom = _afterLastFence(last);
    var safe =
        scanFrom +
        inlineSafeLength(
          last.substring(scanFrom),
          holdMathDollars: widget.holdMathDollars,
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
      _holdHighWater = tailStart + safe;
    }
    if (safe >= last.length) {
      return segments;
    }
    _armHoldRelease();
    final trimmed = last.substring(0, safe);
    final out = segments.sublist(0, segments.length - 1);
    if (trimmed.trim().isNotEmpty) {
      out.add(trimmed);
    }
    return out;
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

  /// Whether [segment] contains a fence that has not closed yet.
  ///
  /// The same naive toggle [splitStreamSegments] uses, so the two always
  /// agree about what is inside a fence.
  static bool _hasOpenFence(String segment) {
    var open = false;
    for (final line in segment.split('\n')) {
      if (line.trimLeft().startsWith('```')) {
        open = !open;
      }
    }
    return open;
  }

  /// Offset just past the last line that closes a fence in [segment], or 0.
  static int _afterLastFence(String segment) {
    var open = false;
    var after = 0;
    var offset = 0;
    for (final line in segment.split('\n')) {
      final lineEnd = offset + line.length;
      if (line.trimLeft().startsWith('```')) {
        open = !open;
        if (!open) {
          after = lineEnd < segment.length ? lineEnd + 1 : segment.length;
        }
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
    final source =
        patterns == null || patterns.isEmpty
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
    _segments =
        !_clamped
            ? _visibleSegments(
              source,
              _segmentCache.update(
                source,
                blockRegistry: widget.config.blockRegistry,
              ),
            )
            : <String>[source];
    final live = _segments.toSet();
    _documents.removeWhere((key, _) => !live.contains(key));
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
      final count =
          _characterCounts[(index, _segments[index])] ??= countRevealCharacters(
            spans,
          );
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

  Widget _buildSegment(BuildContext context, int index) {
    final segment = _segments[index];
    final spans = _rendered[index];
    final start = _starts[index];
    final end = start + _counts[index];
    final revealing = widget.revealing && _motionEnabled;
    final settled = _engine.revealedFloor >= _total && !_engine.tailStillFading;
    final fading = revealing && widget.effect.animatesCharacters && !settled;
    final revealed = revealing ? _engine.revealedFloor : _total;
    final settledBelow = fading ? revealed - RevealEngine.fadeWindow : revealed;
    final Widget paragraph;
    if (end <= settledBelow) {
      paragraph = _settled[(index, segment)] ??= _paragraph(spans);
    } else {
      paragraph = _paragraph(
        applyReveal(
          spans: spans,
          revealed: revealed - start,
          effect: widget.effect,
          progressFor: (offset) => _engine.progressFor(start + offset),
          defaultColor:
              widget.config.style?.color ??
              DefaultTextStyle.of(context).style.color ??
              Theme.of(context).colorScheme.onSurface,
          window: RevealEngine.fadeWindow,
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
    final animating =
        _arriving ||
        (revealing &&
            (_engine.revealedFloor < _total || _engine.tailStillFading));
    if (!animating) {
      return column;
    }
    return Semantics(
      container: true,
      label:
          MediaQuery.accessibleNavigationOf(context) ? _semanticsLabel() : null,
      child: ExcludeSemantics(child: column),
    );
  }

  /// The reply so far as one string, for [build]'s streaming semantics label.
  ///
  /// Per-segment text is cached alongside the spans it came from, so a chunk
  /// only converts the segment it landed in.
  String _semanticsLabel() {
    final buffer = StringBuffer();
    for (var index = 0; index < _segments.length; index++) {
      final text =
          _plainText[(index, _segments[index])] ??= TextSpan(
            children: _rendered[index],
          ).toPlainText(
            includeSemanticsLabels: false,
            includePlaceholders: false,
          );
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
