/// Block parser: walks the document line-by-line and produces block-level
/// [MdNode]s, recursing into the inline parser for text content and into
/// itself for nested content (list items, blockquotes). Single pass,
/// error-tolerant: it never throws on malformed or partial (streaming) input.
/// Ported 1:1 from the Rust plusparse block parser.
library;

import 'ast.dart';
import 'block_syntax.dart';
import 'inline_parser.dart';
import 'scanner.dart';

MdDocument parseDocument(
  String src,
  bool useDollar, [
  MarkdownBlockRegistry? registry,
]) {
  // Two full rewrites of the source, for a character most sources do not
  // contain. Checking first is one scan that usually ends in none.
  final normalized =
      src.contains('\r')
          ? src.replaceAll('\r\n', '\n').replaceAll('\r', '\n')
          : src;
  final lines = normalized.split('\n');
  return MdDocument(children: parseBlocks(lines, useDollar, registry));
}

List<MdNode> parseBlocks(
  List<String> lines,
  bool useDollar, [
  MarkdownBlockRegistry? registry,
]) {
  final out = <MdNode>[];
  final n = lines.length;
  var i = 0;

  while (i < n) {
    final raw = lines[i];
    if (isBlank(raw)) {
      i += 1;
      continue;
    }
    final trimmed = raw.trimLeft();

    final custom = registry?.match(lines, i);
    if (custom != null) {
      out.add(custom.node);
      i = custom.endLine;
      continue;
    }

    // Fenced code block ```lang ... ```
    if (trimmed.startsWith('```')) {
      final language = trimmed.substring(3).trim();
      i += 1;
      final code = <String>[];
      var closed = false;
      while (i < n) {
        if (lines[i].trimLeft().startsWith('```')) {
          closed = true;
          i += 1;
          break;
        }
        code.add(lines[i]);
        i += 1;
      }
      out.add(
        MdCodeBlock(language: language, code: code.join('\n'), closed: closed),
      );
      continue;
    }

    // Block LaTeX \[ ... \]
    if (trimmed.startsWith('\\[')) {
      var first = trimmed;
      while (first.startsWith('\\[')) {
        first = first.substring(2);
      }
      final end = first.indexOf('\\]');
      if (end != -1) {
        out.add(MdBlockLatex(tex: first.substring(0, end).trim()));
        i += 1;
        continue;
      }
      final content = <String>[];
      if (first.trim().isNotEmpty) {
        content.add(first);
      }
      i += 1;
      while (i < n) {
        final lineEnd = lines[i].indexOf('\\]');
        if (lineEnd != -1) {
          final pre = lines[i].substring(0, lineEnd);
          if (pre.trim().isNotEmpty) {
            content.add(pre);
          }
          i += 1;
          break;
        }
        content.add(lines[i]);
        i += 1;
      }
      out.add(MdBlockLatex(tex: content.join('\n').trim()));
      continue;
    }

    // Heading
    final heading = isHeading(trimmed);
    if (heading != null) {
      out.add(
        MdHeading(
          level: heading.level,
          children: parseInline(heading.content, useDollar),
        ),
      );
      i += 1;
      continue;
    }

    // Horizontal rule
    if (isHr(trimmed)) {
      out.add(const MdHorizontalRule());
      i += 1;
      continue;
    }

    // Blockquote
    if (trimmed.startsWith('>')) {
      final inner = <String>[];
      while (i < n) {
        if (isBlank(lines[i])) {
          break;
        }
        final t = lines[i].trimLeft();
        if (t.startsWith('>')) {
          var stripped = t.substring(1);
          if (stripped.startsWith(' ')) {
            stripped = stripped.substring(1);
          }
          inner.add(stripped);
        } else {
          // lazy continuation line
          inner.add(t);
        }
        i += 1;
      }
      out.add(MdBlockQuote(children: parseBlocks(inner, useDollar, registry)));
      continue;
    }

    // Table
    final tableEnd = _tryTable(lines, i, useDollar, out);
    if (tableEnd != null) {
      i = tableEnd;
      continue;
    }

    // Checkbox / radio
    final checkbox = checkboxMarker(trimmed);
    if (checkbox != null) {
      out.add(
        MdCheckbox(
          checked: checkbox.checked,
          children: parseInline(checkbox.content, useDollar),
        ),
      );
      i += 1;
      continue;
    }
    final radio = radioMarker(trimmed);
    if (radio != null) {
      out.add(
        MdRadio(
          selected: radio.selected,
          children: parseInline(radio.content, useDollar),
        ),
      );
      i += 1;
      continue;
    }

    // Lists
    if (unorderedMarker(trimmed) != null) {
      final r = _parseListInner(lines, i, false, useDollar, registry);
      out.add(MdUnorderedList(items: r.items));
      i = r.next;
      continue;
    }
    if (orderedMarker(trimmed) != null) {
      final r = _parseListInner(lines, i, true, useDollar, registry);
      out.add(MdOrderedList(start: r.start, items: r.items));
      i = r.next;
      continue;
    }

    // Paragraph: gather consecutive non-blank, non-block lines.
    final para = <String>[];
    while (i < n) {
      if (isBlank(lines[i])) {
        break;
      }
      final t = lines[i].trimLeft();
      if (_startsBlock(t) ||
          (para.isNotEmpty && registry?.match(lines, i) != null)) {
        break;
      }
      para.add(t);
      i += 1;
    }
    // Joined on the newline, not on a space. CommonMark folds a single
    // newline inside a paragraph into a space, and this package has never
    // done that: a model writes a list of bullet glyphs, or a run of short
    // lines, and folding them produced one long wrapped line. Folding also
    // swallowed the two breaks CommonMark does define — two trailing spaces
    // and a trailing backslash — because the newline they mark was gone
    // before the inline parser ran.
    out.add(MdParagraph(children: parseInline(para.join('\n'), useDollar)));
  }

  return out;
}

