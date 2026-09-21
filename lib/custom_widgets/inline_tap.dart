/// Tap targets inside a paragraph, resolved by text range rather than by span.
///
/// A [GestureRecognizer] on an [InlineSpan] is only effective for events that
/// directly hit that span's own [TextSpan.text], never its
/// [TextSpan.children]: [TextSpan.visitChildren] skips a span whose text is
/// null, [TextSpan.getSpanForPositionVisitor] returns null for a span whose
/// text is null or empty, and `RenderParagraph.hitTestChildren` adds exactly
/// the one span `getSpanForPosition` returned. So
/// `TextSpan(children: label, recognizer: tap)` compiles, reads correctly, and
/// is never tapped. A [WidgetSpan] cannot carry a recognizer at all.
///
/// This library sidesteps both. A [TappableTextSpan] carries a
/// [VoidCallback], not a recognizer; [collectInlineTapRuns] measures it
/// *after* its subtree, so a wrapper covers its whole label; and
/// [InlineTapTargets] resolves a pointer to a run with
/// [RenderParagraph.getBoxesForSelection] — the same public call
/// [InlineCodeDecoration] already uses to paint chips. A wrapper is therefore
/// as tappable as a leaf, and a placeholder inside a label is covered by the
/// run around it.
library;

import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../styles/link_style.dart';

/// A [TextSpan] that answers a tap, without carrying a [GestureRecognizer].
///
/// Behaves as an ordinary [TextSpan] everywhere else, so the text stays
/// selectable, wraps across lines, and sits on the surrounding baseline — none
/// of which a [WidgetSpan] can do.
///
/// Taps are resolved by the paragraph, by text range, so a span built over
/// [TextSpan.children] is a working tap target — something a
/// [GestureRecognizer] cannot be, because it only fires for a span carrying
/// its own text. The package owns every recognizer involved and disposes them.
/// Nothing you can return from an [InlineLinkBuilder] produces a silently dead
/// tap.
///
/// ```dart
/// TappableTextSpan(
///   text: 'Read the docs',
///   onTap: () => launchUrl(uri),
///   style: style,
/// )
/// ```
class TappableTextSpan extends TextSpan {
  /// Creates a tappable run of text.
  const TappableTextSpan({
    required String super.text,
    this.onTap,
    this.hoverStyle,
    super.style,
    super.recognizer,
    super.mouseCursor,
    super.semanticsLabel,
  });

  /// Creates a tappable span over already-built [children].
  ///
  /// The whole subtree is one tap target. This is the form a link label takes
  /// — the label is parsed into spans before a builder ever sees it — and the
  /// form the streaming reveal rebuilds while the last characters are still
  /// arriving.
  ///
  /// No `semanticsLabel` here: [TextSpan] asserts that one is only set
  /// alongside `text`. Put it on the leaves.
  const TappableTextSpan.wrapping({
    required List<InlineSpan> super.children,
    this.onTap,
    this.hoverStyle,
    super.style,
    super.mouseCursor,
  });

  /// Run when this span is tapped. Null makes the span inert.
  final VoidCallback? onTap;

  /// Merged over [TextSpan.style] — and over every descendant's — while the
  /// pointer is inside this span.
  ///
  /// Null means the span does not react to hover. Resolved by the paragraph,
  /// so hovering does not regenerate the document's spans.
  final TextStyle? hoverStyle;
}

/// A [TappableTextSpan] the package recognises as a link.
///
/// Carries [url] and the resolved [LinkStyle] it was drawn with, so the rest
/// of the pipeline — the streaming reveal, the test serialiser, a future
/// semantics pass — can find links in a finished span tree instead of
/// inferring them from a decoration.
class LinkTextSpan extends TappableTextSpan {
  /// Creates a link over one run of text.
  const LinkTextSpan({
    required super.text,
    required this.url,
    required this.linkStyle,
    super.onTap,
    super.hoverStyle,
    super.style,
    super.recognizer,
    super.mouseCursor,
    super.semanticsLabel,
  });

  /// Creates a link over an already-parsed label.
  const LinkTextSpan.wrapping({
    required super.children,
    required this.url,
    required this.linkStyle,
    super.onTap,
    super.hoverStyle,
    super.style,
    super.mouseCursor,
  }) : super.wrapping();

