/// Reveal animation for Markdown that arrives a token at a time.
library;

import 'package:material_ui/material_ui.dart';
import 'package:flutter/scheduler.dart';

import 'reveal_engine.dart';
import 'stream_split.dart';

/// Builds the Markdown for a slice of the source.
typedef StreamingMarkdownBuilder =
    Widget Function(BuildContext context, String text);

/// Reveals [text] progressively, rebuilding only the part that can still
/// change.
///
/// The source is split at the last safe blank line. Everything before it is
/// settled — built once, cached, and wrapped in a [RepaintBoundary], so it is
/// neither rebuilt nor repainted as the reply continues. Only the tail is
/// rebuilt per frame.
///
/// That split is the whole performance story. Measured on a 7.7 kB reply, a
/// whole-document rebuild costs about 14 ms; a tail-only rebuild costs about
/// 1.3 ms and, unlike the first, does not grow as the reply gets longer.
///
/// Streaming is data, not a `Stream`: rebuild this widget with a longer [text]
/// while [isStreaming] is true. When it flips to false the remainder
/// fast-forwards in, so a finished reply never trickles.
class StreamingMarkdown extends StatefulWidget {
  /// Creates a revealing Markdown view.
  const StreamingMarkdown({
    super.key,
    required this.text,
    required this.builder,
    this.isStreaming = true,
    this.charactersPerSecond = 300,
    this.seamGap = 0,
  }) : assert(charactersPerSecond > 0, 'charactersPerSecond must be positive'),
       assert(seamGap >= 0, 'seamGap must not be negative');

  /// Everything received so far.
  final String text;

  /// Renders a slice of the source. The same builder is used for the settled
  /// prefix and the live tail.
  final StreamingMarkdownBuilder builder;

  /// Whether more text may still arrive.
  ///
  /// While true the reveal animates. When it turns false the remainder
  /// fast-forwards in and the ticker stops, so a settled reply costs nothing.
  final bool isStreaming;

  /// Baseline reveal speed. The reveal goes faster than this on its own
  /// whenever it would otherwise fall behind the incoming text.
  final double charactersPerSecond;

  /// Space between the settled prefix and the live tail.
  ///
  /// The split always lands just after a blank line, so in the finished
  /// document that boundary carries exactly one block gap. The two halves are
  /// built as separate documents, though, and neither owns the space between
  /// them — leave this at 0 and the gap is missing for as long as the seam is
  /// there, then appears when the reply completes and the document is built
  /// whole, shifting everything below it down.
  ///
  /// [GptMarkdown] passes its own block gap. Defaults to 0 so a caller
  /// supplying its own builder keeps the previous layout.
  final double seamGap;

  @override
  State<StreamingMarkdown> createState() => _StreamingMarkdownState();
}

