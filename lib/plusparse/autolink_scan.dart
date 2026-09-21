part of '../gpt_markdown.dart';

/// Autolinks one run of plain text, without running a regex over it.
///
/// This is the plusparse counterpart of dispatching [AutolinkMd] through
/// [MarkdownComponent.generate], and it exists for one reason: proving that a
/// run holds *no* link is the common case, and a regex is terrible at it. The
/// combined pattern is an alternation of six forms, five of which can start at
/// almost any character, so the engine backtracks at every word of ordinary
/// prose. Measured on a 2598-character link-free run it cost 487 us, against
/// 18 us for a character scan — roughly 95% of the parse stage, and a tenth of
/// a cold frame, spent proving a negative.
///
/// Only *candidate detection* is reimplemented here. Which substrings are
/// candidates is defined by `AutolinkMd._pattern`; what a candidate resolves
/// to — scheme allow-list, GFM trailing punctuation, paren balancing, entity
/// references, the valid-domain rule — is [AutolinkMd] `_parseAngle` and
/// `_parseBare`, called unchanged, so there is exactly one implementation of
/// the semantics and this file cannot drift away from it.
///
/// `test/regression/autolink_parity_test.dart` runs both paths over the same
/// corpus and compares the span trees.
List<InlineSpan> autolinkSpans(
  BuildContext context,
  String text,
  GptMarkdownConfig config,
) {
  if (text.isEmpty) {
    // `MarkdownComponent.generate` contributes nothing for an empty run.
    return const <InlineSpan>[];
  }
  if (!config.autolink ||
      // `AutolinkMd.scopes` is `allScopesExceptLinkLabel`, and `generate`
      // filters on it before it builds the combined regex. A link label is
      // already inside the outer link's span, so nothing may link there.
      !MarkdownComponent.allScopesExceptLinkLabel.contains(config.scope) ||
      !_AutolinkScan.mayHoldLink(text)) {
    return [TextSpan(text: text, style: config.style)];
  }
  return _AutolinkScan.spans(context, text, config);
}

/// The character scan behind [autolinkSpans].
///
/// Every method here is a hand-translation of one alternative of
/// `AutolinkMd._pattern`, including its greediness and the backtracking that
/// follows from it. The pattern is compiled case-insensitively, which for
/// these alternatives only matters for the literals `www` and `mailto`/`xmpp`
/// — every other element is a character class that already spells both cases
/// out. (Dart's regex is not in Unicode mode, so case folding never reaches
/// across the ASCII boundary: `K` does not match `k`.)
///
/// The alternation rules the scan has to honour:
///
/// * **leftmost wins** — the earliest start position that matches anything;
/// * **first alternative wins** — at that position, the earliest-listed form,
///   whatever its length. Form 5 before form 6 is the case where that is
///   visible: `www.x@y.com/path` is one `www.` link to the end of the run,
///   not the email `www.x@y.com` with a path left over;
/// * scanning resumes at the end of the match, never inside it.
class _AutolinkScan {
  _AutolinkScan._();

  static const int _tab = 0x09;
  static const int _cr = 0x0D;
  static const int _space = 0x20;
  static const int _exclaim = 0x21;
  static const int _hash = 0x23;
  static const int _percent = 0x25;
  static const int _amp = 0x26;
  static const int _quote = 0x27;
  static const int _star = 0x2A;
  static const int _plus = 0x2B;
  static const int _hyphen = 0x2D;
  static const int _dot = 0x2E;
  static const int _slash = 0x2F;
  static const int _colon = 0x3A;
  static const int _lt = 0x3C;
  static const int _equals = 0x3D;
  static const int _gt = 0x3E;
  static const int _question = 0x3F;
  static const int _at = 0x40;
  static const int _caret = 0x5E;
  static const int _underscore = 0x5F;
  static const int _backtick = 0x60;
  static const int _lowerW = 0x77;
  static const int _upperW = 0x57;
  static const int _braceOpen = 0x7B;
  static const int _bar = 0x7C;
  static const int _braceClose = 0x7D;
  static const int _tilde = 0x7E;

  /// The longest scheme the angle form accepts: `[A-Za-z]` plus `{1,31}`.
  static const int _maxAngleSchemeTail = 31;

  /// The longest DNS label the angle-email form accepts: `1 + 61 + 1`.
  static const int _maxDomainLabel = 63;

  /// Whether [text] can hold a candidate at all.
  ///
  /// Every form needs `<`, `:`, `@` or the literal `www.`; prose usually has
  /// none of them, and this pass then rejects the whole run with a handful of
  /// integer compares and no allocation. It never rejects a run the scan would
  /// have found something in, so it can only save work.
  static bool mayHoldLink(String text) {
    final n = text.length;
    for (var i = 0; i < n; i++) {
      final c = text.codeUnitAt(i);
      if (c == _lt || c == _colon || c == _at) {
        return true;
      }
      if ((c == _lowerW || c == _upperW) && _isWwwDot(text, i, n)) {
        return true;
      }
    }
    return false;
  }

