/// Applying a character reveal to spans that are already built.
///
/// The alternative — re-slicing the Markdown source every frame and rendering
/// the prefix — reparses the tail on every tick, and can only ever produce a
/// hard cut: by the time there are spans the character boundaries are gone, so
/// the only softening left is a gradient over whatever pixels happen to be at
/// the bottom of the box.
///
/// Working on the span tree instead means the document is rendered once per
/// *text* change rather than once per *frame*, and a frame's whole job is
/// restyling the handful of characters still arriving. It also has nothing to
/// say about which parser produced the spans, so one implementation serves
/// both pipelines.
library;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../custom_widgets/inline_code.dart';
import '../custom_widgets/inline_tap.dart';
import 'reveal_effect.dart';

/// Transforms a run of spans — the reveal, handed to a [RevealableSpan] so it
/// can be applied to content the span builds for itself.
typedef SpanTransform = List<InlineSpan> Function(List<InlineSpan> spans);

/// A widget span that lets the reveal reach the text inside it.
///
/// Block constructs — headings, list items, quotes, checkboxes — are text with
/// a marker, an indent or a rule around it, so the renderer builds them as
/// widgets. To the reveal a widget is one opaque character, which is why those
/// constructs used to arrive whole however the reveal was configured, while a
/// bare paragraph revealed letter by letter.
///
/// This keeps the widget but publishes two things alongside it: [content], the
/// text within, so the reveal can count and style it; and [rebuild], which
/// reconstructs the span with a transform applied to that text. The widget is
/// still built by the same code with the same styling — it just builds over
/// revealed spans instead of finished ones.
class RevealableSpan extends TextSpan {
  /// Creates a span whose inner text the reveal can reach.
  ///
  /// [children] is what actually renders — normally the single widget span the
  /// block was already built as. Wrapping a span rather than a widget keeps
  /// this usable for constructs that build their own span (a block quote
  /// carries its bar and inset in one) without a paragraph nested inside a
  /// paragraph to hold it.
  const RevealableSpan({
    required this.content,
    required this.rebuild,
    required super.children,
    super.style,
  });

  /// The text inside the widget, in document order.
  ///
  /// Used for counting and for resolving offsets. Built with the enclosing
  /// config; the widget may rebuild it under a modified one (a heading's
  /// larger type, a quote's dimmer ink), which changes the styling but not the
  /// characters.
  final List<InlineSpan> content;

  /// Rebuilds this span with [transform] applied to its content.
  final InlineSpan Function(SpanTransform transform) rebuild;
}

/// Total characters in [spans], counting a placeholder as one.
///
/// This is the unit the reveal counts in, so it has to agree exactly with what
/// [applyReveal] walks — hence one function, used by both.
int countRevealCharacters(List<InlineSpan> spans) {
  var total = 0;
  for (final span in spans) {
    total += _count(span);
  }
  return total;
}

int _count(InlineSpan span) {
  // Counted by what is inside it, not as the single placeholder it is to
  // Flutter — that is the whole point of the span.
  if (span is RevealableSpan) {
    return countRevealCharacters(span.content);
  }
  if (span is! TextSpan) {
    // A placeholder occupies one character in Flutter's own accounting
    // (`￼`); matching that keeps offsets aligned with the paragraph.
    return 1;
  }
  var total = span.text?.length ?? 0;
  final children = span.children;
  if (children != null) {
    for (final child in children) {
      total += _count(child);
    }
  }
  return total;
}

