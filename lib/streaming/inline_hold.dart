/// Holding the reveal behind markup that has not finished arriving.
///
/// A streaming reply is parsed from what has been received so far, so an inline
/// construct is literal text until its closing delimiter lands. `` `npm `` is
/// prose; `` `npm install` `` is a code chip. Reveal the characters as they
/// arrive and the reader watches eight settled words turn monospace a moment
/// later — a different font, a background, different metrics, and a line that
/// reflows around them. The same happens when `**bold` closes, or `\(x^2`.
///
/// Nothing is wrong with the parse; the reveal is simply ahead of it. So the
/// head waits: characters that could still change meaning are not shown until
/// the construct that governs them is complete, and every character a reader
/// sees is already in its final form.
///
/// [inlineSafeLength] still holds an open formula. The incremental view does
/// not call it on one: it renders an open formula as far as it has arrived
/// instead, and holds only the text before it.
library;

import '../plusparse/html_tags.dart';
import '../plusparse/scanner.dart';

/// Longest run of text the reveal will wait on for a delimiter that also
/// occurs in ordinary prose.
///
/// A lone backtick, or an asterisk used as a footnote mark, has no closer
/// coming. Waiting on one stalls the reveal and then dumps the backlog, which
/// reads worse than the restyle this avoids. These delimiters are given a
/// short leash: real emphasis and code spans close well inside it.
const int proseDelimiterHold = 48;

/// Longest run of text the reveal will wait on for a delimiter that is
/// unambiguously markup.
///
/// `\(`, `\[`, `<b>` and `[label](href)` do not appear by accident, so it is
/// worth waiting longer — a link with a long URL, or a displayed equation,
/// routinely runs past the prose limit.
const int markupDelimiterHold = 160;