/// Does the (already left-trimmed) line begin a block construct? Used to know
/// where a paragraph ends.
bool _startsBlock(String t) {
  return t.startsWith('```') ||
      t.startsWith('\\[') ||
      isHeading(t) != null ||
      isHr(t) ||
      t.startsWith('>') ||
      checkboxMarker(t) != null ||
      radioMarker(t) != null ||
      unorderedMarker(t) != null ||
      orderedMarker(t) != null;
}

/// Parse a list starting at [start]. Handles indentation-based nesting: lines
/// indented past the marker become the item's nested blocks. Returns the
/// items, the index after the list, and the first ordered number (1 for
/// unordered).
({List<MdListItem> items, int next, int start}) _parseListInner(
  List<String> lines,
  int start,
  bool ordered,
  bool useDollar,
  MarkdownBlockRegistry? registry,
) {
  final n = lines.length;
  final base = indentWidth(lines[start]);
  final items = <MdListItem>[];
  var firstNum = 1;
  var gotFirst = false;
  var i = start;

  while (i < n) {
    if (isBlank(lines[i])) {
      // Skip blank lines only if another item at the same level follows.
      var j = i + 1;
      while (j < n && isBlank(lines[j])) {
        j += 1;
      }
      if (j < n &&
          indentWidth(lines[j]) == base &&
          _markerMatches(lines[j], ordered)) {
        i = j;
        continue;
      }
      break;
    }
    if (indentWidth(lines[i]) != base) {
      break;
    }
    final trimmed = lines[i].trimLeft();
    final split = _splitMarker(trimmed, ordered);
    if (split == null) {
      break;
    }
    if (!gotFirst) {
      firstNum = split.number;
      gotFirst = true;
    }
    // Column where the item content begins (markers are ASCII).
    final contentCol = base + (trimmed.length - split.content.length);

    // Block maths opened on the marker line — `1. \\[` with the body on the
    // lines below.
    //
    // The body is opaque, like a fence: its lines are maths, not Markdown, and
    // they are not indented under the marker. The nested-line scan below only
    // takes lines indented past the marker, so without claiming them here the
    // `\\[` stayed literal text and the body leaked out of the list as a
    // paragraph with a stray `\\]`.
    final latex = _listItemBlockLatex(lines, i, split.content);

    // Collect nested lines (indented past the marker).
    final nested = <String>[];
    var k = (latex?.next ?? i + 1);
    while (k < n) {
      if (isBlank(lines[k])) {
        nested.add('');
        k += 1;
        continue;
      }
      if (indentWidth(lines[k]) > base) {
        nested.add(stripIndent(lines[k], contentCol));
        k += 1;
      } else {
        break;
      }
    }
    while (nested.isNotEmpty && nested.last.trim().isEmpty) {
      nested.removeLast();
    }

    // A task list — `- [x] item` — is a checkbox wearing a list marker. The
    // checkbox is a block-level node, and an item's content is parsed inline,
    // so without this the marker survives as the literal text `[x] item`.
    // Checked before the inline parse for the same reason: `[x]` inline is
    // just a bracketed letter.
    final children = <MdNode>[];
    final task = latex == null ? checkboxMarker(split.content) : null;
    final choice =
        task == null && latex == null ? radioMarker(split.content) : null;
    if (latex != null) {
      children.add(MdBlockLatex(tex: latex.tex));
    } else if (task != null) {
      children.add(
        MdCheckbox(
          checked: task.checked,
          children: parseInline(task.content, useDollar),
        ),
      );
    } else if (choice != null) {
      children.add(
        MdRadio(
          selected: choice.selected,
          children: parseInline(choice.content, useDollar),
        ),
      );
    } else {
      children.addAll(parseInline(split.content, useDollar));
    }
    if (nested.isNotEmpty) {
      children.addAll(parseBlocks(nested, useDollar, registry));
    }
    items.add(
      MdListItem(children: children, number: ordered ? split.number : null),
    );
    i = k;
  }

  return (items: items, next: i, start: firstNum);
}