/// Rebuilds [spans] showing only the first [revealed] characters, with the
/// ones still arriving styled by [effect].
///
/// [progressFor] reports how far through its entrance the character at a given
/// index is — `RevealEngine.progressFor` in practice, but any function will do.
///
/// Three regions come out of this, and only the middle one costs anything per
/// frame:
///
/// * **Settled** — characters whose entrance is over, emitted as whole spans
///   and never split, so a long reply stays a handful of spans.
/// * **Arriving** — at most [window] characters, grouped by word (or split
///   per character for an effect that styles letters individually), each
///   group carrying the effect's style delta.
/// * **Unrevealed** — dropped. The document ends where the reveal is, so
///   nothing below the reading position is laid out before it is meant to be
///   seen, and nothing pops in there later.
List<InlineSpan> applyReveal({
  required List<InlineSpan> spans,
  required int revealed,
  required GptMarkdownAnimation effect,
  required double Function(int index) progressFor,
  required Color defaultColor,
  int window = 64,
}) {
  final from = effect.animatesCharacters ? revealed - window : revealed;
  final out = <InlineSpan>[];
  _walk(
    spans: spans,
    out: out,
    cursor: _Cursor(),
    revealed: revealed,
    settledBelow: from < 0 ? 0 : from,
    effect: effect,
    progressFor: progressFor,
    inheritedColor: defaultColor,
  );
  return out;
}

/// The running character offset, shared down the recursion.
class _Cursor {
  int value = 0;

  /// Whether the last emitted character was a word boundary (whitespace, a
  /// placeholder, or the start of the document).
  ///
  /// A word can straddle two spans (`**bo**ld`), and the piece that holds its
  /// back half cannot see its front. Styling that back half while the front
  /// sits settled in its own span would paint an opacity seam inside the
  /// word — so a piece that opens mid-word keeps its opening plain.
  bool lastWasSpace = true;
}

void _walk({
  required List<InlineSpan> spans,
  required List<InlineSpan> out,
  required _Cursor cursor,
  required int revealed,
  required int settledBelow,
  required GptMarkdownAnimation effect,
  required double Function(int index) progressFor,
  required Color inheritedColor,
}) {
  for (final span in spans) {
    if (cursor.value >= revealed) {
      return;
    }
    // A span that has entirely settled passes through as the original object.
    // Identity, not reconstruction: the span may be a subclass the paragraph
    // recognises (`CodeTextSpan` is how the inline-code chip finds its runs),
    // it keeps its recognizer, and one span stays one shaped run — so settled
    // content lays out exactly as it will once the reveal is over, and
    // switching a segment between this path and its cached settled widget
    // changes nothing on screen.
    final size = _count(span);
    if (cursor.value + size <= settledBelow) {
      out.add(span);
      cursor.value += size;
      final lastChar = _lastCharOf(span);
      if (lastChar != null) {
        cursor.lastWasSpace = lastChar < 0 || _isSpace(lastChar);
      }
      continue;
    }
    if (span is RevealableSpan) {
      final base = cursor.value;
      // The widget rebuilds its own content, so the reveal is handed in as a
      // transform rather than applied to a span list this loop owns. Offsets
      // continue from here, so a heading's third character is the document's
      // third character and fades on the same clock as everything else.
      out.add(
        span.rebuild((inner) {
          final revealedInner = <InlineSpan>[];
          _walk(
            spans: inner,
            out: revealedInner,
            cursor: _Cursor()..value = base,
            revealed: revealed,
            settledBelow: settledBelow,
            effect: effect,
            progressFor: progressFor,
            inheritedColor: inheritedColor,
          );
          return revealedInner;
        }),
      );
      cursor.value = base + countRevealCharacters(span.content);
      cursor.lastWasSpace = true;
      continue;
    }
    if (span is! TextSpan) {
      // Placeholders are atomic: shown whole or not at all, and never
      // restyled — there is no text inside them to fade.
      out.add(span);
      cursor.value += 1;
      cursor.lastWasSpace = true;
      continue;
    }

    // Only the colour is resolved down the tree. Everything else is left to
    // Flutter's own span inheritance, so the rebuilt tree keeps whatever the
    // renderer put on these spans without this file having to know about it.
    final color = span.style?.color ?? inheritedColor;

    final pieces = <InlineSpan>[];
    final text = span.text;
    if (text != null && text.isNotEmpty) {
      _emitText(
        text: text,
        out: pieces,
        cursor: cursor,
        revealed: revealed,
        settledBelow: settledBelow,
        effect: effect,
        progressFor: progressFor,
        color: color,
        recognizer: span.recognizer,
      );
    }
    final children = span.children;
    if (children != null && cursor.value < revealed) {
      _walk(
        spans: children,
        out: pieces,
        cursor: cursor,
        revealed: revealed,
        settledBelow: settledBelow,
        effect: effect,
        progressFor: progressFor,
        inheritedColor: color,
      );
    }
    if (pieces.isEmpty) {
      continue;
    }
    // The original span's own style is kept on the container and the pieces
    // carry only the effect's delta, so Flutter resolves `foreground` against
    // `color` the way it always does. Two things travel further down:
    //
    // A recognizer is copied onto every emitted piece, not just left on the
    // container. A recognizer on a span that has children and no `text` can
    // never fire, so leaving it here alone would make an `InlinePattern`
    // mention — or any recognizer-bearing span — untappable for the whole
    // reveal and tappable only once the segment settled.
    //
    // A tagged span keeps its tag: inline code's chip and a link's tap run are
    // both found by subclass, and rebuilding one as a plain `TextSpan` left it
    // undecorated and untappable until the segment settled.
    out.add(switch (span) {
      CodeTextSpan() => CodeTextSpan.revealing(
        children: pieces,
        codeStyle: span.codeStyle,
        style: span.style,
        recognizer: span.recognizer,
        mouseCursor: span.mouseCursor,
        semanticsLabel: span.semanticsLabel,
      ),
      LinkTextSpan() => LinkTextSpan.wrapping(
        children: pieces,
        url: span.url,
        linkStyle: span.linkStyle,
        onTap: span.onTap,
        hoverStyle: span.hoverStyle,
        style: span.style,
        mouseCursor: span.mouseCursor,
      ),
      TappableTextSpan() => TappableTextSpan.wrapping(
        children: pieces,
        onTap: span.onTap,
        hoverStyle: span.hoverStyle,
        style: span.style,
        mouseCursor: span.mouseCursor,
      ),
      _ => TextSpan(
        children: pieces,
        style: span.style,
        recognizer: span.recognizer,
        mouseCursor: span.mouseCursor,
        onEnter: span.onEnter,
        onExit: span.onExit,
        semanticsLabel: span.semanticsLabel,
        locale: span.locale,
        spellOut: span.spellOut,
      ),
    });
  }
}