/// How much of [source] can be shown without its styling changing later.
///
/// Returns [source]'s length when nothing is pending, so the common case costs
/// one scan and no allocation.
///
/// Deliberately a scan for unbalanced delimiters rather than a second parse:
/// it runs on the tail segment for every chunk that arrives, and it only has to
/// be *conservative*. Holding a character that would not have changed costs a
/// few milliseconds of latency; showing one that does change is the artefact
/// this exists to remove.
///
/// [html] is the HTML the parse understands; [MarkdownHtml.defaults] when
/// null. A tag outside it is text, and never held.
int inlineSafeLength(
  String source, {
  bool holdMathDollars = false,
  MarkdownHtml? html,
}) {
  final tags = html ?? MarkdownHtml.defaults;
  var limit = source.length;

  // Each delimiter carries its own patience. Holding is only ever worth it
  // while the closer is plausibly still coming.
  void holdAt(int index, int cap) {
    if (index < 0 || index >= limit) {
      return;
    }
    if (source.length - index > cap) {
      return;
    }
    limit = index;
  }

  // A code span runs to its closing backtick and swallows any other delimiter
  // on the way, so it is resolved first and the rest is checked outside it.
  var i = 0;
  var lastOpenTick = -1;
  final outside = StringBuffer();
  while (i < source.length) {
    if (source.codeUnitAt(i) == 0x60 /* ` */ ) {
      // A run of N backticks closes at the next run of exactly N.
      final span = codeSpanAt(source, i);
      if (span == null) {
        lastOpenTick = i;
        break;
      }
      // Keep the offsets aligned without copying the span's contents.
      final end = span.close + span.run;
      outside.write(' ' * (end - i));
      i = end;
      continue;
    }
    if (source.codeUnitAt(i) == 0x5C /* \ */ && i + 1 < source.length) {
      // A closed formula is opaque in the same way: `_`, `*`, `[` and `$`
      // inside TeX are maths, not Markdown. Scanned as prose, the `_` of
      // `(z)_i` read as an opening underscore, and the hold cut the tail
      // inside a `\[…\]` that had just closed — the formula fell back to raw
      // source and was retyped, until enough text arrived after it to release
      // the hold. An open formula is left in the text so the pair check below
      // still holds it.
      final next = source.codeUnitAt(i + 1);
      if (next == 0x28 /* ( */ || next == 0x5B /* [ */ ) {
        final close = source.indexOf(next == 0x28 ? r'\)' : r'\]', i + 2);
        if (close != -1) {
          final end = close + 2;
          outside.write(' ' * (end - i));
          i = end;
          continue;
        }
      }
      // Any other escape is one unit: `\\[` is a backslash and a bracket.
      outside
        ..writeCharCode(0x5C)
        ..writeCharCode(next);
      i += 2;
      continue;
    }
    outside.writeCharCode(source.codeUnitAt(i));
    i += 1;
  }
  holdAt(lastOpenTick, proseDelimiterHold);

  // A `*` that begins a line and is followed by whitespace is a list bullet,
  // and a line made only of `*`/`-`/`_` is a thematic break — neither is an
  // emphasis delimiter, and counting them as one made every streamed `*`
  // bullet invisible for the length of the leash. They are blanked out
  // before the emphasis scans, offsets preserved.
  final rest = _maskLineMarkers(outside.toString());
  // Paired delimiters: an odd count means the last one is still open.
  for (final token in const ['**', '~~', r'$$']) {
    holdAt(_lastUnpaired(rest, token), proseDelimiterHold);
  }
  // Single `*` for italic, but only the ones that are not part of `**`.
  holdAt(_lastUnpairedStar(rest), proseDelimiterHold);
  // `_` and `__`, but only where they can open: an underscore inside a word
  // (`snake_case`) never does, so it is never waited on.
  holdAt(_lastOpenUnderscore(rest), proseDelimiterHold);

  // Delimiters with distinct open and close forms.
  for (final pair in const [(r'\(', r'\)'), (r'\[', r'\]'), ('<!--', '-->')]) {
    final open = rest.lastIndexOf(pair.$1);
    if (open != -1 && rest.indexOf(pair.$2, open + pair.$1.length) == -1) {
      holdAt(open, markupDelimiterHold);
    }
  }

  // An HTML tag the parser understands — `<b>`, `<a href>`, `<span>`,
  // `<script>` — is text until its closing tag arrives.
  if (!tags.isEmpty) {
    holdAt(_lastUnclosedHtmlTag(rest, tags), markupDelimiterHold);
  }

  // A link or image: `[label](href)` is prose until its closing paren.
  final bracket = rest.lastIndexOf('[');
  if (bracket != -1) {
    final closeBracket = rest.indexOf(']', bracket + 1);
    if (closeBracket == -1) {
      holdAt(bracket, markupDelimiterHold);
    } else if (closeBracket + 1 < rest.length &&
        rest.codeUnitAt(closeBracket + 1) == 0x28 /* ( */ &&
        rest.indexOf(')', closeBracket + 1) == -1) {
      holdAt(bracket, markupDelimiterHold);
    }
  }

  // A table row is atomic: a line beginning with `|` is held until its
  // newline arrives, so the parser only ever sees complete rows. And while
  // the delimiter row is still arriving, the header is held with it — a
  // partial delimiter is invalid, so without this the table formed on one
  // cut (`|-`), fell apart on the next (`|:`), and re-formed, several times
  // per row.
  final lastNewline = source.lastIndexOf('\n');
  final lastLine = source.substring(lastNewline + 1);
  if (lastLine.trimLeft().startsWith('|')) {
    var holdIndex = lastNewline + 1;
    if (lastNewline > 0 && _partialTableSeparator.hasMatch(lastLine.trim())) {
      final prevNewline = source.lastIndexOf('\n', lastNewline - 1);
      final prevLine = source.substring(prevNewline + 1, lastNewline);
      // Only above a header. Under a finished delimiter row, a `| ` is the
      // first body row starting, and holding the delimiter row back with it
      // turned the header into a paragraph for a chunk — then into a table.
      final prevIsDelimiterRow =
          prevLine.contains('-') &&
          _partialTableSeparator.hasMatch(prevLine.trim());
      if (prevLine.trimLeft().startsWith('|') && !prevIsDelimiterRow) {
        holdIndex = prevNewline + 1;
      }
    }
    holdAt(holdIndex, markupDelimiterHold);
  }

  // A finished `|` line with nothing after it yet may be a table's header,
  // waiting for its delimiter row. Shown, it reads as a paragraph, and then
  // turns into a table — a different height — a chunk later. Only the first
  // `|` line: a row under an existing table is already final.
  if (lastLine.isEmpty && lastNewline > 0) {
    final prevStart = source.lastIndexOf('\n', lastNewline - 1) + 1;
    final prevLine = source.substring(prevStart, lastNewline);
    if (prevLine.trimLeft().startsWith('|')) {
      // `prevStart - 2` is -1 when the line above is the first, after a
      // leading newline — and `lastIndexOf` throws on a negative start.
      final beforeStart = prevStart > 1
          ? source.lastIndexOf('\n', prevStart - 2) + 1
          : (prevStart == 1 ? 0 : -1);
      final before = beforeStart >= 0
          ? source.substring(beforeStart, prevStart - 1)
          : '';
      if (!before.trimLeft().startsWith('|')) {
        holdAt(prevStart, markupDelimiterHold);
      }
    }
  }

  // Single-`$` maths, only when the caller treats `$…$` as maths at all —
  // to everyone else a dollar is a dollar.
  if (holdMathDollars) {
    holdAt(_lastUnpairedDollar(rest), markupDelimiterHold);
  }

  // A last line that is not finished deciding what it is:
  //
  // * `---` / `===` under a paragraph makes it a heading, but `-` is also the
  //   start of `- item`. Shown early, the paragraph above flickers into a
  //   heading and back.
  // * `[label]: url` is a definition, hidden once it is one — but only once
  //   its URL has arrived. Shown early, it flashes as text and vanishes.
  if (lastNewline >= 0 && setextUnderlineLevel(lastLine) != null) {
    holdAt(lastNewline + 1, proseDelimiterHold);
  }
  if (_definitionStart.hasMatch(lastLine)) {
    holdAt(lastNewline + 1, markupDelimiterHold);
  }
  // * `[label]:` with its destination on the next line, which has not
  //   arrived yet.
  if (lastNewline > 0) {
    final prevStart = source.lastIndexOf('\n', lastNewline - 1) + 1;
    if (_bareDefinitionLabel.hasMatch(
      source.substring(prevStart, lastNewline),
    )) {
      holdAt(prevStart, markupDelimiterHold);
    }
  }
  // * `2` or `2.` or `*` alone is the start of a list item still arriving.
  //   Shown early, it renders as a paragraph under the list — a line taller —
  //   and the list jumps back up a chunk later when it becomes an item.
  //   It can be the first line too: a list after a blank line starts a new
  //   segment, so its first marker has no line above it.
  if (_partialListMarker.hasMatch(lastLine)) {
    holdAt(lastNewline + 1, proseDelimiterHold);
  }

  // A trailing character that is only the first half of an opener: `\` may
  // become `\(` and `<` may become `<u>`. Un-held it is shown, revealed, and
  // then vanishes when the second half lands — the one leak the rules above
  // cannot see. The very next character decides, so this holds a couple of
  // characters at most and cannot stall.
  final partial = _partialTrailingOpener.firstMatch(source);
  if (partial != null) {
    holdAt(partial.start, proseDelimiterHold);
  }
  // A tag or an autolink whose `>` has not arrived: `<b`, `<a href="…`,
  // `<https://exa…`. Shown, it reads as text and then turns into
  // formatting or a link.
  holdAt(_partialTag(source, tags), markupDelimiterHold);

  // A hold that ends just after a list marker would show an empty item —
  // `2. ` with its content held back — which is a different height from the
  // item it becomes, so the list jumps when the content lands. Hold the
  // marker with its content instead.
  if (limit > 0 && limit < source.length) {
    final lineStart = source.lastIndexOf('\n', limit - 1) + 1;
    if (_bareListMarker.hasMatch(source.substring(lineStart, limit))) {
      limit = lineStart;
    }
  }

  return limit;
}