  /// Scans [text] and builds its spans.
  static List<InlineSpan> spans(
    BuildContext context,
    String text,
    GptMarkdownConfig config,
  ) {
    final n = text.length;
    final style = config.style;
    // Allocated only once something is actually linked; a run that holds an
    // anchor but no link still costs nothing beyond the scan.
    List<InlineSpan>? out;
    var plainStart = 0;
    var i = 0;

    while (i < n) {
      final c = text.codeUnitAt(i);
      final bool angle;
      final int end;

      if (c == _lt) {
        angle = true;
        final match = _matchAngle(text, i, n);
        if (match < 0) {
          i++;
          continue;
        }
        end = match;
      } else if (_isBareStartChar(c)) {
        angle = false;
        if (i > 0 && _isBoundaryChar(text.codeUnitAt(i - 1))) {
          // The lookbehind rejects this position — and every position inside
          // the run that starts here, since each of those is preceded by a
          // run character, which is always a boundary character too.
          i = _bareRunEnd(text, i, n);
          continue;
        }
        final match = _matchBare(text, i, n);
        if (match < 0) {
          // Same argument: nothing inside the run can start a match either.
          i = _bareRunEnd(text, i, n);
          continue;
        }
        end = match;
      } else {
        i++;
        continue;
      }

      final element = text.substring(i, end);
      final resolved =
          angle
              ? AutolinkMd._parseAngle(element)
              : AutolinkMd._parseBare(element, config.autolinkSchemes);
      if (resolved == null) {
        // The regex claimed this too, and `AutolinkMd.span` handed it straight
        // back as text. It stays part of the pending plain run.
        i = end;
        continue;
      }

      out ??= <InlineSpan>[];
      if (i > plainStart) {
        out.add(TextSpan(text: text.substring(plainStart, i), style: style));
      }
      out.add(
        buildLinkSpan(
          context,
          config,
          url: resolved.url,
          label: resolved.label,
          // The label is the URL itself; see `AutolinkMd.span`.
          parseLabel: false,
        ),
      );
      // Whatever the link did not take — GFM's trailing punctuation — goes
      // back into the plain run. The regex path put it in a sibling
      // `TextSpan`; both render the same characters in the same order.
      plainStart = end - resolved.trailing.length;
      i = end;
    }

    if (out == null) {
      return [TextSpan(text: text, style: style)];
    }
    if (plainStart < n) {
      out.add(TextSpan(text: text.substring(plainStart), style: style));
    }
    return out;
  }

  // ───────────────────────── the six alternatives ─────────────────────────

  /// Forms 1 and 2, in that order. Returns the end of the match, or -1.
  static int _matchAngle(String text, int start, int n) {
    final scheme = _matchAngleScheme(text, start, n);
    if (scheme >= 0) {
      return scheme;
    }
    return _matchAngleEmail(text, start, n);
  }

  /// Form 1: `<[A-Za-z][A-Za-z0-9+.\-]{1,31}:[^<>\x00-\x20]*>`.
  static int _matchAngleScheme(String text, int start, int n) {
    var p = start + 1;
    if (p >= n || !_isAlpha(text.codeUnitAt(p))) {
      return -1;
    }
    p++;
    var tail = 0;
    while (p < n && _isSchemeChar(text.codeUnitAt(p))) {
      p++;
      tail++;
      if (tail > _maxAngleSchemeTail) {
        // A 32nd scheme character means every position the `:` could have
        // been backtracked to holds a scheme character instead.
        return -1;
      }
    }
    if (tail < 1 || p >= n || text.codeUnitAt(p) != _colon) {
      return -1;
    }
    p++;
    while (p < n) {
      final c = text.codeUnitAt(p);
      if (c == _gt) {
        return p + 1;
      }
      // `[^<>\x00-\x20]` — note this excludes every control character, not
      // just the ones `\s` covers.
      if (c == _lt || c <= _space) {
        return -1;
      }
      p++;
    }
    return -1;
  }

  /// Form 2: `<local@domain>`, with the domain-label shape spelled out.
  static int _matchAngleEmail(String text, int start, int n) {
    var p = start + 1;
    final localStart = p;
    while (p < n && _isAngleLocalChar(text.codeUnitAt(p))) {
      p++;
    }
    // `@` is not in the local class, so a shorter local part could never be
    // followed by one either: there is nothing to backtrack to.
    if (p == localStart || p >= n || text.codeUnitAt(p) != _at) {
      return -1;
    }
    p++;
    final domainStart = p;
    while (p < n && _isDomainRunChar(text.codeUnitAt(p))) {
      p++;
    }
    // `>` is not a domain character, so the only end position the domain
    // could be followed by one at is the end of the run — which is why no
    // backtracking over the labels is needed here.
    if (p >= n || text.codeUnitAt(p) != _gt) {
      return -1;
    }
    if (!_isAngleDomain(text, domainStart, p)) {
      return -1;
    }
    return p + 1;
  }

