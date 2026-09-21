part of 'gpt_markdown.dart';

/// Builds the span for one [InlineDirective] occurrence.
///
/// [payload] is the text between the delimiters, verbatim — the parser never
/// looked at it, so whatever the host put there is what arrives here.
typedef InlineDirectiveBuilder =
    InlineSpan Function(BuildContext context, String payload, TextStyle style);

/// A host-defined inline region the Markdown parser must not look inside.
///
/// [InlinePattern] is the tool for host syntax that is still *text* —
/// `@mention`, `#channel`, `:emoji:`. It runs over the plain-text runs a parse
/// produced, which means the parse has already happened: a payload holding
/// `**`, a backtick, `~~` or `[…](…)` is consumed as Markdown before the
/// pattern ever sees it, and the match silently fails. That is fine for a
/// mention and useless for a JSON payload.
///
/// A directive is the other case: a delimited region whose contents are not
/// Markdown and must survive intact. It is lifted out of the source *before*
/// parsing and put back at render time, so nothing inside it can be
/// interpreted, truncated, or split across nodes.
///
/// ```dart
/// GptMarkdown(
///   reply,
///   inlineDirectives: [
///     InlineDirective(
///       open: '\u{E200}widget\u{E202}',
///       close: '\u{E201}',
///       builder: (context, payload, style) =>
///           WidgetSpan(child: MyWidget.fromJson(payload)),
///     ),
///   ],
/// )
/// ```
///
/// Delimiters should be characters a model does not emit by accident —
/// Private Use Area code points are the usual choice, substituted by the
/// server on the way out so the model itself never types them.
///
/// An unterminated directive stays literal text until its closer arrives,
/// which is what a streaming reply needs: a payload that is still arriving
/// must not render half-built.
class InlineDirective {
  /// Creates a directive.
  const InlineDirective({
    required this.open,
    required this.close,
    required this.builder,
  }) : assert(open.length > 0, 'open must not be empty'),
       assert(close.length > 0, 'close must not be empty');

  /// The opening delimiter.
  final String open;

  /// The closing delimiter.
  final String close;

  /// Builds the span for each complete occurrence.
  final InlineDirectiveBuilder builder;
}

/// Private Use Area sentinels wrapping a masked directive.
///
/// Chosen so the masked form is inert to every stage that follows: the code
/// points are outside ASCII, so the inline parser's trigger table rejects them
/// without a second thought, and the payload rides between them Base64-encoded,
/// whose alphabet holds no Markdown punctuation at all. The masked text can
/// therefore be split into segments, parsed, and carried through the AST as
/// ordinary text with nothing to interpret.
const String _maskOpen = '\u{E010}';
const String _maskClose = '\u{E011}';

/// Replaces every complete [directives] occurrence in [source] with an inert
/// sentinel carrying its payload.
///
/// Returns [source] unchanged when there is nothing to do, so a document
/// without directives — which is every document unless the host configured
/// one — costs one `indexOf` per directive and no allocation.
String maskInlineDirectives(
  String source,
  List<InlineDirective> directives, {
  MarkdownBlockRegistry? blockRegistry,
}) {
  if (blockRegistry != null && directives.isNotEmpty) {
    return _outsideCustomBlocks(
      source,
      blockRegistry,
      (text) => maskInlineDirectives(text, directives),
    );
  }
  if (directives.isEmpty) {
    return source;
  }
  var out = source;
  for (var index = 0; index < directives.length; index++) {
    final directive = directives[index];
    if (!out.contains(directive.open)) {
      continue;
    }
    final buffer = StringBuffer();
    var cursor = 0;
    while (cursor < out.length) {
      final start = out.indexOf(directive.open, cursor);
      if (start == -1) {
        break;
      }
      final from = start + directive.open.length;
      final end = out.indexOf(directive.close, from);
      if (end == -1) {
        // Still arriving. Left as written so it reads as the literal text it
        // currently is, and masked on a later build once the closer lands.
        break;
      }
      buffer
        ..write(out.substring(cursor, start))
        ..write(_maskOpen)
        ..write(index)
        ..write(':')
        ..write(base64Encode(utf8.encode(out.substring(from, end))))
        ..write(_maskClose);
      cursor = end + directive.close.length;
    }
    if (buffer.isNotEmpty) {
      buffer.write(out.substring(cursor));
      out = buffer.toString();
    }
  }
  return out;
}

/// Matches one masked directive, for the regex pipeline's component.
const String inlineDirectiveMaskPattern =
    '$_maskOpen[0-9]+:[A-Za-z0-9+/=]*$_maskClose';