/// A list marker with nothing after it yet: `2. `, `- `, `* [ ] `.
final RegExp _bareListMarker = RegExp(
  r'^\s*(?:\d{1,9}[.)]|[-*+])(?:\s+\[[ xX]?\]?)?\s*$',
);

/// A trailing `\`, `<`, `</`, `<!` or `<!-` — an opener the next character
/// may complete.
final RegExp _partialTrailingOpener = RegExp(r'(\\|</?|<!-?)$');

/// `[label]:` and nothing else: a definition whose destination is on the
/// next line.
final RegExp _bareDefinitionLabel = RegExp(r'^ {0,3}\[[^\]]+\]:\s*$');

/// Index of a `<` on the last line that has not met its `>` yet and is
/// becoming a tag the parser understands or an autolink, or -1.
int _partialTag(String source, MarkdownHtml tags) {
  final open = source.lastIndexOf('<');
  if (open == -1 ||
      source.indexOf('>', open) != -1 ||
      source.indexOf('\n', open) != -1) {
    return -1;
  }
  var p = open + 1;
  if (p < source.length && source.codeUnitAt(p) == 0x2F /* / */ ) {
    p += 1;
  }
  final nameStart = p;
  while (p < source.length && _isTagNameChar(source.codeUnitAt(p))) {
    p += 1;
  }
  if (p == nameStart) {
    return -1;
  }
  final name = source.substring(nameStart, p).toLowerCase();
  // `<https:` — an autolink, and `<me@` — an email.
  if (p < source.length) {
    final c = source.codeUnitAt(p);
    if (c == 0x3A /* : */ || c == 0x40 /* @ */ ) {
      return source.indexOf(' ', p) == -1 ? open : -1;
    }
    if (c != 0x20 && c != 0x2F && c != 0x09) {
      return -1;
    }
  }
  if (p == source.length) {
    // Still typing the name: hold while it can become a known one.
    return tags.names.any((known) => known.startsWith(name)) ? open : -1;
  }
  return tags[name] != null ? open : -1;
}