void _emitText({
  required String text,
  required List<InlineSpan> out,
  required _Cursor cursor,
  required int revealed,
  required int settledBelow,
  required GptMarkdownAnimation effect,
  required double Function(int index) progressFor,
  required Color color,
  GestureRecognizer? recognizer,
}) {
  final start = cursor.value;
  final end = start + text.length;
  cursor.value = end;

  // Entirely settled: one span, whatever its length. This is the branch that
  // keeps a long reply cheap.
  if (end <= settledBelow) {
    out.add(TextSpan(text: text, recognizer: recognizer));
    cursor.lastWasSpace = _isSpace(text.codeUnitAt(text.length - 1));
    return;
  }
  // Entirely past the reveal head.
  if (start >= revealed) {
    return;
  }

  final settledEnd = settledBelow < start ? start : settledBelow;

  var limit = end < revealed ? end : revealed;
  // Never cut a surrogate pair at the head: half of one is not a character,
  // it lays out as a replacement glyph, and its different advance jiggles the
  // wrap point until the low half arrives. The pair waits one floor step.
  if (limit < end &&
      limit > start &&
      _isHighSurrogate(text.codeUnitAt(limit - 1 - start))) {
    limit -= 1;
  }
  if (limit <= start) {
    return;
  }

  final perCharacter = effect.animatesPerCharacter;
  var i = settledEnd < limit ? settledEnd : limit;
  if (!perCharacter && i > start) {
    // The settled boundary is word-aligned before anything is emitted, so it
    // can never sit inside a word: the word it would have cut joins the
    // styled region whole, anchored at its own start — settled or nearly so,
    // so it draws plain or almost plain — and the plain/styled boundary only
    // ever moves from word edge to word edge.
    i = _wordStart(text, start, i);
  }
  // Pieces needing no style of their own are gathered into one span rather
  // than emitted singly: a piece whose entrance is over is drawn exactly as
  // it will settle, and separate spans are not the same as one span — they
  // shape as separate runs. Only what is genuinely mid-entrance is split off.
  // The settled prefix opens the run rather than being emitted on its own, so
  // it merges with any finished pieces that follow it.
  var plainFrom = i > start ? start : -1;
  void flushPlain(int until) {
    if (plainFrom >= 0) {
      out.add(
        TextSpan(
          text: text.substring(plainFrom - start, until - start),
          recognizer: recognizer,
        ),
      );
      plainFrom = -1;
    }
  }

  // A word continuing out of the previous span cannot be word-aligned from
  // inside this piece; it stays plain to its first whitespace instead of
  // painting an opacity seam mid-word.
  var midWordOpen = !perCharacter && i == start && !cursor.lastWasSpace;

  while (i < limit) {
    final int next;
    if (perCharacter) {
      // Never split a surrogate pair mid-stream either.
      next =
          i +
          (_isHighSurrogate(text.codeUnitAt(i - start)) && i + 1 < limit
              ? 2
              : 1);
    } else {
      // Whole words: a style boundary only ever falls on whitespace, where
      // there is no kerning or ligature to break and no advance to change
      // when the boundary later disappears. The word's progress is its first
      // character's: it fades as one, growing at the head as its characters
      // are revealed.
      next = _groupEnd(text, start, i, limit);
    }
    if (midWordOpen && _isSpace(text.codeUnitAt(i - start))) {
      midWordOpen = false;
    }
    final delta =
        midWordOpen ? null : revealStyleFor(effect, progressFor(i), color);
    if (delta == null) {
      if (plainFrom < 0) {
        plainFrom = i;
      }
    } else {
      flushPlain(i);
      out.add(
        TextSpan(
          text: text.substring(i - start, next - start),
          style: delta,
          recognizer: recognizer,
        ),
      );
    }
    i = next;
  }
  flushPlain(limit);
  cursor.lastWasSpace = _isSpace(text.codeUnitAt(limit - 1 - start));
}