  /// Forms 3 to 6, in that order, at a position the lookbehind allows.
  /// Returns the end of the match, or -1.
  static int _matchBare(String text, int start, int n) {
    // Form 3: `[A-Za-z][A-Za-z0-9+.\-]*://[^\s<]+`.
    if (_isAlpha(text.codeUnitAt(start))) {
      var p = start + 1;
      while (p < n && _isSchemeChar(text.codeUnitAt(p))) {
        p++;
      }
      if (p + 2 < n &&
          text.codeUnitAt(p) == _colon &&
          text.codeUnitAt(p + 1) == _slash &&
          text.codeUnitAt(p + 2) == _slash) {
        final end = _urlRunEnd(text, p + 3, n);
        // `[^\s<]+` needs one character. Without it this alternative fails and
        // the next one is tried at the same position.
        if (end > p + 3) {
          return end;
        }
      }
    }

    // Form 4: `(?:mailto|xmpp):[^\s<]+`.
    final authority = _schemelessAuthorityEnd(text, start, n);
    if (authority >= 0) {
      final end = _urlRunEnd(text, authority, n);
      if (end > authority) {
        return end;
      }
    }

    // Form 5: `www\.[^\s<]+`.
    if (_isWwwDot(text, start, n)) {
      final end = _urlRunEnd(text, start + 4, n);
      if (end > start + 4) {
        return end;
      }
    }

    // Form 6: the bare email.
    return _matchBareEmail(text, start, n);
  }

  /// Form 6: `[A-Za-z0-9._+-]+@[A-Za-z0-9][A-Za-z0-9._-]*\.[A-Za-z0-9-]+`.
  static int _matchBareEmail(String text, int start, int n) {
    var p = start;
    while (p < n && _isBareStartChar(text.codeUnitAt(p))) {
      p++;
    }
    if (p == start || p >= n || text.codeUnitAt(p) != _at) {
      return -1;
    }
    p++;
    if (p >= n || !_isAlnum(text.codeUnitAt(p))) {
      return -1;
    }
    final bodyStart = p + 1;
    var bodyEnd = bodyStart;
    while (bodyEnd < n && _isEmailDomainChar(text.codeUnitAt(bodyEnd))) {
      bodyEnd++;
    }
    // `[A-Za-z0-9._-]*` is greedy, so the engine takes the *last* `.` that
    // still leaves a label after it. Neither the dot nor that label can sit
    // outside the run: both classes are subsets of the run's.
    for (var dot = bodyEnd - 2; dot >= bodyStart; dot--) {
      if (text.codeUnitAt(dot) != _dot ||
          !_isLabelChar(text.codeUnitAt(dot + 1))) {
        continue;
      }
      var end = dot + 1;
      while (end < n && _isLabelChar(text.codeUnitAt(end))) {
        end++;
      }
      return end;
    }
    return -1;
  }

  // ─────────────────────────── character classes ───────────────────────────

  /// `[A-Za-z]`.
  static bool _isAlpha(int c) =>
      (c >= 0x61 && c <= 0x7A) || (c >= 0x41 && c <= 0x5A);

  /// `[0-9]`.
  static bool _isDigit(int c) => c >= 0x30 && c <= 0x39;

  /// `[A-Za-z0-9]`.
  static bool _isAlnum(int c) => _isDigit(c) || _isAlpha(c);

  /// `[A-Za-z0-9+.\-]`, the scheme tail of forms 1 and 3.
  static bool _isSchemeChar(int c) =>
      _isAlnum(c) || c == _plus || c == _dot || c == _hyphen;

  /// `[\w@.+/-]`, the lookbehind that keeps a link from starting mid-word,
  /// mid-path or mid-address.
  ///
  /// Only `@` and `/` are ever decisive: every other character here is also a
  /// run character, so a position preceded by one is inside a run the scan
  /// already skipped whole. Spelling the class out anyway is what keeps it
  /// checkable against the pattern.
  static bool _isBoundaryChar(int c) =>
      _isAlnum(c) ||
      c == _underscore ||
      c == _at ||
      c == _dot ||
      c == _plus ||
      c == _slash ||
      c == _hyphen;

  /// `[A-Za-z0-9._+-]` — form 6's local part, and a superset of the first
  /// character of every bare form.
  static bool _isBareStartChar(int c) =>
      _isAlnum(c) ||
      c == _dot ||
      c == _underscore ||
      c == _plus ||
      c == _hyphen;