bool _heldUntilClosed(HtmlTagKind kind) => switch (kind) {
  HtmlTagKind.bold ||
  HtmlTagKind.italic ||
  HtmlTagKind.strike ||
  HtmlTagKind.underline ||
  HtmlTagKind.code ||
  HtmlTagKind.superscript ||
  HtmlTagKind.subscript ||
  HtmlTagKind.highlight ||
  HtmlTagKind.link ||
  HtmlTagKind.hidden ||
  HtmlTagKind.inlineContent ||
  HtmlTagKind.svg ||
  HtmlTagKind.inlineElement => true,
  _ => false,
};

bool _isTagNameChar(int c) =>
    (c >= 0x41 && c <= 0x5A) ||
    (c >= 0x61 && c <= 0x7A) ||
    (c >= 0x30 && c <= 0x39) ||
    c == 0x2D ||
    c == 0x2B ||
    c == 0x2E;

/// Index of the earliest paired tag the parser understands inside a line —
/// `<b>`, `<span>`, `<script>` — whose closing tag has not arrived, or -1.
///
/// Not a block one, `<div>` or `<blockquote>` or an app's block element:
/// those are dropped or rendered as their content arrives.
///
/// Pairs the way the parser does: a closing tag takes the nearest opening
/// tag before it, and of several still open with one name the innermost is
/// the one waited on. In `The <b> tag makes <b>text bo` that is the second
/// `<b>`, so a first `<b>` that was only mentioned does not hold back the
/// words after it. (Should it turn out to be closed after all, the text
/// restyles once; the hold never moves back over what was shown.) A tag
/// whose content is raw — `<code>`, `<script>` — ends at its first closing
/// tag, and nothing inside it counts.
int _lastUnclosedHtmlTag(String text, MarkdownHtml tags) {
  var p = text.indexOf('<');
  if (p == -1) {
    return -1;
  }
  final open = <String, List<int>>{};
  while (p != -1) {
    final tag = htmlTagAt(text, p);
    final syntax = tag == null ? null : tags[tag.name];
    if (tag != null &&
        syntax != null &&
        !tag.isVoid &&
        !tag.closing &&
        _heldUntilClosed(syntax.kind) &&
        htmlContentIsRaw(syntax)) {
      final close = matchingCloseTag(text, tag.name, tag.end, nested: false);
      if (close == null) {
        open.putIfAbsent(tag.name, () => <int>[]).add(p);
        break;
      }
      p = text.indexOf('<', close.end);
      continue;
    }
    if (tag != null &&
        syntax != null &&
        !tag.isVoid &&
        _heldUntilClosed(syntax.kind)) {
      final stack = open.putIfAbsent(tag.name, () => <int>[]);
      if (tag.closing) {
        if (stack.isNotEmpty) {
          stack.removeLast();
        }
      } else {
        stack.add(p);
      }
    }
    p = text.indexOf('<', p + 1);
  }
  var earliest = -1;
  for (final stack in open.values) {
    if (stack.isNotEmpty && (earliest == -1 || stack.last < earliest)) {
      earliest = stack.last;
    }
  }
  return earliest;
}