/// Reads a masked directive back into its index and payload.
///
/// Returns null when [masked] is not a directive this document declared, so a
/// stray sentinel in model output renders as the text it is rather than being
/// mistaken for a widget.
({int index, String payload})? decodeInlineDirectiveMask(
  String masked,
  int directiveCount,
) {
  if (!masked.startsWith(_maskOpen) || !masked.endsWith(_maskClose)) {
    return null;
  }
  final body = masked.substring(1, masked.length - 1);
  final colon = body.indexOf(':');
  if (colon == -1) {
    return null;
  }
  final index = int.tryParse(body.substring(0, colon));
  if (index == null || index < 0 || index >= directiveCount) {
    return null;
  }
  try {
    return (
      index: index,
      payload: utf8.decode(base64Decode(body.substring(colon + 1))),
    );
  } on FormatException {
    return null;
  }
}

/// Expands the sentinels in [text] back into directive spans.
///
/// [rest] renders the stretches between them, so ordinary text still goes
/// through whatever the caller does with it — inline patterns, autolinking.
List<InlineSpan> expandInlineDirectives(
  BuildContext context,
  String text,
  List<InlineDirective> directives,
  TextStyle style,
  List<InlineSpan> Function(String text) rest,
) {
  final out = <InlineSpan>[];
  var cursor = 0;
  while (cursor < text.length) {
    final start = text.indexOf(_maskOpen, cursor);
    if (start == -1) {
      break;
    }
    final end = text.indexOf(_maskClose, start + 1);
    if (end == -1) {
      break;
    }
    final body = text.substring(start + 1, end);
    final colon = body.indexOf(':');
    final index = colon == -1 ? -1 : int.tryParse(body.substring(0, colon));
    if (index == null || index < 0 || index >= directives.length) {
      // Not one of ours after all; leave it as written.
      cursor = start + 1;
      continue;
    }
    if (start > cursor) {
      out.addAll(rest(text.substring(cursor, start)));
    }
    out.add(
      _scaleInlineSpanWidgets(
        directives[index].builder(
          context,
          utf8.decode(base64Decode(body.substring(colon + 1))),
          style,
        ),
      ),
    );
    cursor = end + 1;
  }
  if (cursor < text.length) {
    out.addAll(rest(text.substring(cursor)));
  }
  return out;
}

/// Sentinels wrapping a masked [InlinePattern] match.
const String _patternOpen = '\u{E012}';
const String _patternClose = '\u{E013}';

/// Replaces every [patterns] match in [source] with an inert sentinel.
///
/// [InlinePattern] promises that a pattern beats the built-in interpretation of
/// the same text — a pattern for `**bold**` renders a chip, not bold. The regex
/// pipeline gets that for free by dispatching patterns and components through
/// one combined match. A parser cannot: by the time it has an AST, `**bold**`
/// is already emphasis and there is no text left for a pattern to claim.
///
/// So the match is lifted out before parsing, exactly as a directive is, and
/// put back at render time. Matches are taken in one pass, earliest first and
/// earlier patterns winning a tie, so a later pattern can never match inside
/// the Base64 of an earlier one.
///
/// Fenced code and block maths are skipped: their content is not Markdown, and
/// a pattern reaching inside them would rewrite the source a reader asked to
/// see verbatim.
String maskInlinePatterns(
  String source,
  List<InlinePattern> patterns, {
  MarkdownBlockRegistry? blockRegistry,
}) {
  if (patterns.isEmpty) {
    return source;
  }
  final opaque = [
    ..._opaqueRegions(source),
    if (blockRegistry != null) ..._customBlockRegions(source, blockRegistry),
  ];
  final hits = <({int start, int end, int pattern, String text})>[];
  for (var index = 0; index < patterns.length; index++) {
    for (final match in patterns[index].pattern.allMatches(source)) {
      final text = match[0];
      if (text == null || text.isEmpty) {
        continue;
      }
      if (opaque.any((r) => match.start < r.$2 && match.end > r.$1)) {
        continue;
      }
      hits.add((
        start: match.start,
        end: match.end,
        pattern: index,
        text: text,
      ));
    }
  }
  if (hits.isEmpty) {
    return source;
  }
  hits.sort((a, b) {
    final byStart = a.start.compareTo(b.start);
    return byStart != 0 ? byStart : a.pattern.compareTo(b.pattern);
  });

  final buffer = StringBuffer();
  var cursor = 0;
  for (final hit in hits) {
    if (hit.start < cursor) {
      continue; // Overlaps one already taken.
    }
    buffer
      ..write(source.substring(cursor, hit.start))
      ..write(_patternOpen)
      ..write(hit.pattern)
      ..write(':')
      ..write(base64Encode(utf8.encode(hit.text)))
      ..write(_patternClose);
    cursor = hit.end;
  }
  buffer.write(source.substring(cursor));
  return buffer.toString();
}