/// Block maths opened by a list item's own content, if any.
///
/// Mirrors the top-level `\\[ ... \\]` rule, including consuming to the end of
/// the document when the closer has not arrived yet — a streaming reply's
/// equation is still being written, and showing it as literal text until the
/// last character lands reads worse than showing nothing.
///
/// [next] is the line to resume scanning from.
({String tex, int next})? _listItemBlockLatex(
  List<String> lines,
  int index,
  String content,
) {
  var first = content.trimLeft();
  if (!first.startsWith('\\[')) {
    return null;
  }
  while (first.startsWith('\\[')) {
    first = first.substring(2);
  }
  // Closed on the same line: leave it to the inline parser, which keeps any
  // text on either side of it. Claiming the whole line here would drop a
  // trailing `done` in `1. \\[ x^2 \\] done`.
  if (first.contains('\\]')) {
    return null;
  }
  final body = <String>[];
  if (first.trim().isNotEmpty) {
    body.add(first);
  }
  var k = index + 1;
  while (k < lines.length) {
    final close = lines[k].indexOf('\\]');
    if (close != -1) {
      final pre = lines[k].substring(0, close);
      if (pre.trim().isNotEmpty) {
        body.add(pre);
      }
      k += 1;
      break;
    }
    body.add(lines[k]);
    k += 1;
  }
  return (tex: body.join('\n').trim(), next: k);
}

bool _markerMatches(String line, bool ordered) {
  final t = line.trimLeft();
  return ordered ? orderedMarker(t) != null : unorderedMarker(t) != null;
}

({String content, int number})? _splitMarker(String trimmed, bool ordered) {
  if (ordered) {
    final m = orderedMarker(trimmed);
    if (m == null) {
      return null;
    }
    return (content: m.content, number: m.number);
  }
  final content = unorderedMarker(trimmed);
  if (content == null) {
    return null;
  }
  return (content: content, number: 0);
}

/// Detect and parse a pipe table starting at [i] (header row + `:---:`
/// separator + body rows). Returns the index after the table, or null if not
/// a table.
int? _tryTable(List<String> lines, int i, bool useDollar, List<MdNode> out) {
  final n = lines.length;
  final headerLine = lines[i].trim();
  if (!headerLine.contains('|') || i + 1 >= n) {
    return null;
  }
  final sepLine = lines[i + 1].trim();
  if (!_isTableSeparator(sepLine)) {
    return null;
  }
  final aligns = _parseAligns(sepLine);
  final header = MdTableRow(cells: _splitTableRow(headerLine, useDollar));
  final rows = <MdTableRow>[];
  var k = i + 2;
  while (k < n) {
    final l = lines[k].trim();
    if (l.isEmpty || !l.contains('|')) {
      break;
    }
    rows.add(MdTableRow(cells: _splitTableRow(l, useDollar)));
    k += 1;
  }
  out.add(MdTable(aligns: aligns, header: header, rows: rows));
  return k;
}

