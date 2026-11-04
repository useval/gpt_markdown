/// Letting a formula render while it is still arriving.
///
/// A formula is literal text until its closing delimiter lands, so a streamed
/// `\( x^2 +` used to be held back whole and then appear at once when `\)`
/// arrived. The maths renderer draws incomplete input — `\frac{a` renders the
/// numerator it has — so the formula can instead grow with the stream: the
/// open formula is closed for the parser, and whatever has arrived renders.
///
/// Not exported: this is the incremental view's policy, not API.
library;

import '../plusparse/scanner.dart';

/// The formula left open at the end of [source], closed so that it parses.
///
/// Returns where its opener starts and the text to render in place of
/// `source.substring(start)`, or null when every formula in [source] is
/// closed. Returns null too when a code span is still open, since its
/// backticks swallow any `\(` inside.
///
/// `\(` and `\[` are always maths; `$$` and `$` only when [dollarsAreMath].
/// A `$` pairs as the final render pairs it ([DollarMathCloser]); one still
/// waiting for its partner is drawn open unless it is a price (`$5`, `5$`),
/// as in the streaming hold. Single-dollar maths does not cross a line
/// break: an opener whose line has ended without a closer is prose.
({int start, String completed})? completeOpenMath(
  String source, {
  required bool dollarsAreMath,
}) {
  final n = source.length;
  final dollars = DollarMathCloser(source);
  var i = 0;
  while (i < n) {
    final c = source.codeUnitAt(i);
    if (c == 0x60 /* ` */ ) {
      final span = codeSpanAt(source, i);
      if (span == null) return null;
      i = span.close + span.run;
      continue;
    }
    if (c == 0x5C /* \ */ && i + 1 < n) {
      final next = source.codeUnitAt(i + 1);
      if (next == 0x28 /* ( */ || next == 0x5B /* [ */ ) {
        final closer = next == 0x28 ? r'\)' : r'\]';
        final end = source.indexOf(closer, i + 2);
        if (end == -1) {
          return _open(source, i, i + 2, source.substring(i, i + 2), closer);
        }
        i = end + 2;
        continue;
      }
      // Any other escape, `\$` included, is one unit.
      i += 2;
      continue;
    }
    if (dollarsAreMath && c == 0x24 /* $ */ ) {
      if (i + 1 < n && source.codeUnitAt(i + 1) == 0x24) {
        final end = source.indexOf(r'$$', i + 2);
        if (end == -1) {
          return _open(source, i, i + 2, r'\[', r'\]', dollarBlock: true);
        }
        i = end + 2;
        continue;
      }
      final end = dollars.find(i);
      if (end == -1) {
        // Still open only while it waits for a partner on the last line,
        // and only if it is not a price: `$5` and `5$` show as text until a
        // closer makes them maths. A `$` before a space is held rather than
        // drawn, so `pay $ 5` never flashes as a formula.
        final next = i + 1 < n ? source.codeUnitAt(i + 1) : -1;
        if (!source.contains('\n', i) &&
            next != -1 &&
            !isUnicodeWhitespace(next) &&
            !source.contains(r'$', i + 1) &&
            !leadsPrice(source, i) &&
            !followsPrice(source, i)) {
          return _open(source, i, i + 1, r'\(', r'\)');
        }
        i += 1;
        continue;
      }
      i = end + 1;
      continue;
    }
    i += 1;
  }
  return null;
}

({int start, String completed})? _open(
  String source,
  int start,
  int bodyStart,
  String opener,
  String closer, {
  bool dollarBlock = false,
}) {
  var body = _withoutPartialTail(source.substring(bodyStart));
  // Half of a `$$` closer: the first `$` has landed and the second is in the
  // next chunk. Left in, it is a `$` inside maths, which the parser rejects,
  // and the formula's error fallback painted the raw TeX source — a flash of
  // source and a jump in height — for exactly one chunk at the end of every
  // dollar block whose closer was split. An escaped `\$` is a literal dollar
  // and stays.
  if (dollarBlock && _partialDollarCloser.hasMatch(body)) {
    body = body.substring(0, body.length - 1);
  }
  // Nothing to draw yet: an empty formula would only flash an empty box.
  if (body.trim().isEmpty) return null;
  return (start: start, completed: '$opener$body $closer');
}

/// [body] without a command name that may still be growing (`\fra` before
/// `\frac`) or an environment name still arriving (`\begin{ali`). The next
/// character decides either, so this holds back a few characters at most.
String _withoutPartialTail(String body) => body
    .replaceFirst(_partialEnvironment, '')
    .replaceFirst(_partialCommand, '');

final RegExp _partialEnvironment = RegExp(r'\\(?:begin|end)\{[^}]*$');
final RegExp _partialCommand = RegExp(r'\\[a-zA-Z]*$');
final RegExp _partialDollarCloser = RegExp(r'(?<!\\)\$$');
