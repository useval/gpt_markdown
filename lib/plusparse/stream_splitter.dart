/// Splits Markdown source into independently-parsable top-level segments,
/// used by gpt_markdown's incremental rendering mode.
///
/// Segments are separated by blank lines, except inside fenced code blocks
/// (```) and block LaTeX (`\[ ... \]`), which stay whole. Each segment can be
/// parsed and rendered on its own; during streaming only the last segment's
/// text changes, so all earlier segments' widgets can be cached and reused —
/// that caps per-chunk rebuild/layout cost at the tail instead of the whole
/// message.
///
/// Divergence from a full-document parse: a list whose items are separated by
/// blank lines becomes multiple adjacent list segments instead of one list.
/// Rendering is visually equivalent (every item is its own row widget either
/// way).
library;

import 'block_syntax.dart';

List<String> splitStreamSegments(
  String src, {
  MarkdownBlockRegistry? blockRegistry,
}) {
  final normalized =
      src.contains('\r')
          ? src.replaceAll('\r\n', '\n').replaceAll('\r', '\n')
          : src;
  final lines = normalized.split('\n');
  final segments = <String>[];
  final current = <String>[];
  var inFence = false;
  var inLatex = false;

  void closeSegment() {
    if (current.isNotEmpty) {
      segments.add(current.join('\n'));
      current.clear();
    }
  }

  for (var index = 0; index < lines.length; index++) {
    final line = lines[index];
    final trimmed = line.trimLeft();

    if (inFence) {
      current.add(line);
      if (trimmed.startsWith('```')) {
        inFence = false;
      }
      continue;
    }
    if (inLatex) {
      current.add(line);
      if (line.contains('\\]')) {
        inLatex = false;
      }
      continue;
    }

    final custom = blockRegistry?.match(lines, index);
    if (custom != null) {
      current.addAll(lines.sublist(index, custom.endLine));
      index = custom.endLine - 1;
      continue;
    }

    if (line.trim().isEmpty) {
      closeSegment();
      continue;
    }

    current.add(line);
    if (trimmed.startsWith('```')) {
      inFence = true;
      continue;
    }
    if (trimmed.startsWith('\\[')) {
      // Mirrors the block parser: strip leading `\[` markers, then the block
      // stays open unless the closer appears on the same line.
      var rest = trimmed;
      while (rest.startsWith('\\[')) {
        rest = rest.substring(2);
      }
      if (!rest.contains('\\]')) {
        inLatex = true;
      }
    }
  }
  closeSegment();
  return segments;
}

/// Retains settled segment strings between appends. Only the previous tail
/// and appended source are split again. Edits or CR normalization fall back to
/// a full split. Callers still compare source prefixes; this is not O(1).
class MarkdownSegmentCache {
  String _source = '';
  List<String> _segments = const [];
  MarkdownBlockRegistry? _registry;

  List<String> update(String source, {MarkdownBlockRegistry? blockRegistry}) {
    if (source == _source && identical(_registry, blockRegistry)) {
      return _segments;
    }
    var from = 0;
    var prefix = const <String>[];
    if (identical(_registry, blockRegistry) &&
        _segments.isNotEmpty &&
        !source.contains('\r') &&
        source.startsWith(_source)) {
      from = _source.lastIndexOf(_segments.last);
      if (from >= 0) {
        prefix = _segments.sublist(0, _segments.length - 1);
      } else {
        from = 0;
      }
    }
    _segments = List.unmodifiable([
      ...prefix,
      ...splitStreamSegments(
        source.substring(from),
        blockRegistry: blockRegistry,
      ),
    ]);
    _source = source;
    _registry = blockRegistry;
    return _segments;
  }
}