/// Byte ranges of [source] a pattern must not reach into.
List<(int, int)> _opaqueRegions(String source) {
  final regions = <(int, int)>[];
  var offset = 0;
  int? fenceStart;
  int? mathStart;
  for (final line in source.split('\n')) {
    final trimmed = line.trimLeft();
    if (fenceStart != null) {
      if (trimmed.startsWith('```') || trimmed.startsWith('~~~')) {
        regions.add((fenceStart, offset + line.length));
        fenceStart = null;
      }
    } else if (mathStart != null) {
      if (trimmed.contains(r'\]')) {
        regions.add((mathStart, offset + line.length));
        mathStart = null;
      }
    } else if (trimmed.startsWith('```') || trimmed.startsWith('~~~')) {
      fenceStart = offset;
    } else if (trimmed.startsWith(r'\[') && !trimmed.contains(r'\]')) {
      mathStart = offset;
    }
    offset += line.length + 1;
  }
  // An unterminated region runs to the end.
  final open = fenceStart ?? mathStart;
  if (open != null) {
    regions.add((open, source.length));
  }
  return regions;
}

/// Expands masked pattern matches back into their builders' spans.
///
/// A pattern that does not apply in [scope] renders as the text it matched,
/// which is what it would have been had the pattern never claimed it.
List<InlineSpan> expandInlinePatterns(
  BuildContext context,
  String text,
  List<InlinePattern> patterns,
  GptMarkdownConfig config,
  List<InlineSpan> Function(String text) rest,
) {
  final out = <InlineSpan>[];
  final style = config.style ?? const TextStyle();
  var cursor = 0;
  while (cursor < text.length) {
    final start = text.indexOf(_patternOpen, cursor);
    if (start == -1) {
      break;
    }
    final end = text.indexOf(_patternClose, start + 1);
    if (end == -1) {
      break;
    }
    final body = text.substring(start + 1, end);
    final colon = body.indexOf(':');
    final index = colon == -1 ? null : int.tryParse(body.substring(0, colon));
    if (index == null || index < 0 || index >= patterns.length) {
      cursor = start + 1;
      continue;
    }
    if (start > cursor) {
      out.addAll(rest(text.substring(cursor, start)));
    }
    final matched = utf8.decode(base64Decode(body.substring(colon + 1)));
    final pattern = patterns[index];
    final match = pattern.pattern.firstMatch(matched);
    if (match == null || !pattern.scopes.contains(config.scope)) {
      out.add(TextSpan(text: matched, style: config.style));
    } else {
      out.add(_scaleInlineSpanWidgets(pattern.builder(context, match, style)));
    }
    cursor = end + 1;
  }
  if (cursor < text.length) {
    out.addAll(rest(text.substring(cursor)));
  }
  return out;
}

/// Source ranges owned by extension blocks must stay opaque to inline masks.
/// Quote markers are stripped for recognition only; offsets remain against
/// the original source so the block parser can retain container structure.
List<(int, int)> _customBlockRegions(
  String source,
  MarkdownBlockRegistry registry,
) {
  final lines = source.split('\n');
  final quoted = lines
      .map((line) {
        var text = line.trimLeft();
        while (text.startsWith('>')) {
          text = text.substring(1).trimLeft();
        }
        return text;
      })
      .toList(growable: false);
  final offsets = <int>[0];
  for (final line in lines) {
    offsets.add(offsets.last + line.length + 1);
  }
  final regions = <(int, int)>[];
  var fence = false;
  var math = false;
  for (var i = 0; i < lines.length; i++) {
    final text = quoted[i];
    if (fence) {
      if (text.startsWith('```')) fence = false;
      continue;
    }
    if (math) {
      if (text.contains(r'\]')) math = false;
      continue;
    }
    final match =
        registry.match(lines, i) ??
        (lines[i].trimLeft().startsWith('>')
            ? registry.match(quoted, i)
            : null);
    if (match != null) {
      regions.add((offsets[i], min(source.length, offsets[match.endLine])));
      i = match.endLine - 1;
    } else if (text.startsWith('```')) {
      fence = true;
    } else if (text.startsWith(r'\[') && !text.contains(r'\]')) {
      math = true;
    }
  }
  return regions;
}

String _outsideCustomBlocks(
  String source,
  MarkdownBlockRegistry registry,
  String Function(String) transform,
) {
  final regions = _customBlockRegions(source, registry);
  if (regions.isEmpty) return transform(source);
  final out = StringBuffer();
  var cursor = 0;
  for (final region in regions) {
    out.write(transform(source.substring(cursor, region.$1)));
    out.write(source.substring(region.$1, region.$2));
    cursor = region.$2;
  }
  out.write(transform(source.substring(cursor)));
  return out.toString();
}
