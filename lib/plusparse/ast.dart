/// The Markdown document AST produced by the plusparse parser.
///
/// This is a pure-Dart rewrite of the original Rust plusparse AST. The
/// renderer (or any consumer) walks this tree, so it covers every construct
/// gpt_markdown supports. Block-level and inline-level variants share one
/// sealed hierarchy so the tree can nest freely (e.g. bold inside a heading
/// inside a list item).
library;

/// Root of a parsed document.
class MdDocument {
  const MdDocument({required this.children});

  final List<MdNode> children;
}

/// Column alignment for tables (from the `:---:` separator row).
enum MdAlign { none, left, center, right }

/// One cell of a table row; holds inline content.
class MdTableCell {
  const MdTableCell({required this.content});

  final List<MdNode> content;
}

/// One row of a table.
class MdTableRow {
  const MdTableRow({required this.cells});

  final List<MdTableCell> cells;
}

/// One item of an ordered/unordered list. [children] holds the item's inline
/// content followed by any nested block nodes (e.g. a nested list).
class MdListItem {
  const MdListItem({required this.children, this.number});

  final List<MdNode> children;

  /// The literal marker number for ordered-list items (`5.` → 5), preserved
  /// so non-sequential numbering renders as written. Null for bullets.
  final int? number;
}

/// A node in the Markdown tree.
sealed class MdNode {
  const MdNode();
}

// ---------- Block-level ----------

class MdHeading extends MdNode {
  const MdHeading({required this.level, required this.children});

  /// 1–6.
  final int level;
  final List<MdNode> children;
}

class MdParagraph extends MdNode {
  const MdParagraph({required this.children});

  final List<MdNode> children;
}

class MdBlockQuote extends MdNode {
  const MdBlockQuote({required this.children});

  final List<MdNode> children;
}

class MdCodeBlock extends MdNode {
  const MdCodeBlock({
    required this.language,
    required this.code,
    required this.closed,
  });

  final String language;
  final String code;

  /// `false` while a fenced block is still open (useful for streaming).
  final bool closed;
}

class MdUnorderedList extends MdNode {
  const MdUnorderedList({required this.items});

  final List<MdListItem> items;
}

class MdOrderedList extends MdNode {
  const MdOrderedList({required this.start, required this.items});

  /// The first ordered number (e.g. 3 for a list starting `3.`).
  final int start;
  final List<MdListItem> items;
}

class MdCheckbox extends MdNode {
  const MdCheckbox({required this.checked, required this.children});

  final bool checked;
  final List<MdNode> children;
}

class MdRadio extends MdNode {
  const MdRadio({required this.selected, required this.children});

  final bool selected;
  final List<MdNode> children;
}

class MdTable extends MdNode {
  const MdTable({
    required this.aligns,
    required this.header,
    required this.rows,
  });

  final List<MdAlign> aligns;
  final MdTableRow header;
  final List<MdTableRow> rows;
}

class MdBlockLatex extends MdNode {
  const MdBlockLatex({required this.tex});

  final String tex;
}

class MdHorizontalRule extends MdNode {
  const MdHorizontalRule();
}

// ---------- Inline-level ----------

class MdText extends MdNode {
  const MdText({required this.text});

  final String text;
}

class MdBold extends MdNode {
  const MdBold({required this.children});

  final List<MdNode> children;
}

class MdItalic extends MdNode {
  const MdItalic({required this.children});

  final List<MdNode> children;
}

class MdStrike extends MdNode {
  const MdStrike({required this.children});

  final List<MdNode> children;
}

class MdUnderline extends MdNode {
  const MdUnderline({required this.children});

  final List<MdNode> children;
}

/// Backtick span (`code`), rendered as highlighted inline code.
class MdInlineCode extends MdNode {
  const MdInlineCode({required this.text});

  final String text;
}

class MdInlineLatex extends MdNode {
  const MdInlineLatex({required this.tex});

  final String tex;
}

class MdLink extends MdNode {
  const MdLink({required this.children, required this.url});

  final List<MdNode> children;
  final String url;
}

class MdImage extends MdNode {
  const MdImage({
    required this.url,
    required this.alt,
    this.width,
    this.height,
  });

  final String url;
  final String alt;

  /// Width parsed from an alt of the form `WxH` (e.g. `![100x200](url)`).
  final double? width;
  final double? height;
}

/// A citation marker such as `[1]`.
class MdSourceTag extends MdNode {
  const MdSourceTag({required this.id});

  final String id;
}

class MdLineBreak extends MdNode {
  const MdLineBreak();
}

/// An extension's parsed payload. [body] remains raw unless the extension
/// explicitly parses it; [data] should be immutable and independent of Flutter.
class MdCustomBlock extends MdNode {
  const MdCustomBlock({
    required this.type,
    required this.body,
    this.data,
    this.closed = true,
  });
  final String type;
  final String body;
  final Object? data;
  final bool closed;
}