/// Longest run one reveal group may cover.
///
/// Text with no whitespace at all — unbroken CJK prose, a long URL — would
/// otherwise be a single group anchored at its start, which settles within
/// one fade and turns the entrance into a hard cut for entire languages. A
/// cap keeps such runs arriving in visible steps. CJK glyphs do not kern or
/// ligate across the cap, and a Latin word this long is rare enough that the
/// one-frame reshape when its groups merge is acceptable.
const int _maxRevealGroup = 12;

/// One reveal group: any leading whitespace, then the word after it, capped
/// at [_maxRevealGroup] code units.
int _groupEnd(String text, int start, int from, int limit) {
  var j = from;
  while (j < limit && _isSpace(text.codeUnitAt(j - start))) {
    j += 1;
  }
  while (j < limit && !_isSpace(text.codeUnitAt(j - start))) {
    j += 1;
  }
  if (j - from > _maxRevealGroup) {
    j = from + _maxRevealGroup;
    if (_isHighSurrogate(text.codeUnitAt(j - 1 - start))) {
      j -= 1;
    }
  }
  return j > from ? j : from + 1;
}

/// Start of the word containing [at], never before [start].
int _wordStart(String text, int start, int at) {
  var j = at;
  while (j > start && !_isSpace(text.codeUnitAt(j - 1 - start))) {
    j -= 1;
  }
  return j;
}

/// Last text character of [span]'s subtree, -1 for a placeholder boundary,
/// null when the subtree holds no characters at all.
int? _lastCharOf(InlineSpan span) {
  if (span is! TextSpan) {
    return -1;
  }
  final children = span.children;
  if (children != null) {
    for (var i = children.length - 1; i >= 0; i--) {
      final c = _lastCharOf(children[i]);
      if (c != null) {
        return c;
      }
    }
  }
  final t = span.text;
  if (t != null && t.isNotEmpty) {
    return t.codeUnitAt(t.length - 1);
  }
  return null;
}

bool _isSpace(int codeUnit) =>
    codeUnit == 0x20 ||
    codeUnit == 0x0A ||
    codeUnit == 0x09 ||
    codeUnit == 0x0D;

bool _isHighSurrogate(int codeUnit) => (codeUnit & 0xFC00) == 0xD800;