  /// The link target, verbatim as it appeared in the document.
  final String url;

  /// The resolved style this link was drawn with, with theme fallbacks
  /// already applied.
  final LinkStyle linkStyle;
}

/// A resolved tap target: a range of the paragraph's plain text, and what to
/// run when it is hit.
@immutable
class InlineTapRun {
  /// Creates a tap run.
  const InlineTapRun({
    required this.start,
    required this.end,
    this.onTap,
    this.hoverStyle,
  });

  /// First code unit of the run, in the paragraph's plain text.
  final int start;

  /// One past the last code unit of the run.
  final int end;

  /// Run on tap.
  final VoidCallback? onTap;

  /// Applied while the pointer is inside the run.
  final TextStyle? hoverStyle;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InlineTapRun &&
          other.start == start &&
          other.end == end &&
          other.onTap == onTap &&
          other.hoverStyle == hoverStyle;

  @override
  int get hashCode => Object.hash(start, end, onTap, hoverStyle);
}

/// Every [TappableTextSpan] in [root], as plain-text ranges.
///
/// Measured *after* the subtree, so a span built over [TextSpan.children]
/// covers everything inside it rather than its own (absent) text — the reason
/// a wrapper is a working tap target here and a dead one with a recognizer.
/// Offsets count a placeholder as the single U+FFFC code unit the engine lays
/// out, so they line up with [RenderParagraph.getBoxesForSelection].
///
/// Identical in shape to [collectInlineCodeRuns].
List<InlineTapRun> collectInlineTapRuns(InlineSpan root) {
  final runs = <InlineTapRun>[];
  var offset = 0;

  void visit(InlineSpan span) {
    if (span is TextSpan) {
      final start = offset;
      offset += span.text?.length ?? 0;
      final children = span.children;
      if (children != null) {
        for (final child in children) {
          visit(child);
        }
      }
      if (span is TappableTextSpan && offset > start) {
        runs.add(
          InlineTapRun(
            start: start,
            end: offset,
            onTap: span.onTap,
            hoverStyle: span.hoverStyle,
          ),
        );
      }
    } else if (span is PlaceholderSpan) {
      offset += 1;
    } else {
      offset += span.toPlainText(includePlaceholders: true).length;
    }
  }

  visit(root);
  return runs;
}

/// The recognizer this package arms a tappable leaf with.
///
/// Marked so [InlineTapTargets] can tell its own arming apart from a
/// recognizer a consumer put on a span. It stands aside for the consumer's —
/// a mention inside a link label opens the profile, not the link — but not for
/// its own, because its own covers only the tight glyph boxes that
/// `RenderParagraph.hitTestChildren` tests, while the run covers the whole
/// line box. Deferring to it would leave the leading and trailing band of a
/// line dead: pointing-hand cursor, no tap.
class InlineTapLeafRecognizer extends TapGestureRecognizer {}