bool _isTableSeparator(String line) {
  final t = line.trim();
  if (!t.contains('-') || !t.contains('|')) {
    return false;
  }
  // A separator cell is only `-` and `:`, so the escape/math rules cannot
  // change the outcome here; useDollar is false to keep the fast path.
  final cells = _splitPipes(t, false);
  if (cells.isEmpty) {
    return false;
  }
  for (final cell in cells) {
    final c = cell.trim();
    if (c.isEmpty || !c.contains('-')) {
      return false;
    }
    for (var idx = 0; idx < c.length; idx++) {
      final ch = c[idx];
      if (ch != '-' && ch != ':') {
        return false;
      }
    }
  }
  return true;
}

List<MdAlign> _parseAligns(String line) {
  return _splitPipes(line, false).map((cell) {
    final c = cell.trim();
    final left = c.startsWith(':');
    final right = c.endsWith(':');
    if (left && right) {
      return MdAlign.center;
    }
    if (right) {
      return MdAlign.right;
    }
    if (left) {
      return MdAlign.left;
    }
    return MdAlign.none;
  }).toList();
}

List<String> _splitPipes(String line, bool useDollar) {
  var t = line.trim();
  if (t.startsWith('|')) {
    t = t.substring(1);
  }
  if (t.endsWith('|')) {
    t = t.substring(0, t.length - 1);
  }
  // Fast path: no construct can hide a pipe, so the native split is correct.
  if (!t.contains('\\') &&
      !t.contains('`') &&
      !(useDollar && t.contains(r'$'))) {
    return t.split('|');
  }
  return _splitPipesScanning(t, useDollar);
}

/// Splits on `|` at depth zero only. Pipes inside code spans, `\(…\)` and
/// (when enabled) `$…$` math, or escaped as `\|`, stay inside their cell.
///
/// The skip rules mirror [parseInline] exactly — same terminators, same
/// fallbacks — so a span that survives the split is the same span the inline
/// parser will later recognise.
List<String> _splitPipesScanning(String t, bool useDollar) {
  const backslash = 0x5C;
  const backtick = 0x60;
  const dollar = 0x24;
  const pipe = 0x7C;
  const openParen = 0x28;

  final cells = <String>[];
  final buf = StringBuffer();
  final n = t.length;
  var i = 0;

  while (i < n) {
    final c = t.codeUnitAt(i);

    // `code span` — single tick, matching parseInline's indexOf('`').
    if (c == backtick) {
      final end = t.indexOf('`', i + 1);
      if (end != -1) {
        buf.write(t.substring(i, end + 1));
        i = end + 1;
        continue;
      }
    }

    if (c == backslash && i + 1 < n) {
      // \( inline latex \)
      if (t.codeUnitAt(i + 1) == openParen) {
        final end = t.indexOf('\\)', i + 2);
        if (end != -1) {
          buf.write(t.substring(i, end + 2));
          i = end + 2;
          continue;
        }
      }
      // Any other \X escapes X — including \| — and is kept verbatim for the
      // inline parser to unescape.
      buf.write(t.substring(i, i + 2));
      i += 2;
      continue;
    }

    if (useDollar && c == dollar) {
      var matched = false;
      if (i + 1 < n && t.codeUnitAt(i + 1) == dollar) {
        final end = t.indexOf(r'$$', i + 2);
        if (end != -1) {
          buf.write(t.substring(i, end + 2));
          i = end + 2;
          matched = true;
        }
      }
      if (!matched) {
        final end = t.indexOf(r'$', i + 1);
        // parseInline requires non-blank content for a single-$ span.
        if (end != -1 && t.substring(i + 1, end).trim().isNotEmpty) {
          buf.write(t.substring(i, end + 1));
          i = end + 1;
          matched = true;
        }
      }
      if (matched) {
        continue;
      }
    }

    if (c == pipe) {
      cells.add(buf.toString());
      buf.clear();
      i += 1;
      continue;
    }

    buf.writeCharCode(c);
    i += 1;
  }

  cells.add(buf.toString());
  return cells;
}

List<MdTableCell> _splitTableRow(String line, bool useDollar) {
  return _splitPipes(
    line,
    useDollar,
  ).map((c) => MdTableCell(content: parseInline(c.trim(), useDollar))).toList();
}