  /// `[A-Za-z0-9._-]`, form 6's domain body.
  static bool _isEmailDomainChar(int c) =>
      _isAlnum(c) || c == _dot || c == _underscore || c == _hyphen;

  /// `[A-Za-z0-9-]`, form 6's last label and the body of a DNS label.
  static bool _isLabelChar(int c) => _isAlnum(c) || c == _hyphen;

  /// The characters a form-2 domain can be built from.
  static bool _isDomainRunChar(int c) => _isLabelChar(c) || c == _dot;

  /// ``[A-Za-z0-9.!#$%&'*+/=?^_`{|}~-]``, form 2's local part.
  static bool _isAngleLocalChar(int c) {
    if (_isAlnum(c)) {
      return true;
    }
    switch (c) {
      case _dot:
      case _exclaim:
      case _hash:
      case 0x24: // $
      case _percent:
      case _amp:
      case _quote:
      case _star:
      case _plus:
      case _slash:
      case _equals:
      case _question:
      case _caret:
      case _underscore:
      case _backtick:
      case _braceOpen:
      case _bar:
      case _braceClose:
      case _tilde:
      case _hyphen:
        return true;
    }
    return false;
  }

  /// ECMAScript `\s`: the Unicode space separators, plus the ASCII control
  /// whitespace and the two line separators. Deliberately *not* `<= 0x20`,
  /// which would also swallow the other C0 controls.
  static bool _isSpaceChar(int c) {
    if (c <= _space) {
      return c == _space || (c >= _tab && c <= _cr);
    }
    if (c < 0xA0) {
      return false;
    }
    return c == 0xA0 ||
        c == 0x1680 ||
        (c >= 0x2000 && c <= 0x200A) ||
        c == 0x2028 ||
        c == 0x2029 ||
        c == 0x202F ||
        c == 0x205F ||
        c == 0x3000 ||
        c == 0xFEFF;
  }

  // ───────────────────────────── small scans ─────────────────────────────

  /// The end of `[^\s<]+` starting at [from].
  static int _urlRunEnd(String text, int from, int n) {
    var p = from;
    while (p < n) {
      final c = text.codeUnitAt(p);
      if (c == _lt || _isSpaceChar(c)) {
        break;
      }
      p++;
    }
    return p;
  }

  /// The end of the `[A-Za-z0-9._+-]` run starting at [from], which is where
  /// the next position the lookbehind could accept begins.
  static int _bareRunEnd(String text, int from, int n) {
    var p = from;
    while (p < n && _isBareStartChar(text.codeUnitAt(p))) {
      p++;
    }
    // Always makes progress: the caller only reaches this with a run
    // character under the cursor.
    return p > from ? p : from + 1;
  }

  /// `www\.`, case-insensitively.
  static bool _isWwwDot(String text, int start, int n) {
    return start + 3 < n &&
        (text.codeUnitAt(start) | 0x20) == _lowerW &&
        (text.codeUnitAt(start + 1) | 0x20) == _lowerW &&
        (text.codeUnitAt(start + 2) | 0x20) == _lowerW &&
        text.codeUnitAt(start + 3) == _dot;
  }

  /// The index just past `mailto:` or `xmpp:`, case-insensitively, or -1.
  static int _schemelessAuthorityEnd(String text, int start, int n) {
    if (_matchesIgnoringCase(text, start, n, 'mailto:')) {
      return start + 7;
    }
    if (_matchesIgnoringCase(text, start, n, 'xmpp:')) {
      return start + 5;
    }
    return -1;
  }

  /// Whether [text] holds [lower] at [start]. [lower] must be ASCII and hold
  /// no character whose case-folded form is ambiguous — the literals here are
  /// `mailto:` and `xmpp:`.
  static bool _matchesIgnoringCase(
    String text,
    int start,
    int n,
    String lower,
  ) {
    if (start + lower.length > n) {
      return false;
    }
    for (var i = 0; i < lower.length; i++) {
      final expected = lower.codeUnitAt(i);
      final actual = text.codeUnitAt(start + i);
      if (actual != expected &&
          !(_isAlpha(expected) && (actual | 0x20) == expected)) {
        return false;
      }
    }
    return true;
  }

  /// Whether `text[start, end)` is form 2's domain: dot-separated labels of
  /// 1 to 63 characters, each starting and ending alphanumeric.
  static bool _isAngleDomain(String text, int start, int end) {
    var labelStart = start;
    for (var p = start; p <= end; p++) {
      if (p < end && text.codeUnitAt(p) != _dot) {
        continue;
      }
      final length = p - labelStart;
      if (length < 1 ||
          length > _maxDomainLabel ||
          !_isAlnum(text.codeUnitAt(labelStart)) ||
          !_isAlnum(text.codeUnitAt(p - 1))) {
        return false;
      }
      labelStart = p + 1;
    }
    return true;
  }
}