/// Resolves taps on [InlineTapRun]s at the paragraph rather than at the span.
///
/// Mix into any [RenderParagraph] subclass. [RenderParagraph.hitTestSelf] is
/// already true, so the paragraph is in every hit-test result; this turns a
/// pointer-down inside a run's boxes into that run's callback. A recognizer is
/// allocated per pointer-down and never recycled — reassigning a live one's
/// callback is how a second finger used to open the first finger's link — and
/// they are freed once their gesture has resolved.
///
/// A span that carries its own [TextSpan.recognizer] has already been handed
/// the pointer by `RenderParagraph.hitTestChildren`, so this stands aside for
/// it: an app-specific mention inside a link label opens the profile, and the
/// link around it is not also triggered.
mixin InlineTapTargets on RenderParagraph {
  List<InlineTapRun> _inlineTapRuns = const <InlineTapRun>[];

  /// Recognizers handed to pointers, one set per pointer-down.
  ///
  /// Never recycled. Reusing one and reassigning its callback is a wrong-url
  /// bug: a second pointer going down while the first is still held would
  /// re-point the recognizer the first gesture is using, so releasing the
  /// first finger opens the second link. Pointer-downs are user-driven, so
  /// allocating per gesture is cheap; resolved ones are pruned on the next
  /// pointer-down and the rest are freed in [dispose].
  final List<GestureRecognizer> _live = <GestureRecognizer>[];
  final Set<GestureRecognizer> _resolved = <GestureRecognizer>{};

  /// The tap targets in this paragraph, in its own text offsets.
  List<InlineTapRun> get inlineTapRuns => _inlineTapRuns;

  set inlineTapRuns(List<InlineTapRun> value) {
    if (listEquals(_inlineTapRuns, value)) {
      return;
    }
    _inlineTapRuns = value;
  }

  /// The innermost run whose boxes contain [position], or null.
  ///
  /// A pure geometric lookup — it does **not** stand aside for a span that
  /// owns its own recognizer, so hover and the pointer cursor still follow the
  /// enclosing link across a nested mention. Only [handleEvent] defers.
  InlineTapRun? runAt(Offset position, {bool requireHandler = false}) {
    if (_inlineTapRuns.isEmpty) {
      return null;
    }
    // One cheap engine call to narrow the field before measuring anything.
    // Without it every run is measured on every mouse move, which is a
    // getBoxesForSelection per link per pointer event.
    final offset = getPositionForOffset(position).offset;
    InlineTapRun? best;
    for (final run in _inlineTapRuns) {
      if (offset < run.start || offset > run.end) {
        continue;
      }
      // A run with nothing to run is not a tap target. Treating it as one lets
      // an inert TappableTextSpan nested in a link silently kill the link over
      // its own text — innermost wins, and the innermost does nothing.
      if (requireHandler && run.onTap == null) {
        continue;
      }
      final boxes = getBoxesForSelection(
        TextSelection(baseOffset: run.start, extentOffset: run.end),
        boxHeightStyle: ui.BoxHeightStyle.max,
      );
      for (final box in boxes) {
        if (box.toRect().contains(position)) {
          if (best == null || run.end - run.start < best.end - best.start) {
            best = run;
          }
          break;
        }
      }
    }
    return best;
  }

  /// Whether the span directly under [position] carries its own recognizer.
  bool _spanOwnsPointer(Offset position) {
    final hit = text.getSpanForPosition(getPositionForOffset(position));
    final recognizer = hit is TextSpan ? hit.recognizer : null;
    return recognizer != null && recognizer is! InlineTapLeafRecognizer;
  }

  @override
  void handleEvent(PointerEvent event, BoxHitTestEntry entry) {
    if (event is PointerDownEvent &&
        _inlineTapRuns.isNotEmpty &&
        !_spanOwnsPointer(entry.localPosition)) {
      final run = runAt(entry.localPosition, requireHandler: true);
      if (run != null) {
        _pruneResolved();
        final onTap = run.onTap;
        if (onTap != null) {
          final tap = TapGestureRecognizer();
          tap
            ..onTap = () {
              _resolved.add(tap);
              onTap();
            }
            ..onTapCancel = () => _resolved.add(tap);
          _live.add(tap);
          tap.addPointer(event);
        }
        if (onTap != null) {
          return;
        }
      }
    }
    super.handleEvent(event, entry);
  }

  /// Frees recognizers whose gesture has finished.
  ///
  /// Only ever called between gestures, so nothing here is still holding a
  /// pointer.
  void _pruneResolved() {
    if (_live.isEmpty) {
      return;
    }
    _live.removeWhere((recognizer) {
      // `onTap`/`onTapCancel` are not enough on their own. A fling that starts
      // on a tap run and is won by the scroller inside `kPressTimeout` rejects
      // the recognizer before it ever sent a tap-down, so neither callback
      // runs and the object would sit here for the render object's lifetime.
      // A recognizer back in `ready` has provably released its pointer.
      final done =
          _resolved.contains(recognizer) ||
          (recognizer is PrimaryPointerGestureRecognizer &&
              recognizer.state == GestureRecognizerState.ready);
      if (!done) {
        return false;
      }
      recognizer.dispose();
      return true;
    });
    _resolved.clear();
  }

  @override
  void dispose() {
    for (final recognizer in _live) {
      recognizer.dispose();
    }
    _live.clear();
    _resolved.clear();
    super.dispose();
  }
}