/// A line that is only a list marker so far: `2`, `12.`, `3)`, `*`, `+`.
final RegExp _partialListMarker = RegExp(r'^\s*(?:\d{1,9}[.)]?|[*+])$');

/// The start of a link or footnote definition line: `[label]:` — or `[label]`
/// alone, which the next character turns into one or not. Revealed early, a
/// `[1]` showed as a citation chip, and since the hold never moves back, the
/// chip stayed until the line ended and then vanished.
final RegExp _definitionStart = RegExp(r'^ {0,3}\[[^\]]+\](?::|$)');

/// A table delimiter row still arriving: only pipes, colons, dashes, spaces.
final RegExp _partialTableSeparator = RegExp(r'^\|[\s|:\-]*$');

/// Blanks list-bullet stars and thematic-break lines out of the emphasis
/// scanner's view, offsets preserved.
String _maskLineMarkers(String text) {
  if (!text.contains('*')) {
    return text;
  }
  final units = text.codeUnits.toList();
  var lineStart = 0;
  void maskLine(int end) {
    var i = lineStart;
    while (i < end && (units[i] == 0x20 || units[i] == 0x09)) {
      i += 1;
    }
    if (i >= end || units[i] != 0x2A /* * */ ) {
      lineStart = end + 1;
      return;
    }
    // `* item` — a bullet: blank the star alone.
    if (i + 1 < end && (units[i + 1] == 0x20 || units[i + 1] == 0x09)) {
      units[i] = 0x20;
      lineStart = end + 1;
      return;
    }
    // `***` (or `* * *`) — a thematic break: blank the whole line.
    var markers = 0;
    var j = i;
    while (j < end) {
      final c = units[j];
      if (c == 0x2A || c == 0x2D /* - */ || c == 0x5F /* _ */ ) {
        markers += 1;
      } else if (c != 0x20 && c != 0x09) {
        lineStart = end + 1;
        return;
      }
      j += 1;
    }
    if (markers >= 3) {
      for (var k = i; k < end; k++) {
        units[k] = 0x20;
      }
    }
    lineStart = end + 1;
  }

  for (var i = 0; i < units.length; i++) {
    if (units[i] == 0x0A) {
      maskLine(i);
    }
  }
  maskLine(units.length);
  return String.fromCharCodes(units);
}