class _StreamingMarkdownState extends State<StreamingMarkdown>
    with SingleTickerProviderStateMixin {
  final RevealEngine _engine = RevealEngine();

  late final Ticker _ticker;
  Duration _lastElapsed = Duration.zero;

  /// The settled prefix and the widget built from it, kept so an unchanged
  /// prefix is never rebuilt.
  String _settledSource = '';
  Widget? _settledChild;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    if (widget.isStreaming) {
      _startTicking();
    } else {
      _engine.snapToEnd(widget.text.length);
    }
  }

  @override
  void didUpdateWidget(StreamingMarkdown oldWidget) {
    super.didUpdateWidget(oldWidget);

    final extended =
        widget.text.length >= oldWidget.text.length &&
        widget.text.startsWith(oldWidget.text);

    if (!extended) {
      // A regenerate or a branch switch: the text was replaced, not extended,
      // so the reveal offset from the old text means nothing.
      _settledSource = '';
      _settledChild = null;
      if (widget.isStreaming) {
        _engine.reset();
        _startTicking();
      } else {
        _snapToEnd();
      }
      return;
    }

    if (widget.isStreaming) {
      _engine.clearFastForward();
      if (!_engine.caughtUp(widget.text.length)) {
        _startTicking();
      }
      return;
    }

    if (oldWidget.isStreaming) {
      // The reply finished. Nothing more is coming, so show the rest quickly
      // instead of making the reader wait for the baseline rate.
      if (_engine.caughtUp(widget.text.length)) {
        _snapToEnd();
      } else {
        _engine.beginFastForward();
        _startTicking();
      }
      return;
    }

    if (widget.text != oldWidget.text) {
      _snapToEnd();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _startTicking() {
    if (_ticker.isActive) {
      return;
    }
    _lastElapsed = Duration.zero;
    _ticker.start();
  }

  void _snapToEnd() {
    if (_ticker.isActive) {
      _ticker.stop();
    }
    _engine.snapToEnd(widget.text.length);
  }

  void _onTick(Duration elapsed) {
    final dt = (elapsed - _lastElapsed).inMicroseconds / 1e6;
    _lastElapsed = elapsed;
    if (dt <= 0) {
      return;
    }
    setState(() {
      final keepGoing = _engine.tick(
        dt,
        widget.text.length,
        widget.charactersPerSecond,
      );
      if (!keepGoing) {
        _ticker.stop();
      }
    });
  }

  /// The settled prefix, built at most once per distinct prefix.
  ///
  /// A [RepaintBoundary] keeps it off the tail's repaint: the tail changes
  /// every frame, and without the boundary the whole reply would repaint with
  /// it.
  Widget _settled(BuildContext context, String source) {
    final cached = _settledChild;
    if (cached != null && source == _settledSource) {
      return cached;
    }
    final built = RepaintBoundary(child: widget.builder(context, source));
    _settledSource = source;
    _settledChild = built;
    return built;
  }

  @override
  Widget build(BuildContext context) {
    // Honour the platform's reduced-motion setting: no reveal, no ticker
    // work, just the finished document.
    if (MediaQuery.disableAnimationsOf(context)) {
      if (_ticker.isActive) {
        _ticker.stop();
      }
      return widget.builder(context, widget.text);
    }

    final full = widget.text;
    final shown = _engine.revealedFloor.clamp(0, full.length);

    // Settled: nothing is animating and nothing more is coming, so build the
    // document plainly. Selection and link taps work here; during the reveal
    // the tail is rebuilt every frame and is not a stable target.
    //
    // The `isStreaming` check matters for performance, not correctness. A
    // model slower than the reveal lets it catch up between tokens, and
    // without this the widget would drop back to building the whole document
    // on every token — the cost the split exists to avoid.
    if (!widget.isStreaming && !_ticker.isActive && shown >= full.length) {
      return widget.builder(context, full);
    }

    final visible = full.substring(0, shown);
    final splitAt = settledSplitOffset(visible);

    final tail = _RevealEdge(
      // The gradient only has to fade the newest characters, so it is a
      // paint-time effect on the tail: no extra layout, and the settled part
      // never sees it.
      child: widget.builder(context, visible.substring(splitAt)),
    );

    if (splitAt == 0) {
      return tail;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _settled(context, visible.substring(0, splitAt)),
        // Stands in for the block gap the whole-document build puts here, so
        // the seam is invisible and nothing moves when it advances or when
        // the reply finishes.
        if (widget.seamGap > 0) SizedBox(height: widget.seamGap),
        tail,
      ],
    );
  }
}

/// Softens the last line of its child with a horizontal gradient.
///
/// Paint-only: a [ShaderMask] composites during paint, so the child is not
/// laid out again. Applied to the tail alone, which is at most one construct.
class _RevealEdge extends StatelessWidget {
  const _RevealEdge({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (bounds) {
        // Fade only the final stretch, and only when the tail is tall enough
        // for the gradient to read as an edge rather than a wash.
        final height = bounds.height;
        final fade = height <= 0 ? 0.0 : (24 / height).clamp(0.0, 0.6);
        return LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: const [Colors.white, Colors.white, Colors.transparent],
          stops: [0, 1 - fade, 1],
        ).createShader(bounds);
      },
      child: child,
    );
  }
}
