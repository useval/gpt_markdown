/// Pure-Dart extension points for block syntax. No Flutter dependency.
library;

import 'ast.dart';

/// A successful match consumes [endLine] exclusively. Parsers must be pure,
/// deterministic, and accept incomplete input. A match may inspect only its
/// consumed lines; otherwise independently cached blocks would be unsafe.
class MarkdownBlockMatch {
  const MarkdownBlockMatch({required this.node, required this.endLine});
  final MdCustomBlock node;
  final int endLine;
}

/// A locally parsable custom block. Register a matching renderer with
/// `MarkdownBlockComponent` on `GptMarkdown.blockComponents`.
///
/// Rules run before built-in blocks, in registration order, but only on lines
/// starting with [prefix] after left trimming. Code fences are opaque. A rule
/// returning null leaves the input to the next rule or built-in Markdown.
abstract class MarkdownBlockSyntax {
  const MarkdownBlockSyntax();
  String get type;
  String get prefix;
  MarkdownBlockMatch? parse(List<String> lines, int startLine);
}

/// A convenient opaque container such as `:::warning` ... `:::`. Its body is
/// raw text, including blank lines. An unfinished block consumes the remaining
/// input with [MdCustomBlock.closed] false. It does not nest the same fence.
class FencedBlockSyntax extends MarkdownBlockSyntax {
  const FencedBlockSyntax({
    required this.type,
    required this.opening,
    this.closing = ':::',
  });
  @override
  final String type;
  final String opening;
  final String closing;
  @override
  String get prefix => opening;

  @override
  MarkdownBlockMatch? parse(List<String> lines, int startLine) {
    if (lines[startLine].trim() != opening) return null;
    var end = startLine + 1;
    while (end < lines.length && lines[end].trim() != closing) {
      end++;
    }
    final closed = end < lines.length;
    return MarkdownBlockMatch(
      node: MdCustomBlock(
        type: type,
        body: lines.sublist(startLine + 1, end).join('\n'),
        closed: closed,
      ),
      endLine: closed ? end + 1 : end,
    );
  }
}

/// Compiled first-character dispatch shared by segmentation and parsing.
/// Invalid consumption is rejected rather than looping or dropping input.
class MarkdownBlockRegistry {
  MarkdownBlockRegistry(Iterable<MarkdownBlockSyntax> syntaxes) {
    final types = <String>{};
    for (final syntax in syntaxes) {
      if (syntax.prefix.isEmpty || syntax.type.isEmpty) {
        throw ArgumentError('Block syntax type and prefix must not be empty.');
      }
      if (!types.add(syntax.type)) {
        throw ArgumentError('Duplicate block syntax type: ${syntax.type}');
      }
      (_dispatch[syntax.prefix.codeUnitAt(0)] ??= []).add(syntax);
    }
  }
  final Map<int, List<MarkdownBlockSyntax>> _dispatch = {};

  MarkdownBlockMatch? match(List<String> lines, int startLine) {
    final line = lines[startLine].trimLeft();
    if (line.isEmpty) return null;
    final candidates = _dispatch[line.codeUnitAt(0)];
    if (candidates == null) return null;
    for (final syntax in candidates) {
      if (!line.startsWith(syntax.prefix)) continue;
      final result = syntax.parse(lines, startLine);
      if (result == null) continue;
      if (result.endLine <= startLine ||
          result.endLine > lines.length ||
          result.node.type != syntax.type) {
        throw StateError('Invalid block match from ${syntax.type}.');
      }
      return result;
    }
    return null;
  }
}