/// Index of the single `$` still open at the end of [text], ignoring every
/// `$$` and every escaped `\$`, or -1.
///
/// The `$` that may still open maths on the last line, or -1.
///
/// Pairs the way the final render does ([DollarMathCloser]). A `$` already
/// paired, or followed by another `$` on its line, is decided. Of the one
/// still waiting for a partner, a price (`$5`, `5$`) shows at once — money is
/// far more common than maths that opens on a digit, and if a closer does
/// turn it into maths the line reflows once. Any other `$`, a lone `$` at
/// the end included, is held.
int _lastUnpairedDollar(String text) {
  final dollars = DollarMathCloser(text);
  var i = text.indexOf(r'$');
  while (i != -1) {
    if (i > 0 && text.codeUnitAt(i - 1) == 0x5C /* \ */ ) {
      i = text.indexOf(r'$', i + 1);
      continue;
    }
    if (i + 1 < text.length && text.codeUnitAt(i + 1) == 0x24 /* $ */ ) {
      i = text.indexOf(r'$', i + 2);
      continue;
    }
    final end = dollars.find(i);
    if (end != -1) {
      i = text.indexOf(r'$', end + 1);
      continue;
    }
    final next = text.indexOf(r'$', i + 1);
    if (next == -1 &&
        !text.contains('\n', i) &&
        !leadsPrice(text, i) &&
        !followsPrice(text, i)) {
      return i;
    }
    i = next;
  }
  return -1;
}

/// Index of the `_` or `__` run still open at the end of [text], or -1.
///
/// Uses the parser's rule: a run opens only with a non-space after it and
/// whitespace or punctuation before it, and closes only with a non-space
/// before it and whitespace or punctuation after it.
int _lastOpenUnderscore(String text) {
  if (!text.contains('_')) {
    return -1;
  }
  var open = -1;
  var i = 0;
  while (i < text.length) {
    if (text.codeUnitAt(i) != 0x5F /* _ */ ) {
      i += 1;
      continue;
    }
    if (i > 0 && text.codeUnitAt(i - 1) == 0x5C /* \ */ ) {
      i += 1;
      continue;
    }
    var run = 1;
    while (i + run < text.length && text.codeUnitAt(i + run) == 0x5F) {
      run += 1;
    }
    final before = codePointBefore(text, i);
    final after = codePointAt(text, i + run);
    final beforeSpaceOrPunct =
        isUnicodeWhitespace(before) || isUnicodePunctuation(before);
    final afterSpaceOrPunct =
        isUnicodeWhitespace(after) || isUnicodePunctuation(after);
    if (open != -1) {
      if (!isUnicodeWhitespace(before) && afterSpaceOrPunct) {
        open = -1;
      }
    } else if (after != -1 &&
        !isUnicodeWhitespace(after) &&
        beforeSpaceOrPunct) {
      open = i;
    }
    i += run;
  }
  return open;
}

/// Index of the last unpaired [token], or -1.
int _lastUnpaired(String text, String token) {
  var count = 0;
  var last = -1;
  var i = text.indexOf(token);
  while (i != -1) {
    count += 1;
    last = i;
    i = text.indexOf(token, i + token.length);
  }
  return count.isOdd ? last : -1;
}

/// Index of the last unpaired single `*`, ignoring every `**`.
int _lastUnpairedStar(String text) {
  var count = 0;
  var last = -1;
  var i = 0;
  while (i < text.length) {
    if (text.codeUnitAt(i) != 0x2A /* * */ ) {
      i += 1;
      continue;
    }
    if (i + 1 < text.length && text.codeUnitAt(i + 1) == 0x2A) {
      i += 2;
      continue;
    }
    count += 1;
    last = i;
    i += 1;
  }
  return count.isOdd ? last : -1;
}
