import 'package:material_ui/material_ui.dart';

import '../custom_widgets/inline_code.dart';
import 'alert_style.dart';
import 'style_lerp.dart';
import 'block_quote_style.dart';
import 'heading_style.dart';
import 'link_style.dart';
import 'list_style.dart';
import 'checkbox_style.dart';
import 'code_block_style.dart';
import 'table_style.dart';
import 'image_style.dart';
import 'hr_style.dart';
import 'source_tag_style.dart';
import 'latex_style.dart';

/// Per-component appearance, in one object.
///
/// Pass it to `GptMarkdown(styleSheet: ...)` for a single widget, or to
/// `GptMarkdownThemeData(styleSheet: ...)` for the whole app. Values on the
/// widget win over the theme **per field**, so a widget that overrides one
/// thing keeps the theme's answer for everything else.
///
/// Every field of every style is optional, and anything still unset resolves
/// to the value the package used before it was configurable — so adding a
/// style sheet never changes how existing content looks.
///
/// ```dart
/// GptMarkdown(
///   text,
///   styleSheet: const GptMarkdownStyleSheet(
///     blockQuote: BlockQuoteStyle(barWidth: 4),
///     codeBlock: CodeBlockStyle(showCopyButton: false),
///   ),
/// )
/// ```
///
/// For structure rather than appearance, use the builders — `codeBuilder`,
/// `tableBuilder`, `blockQuoteBuilder` and the rest. The rule across the
/// package is: **style object for looks, builder for structure.**
@immutable
class GptMarkdownStyleSheet {
  /// Creates a style sheet. Every field is optional.
  const GptMarkdownStyleSheet({
    this.blockQuote,
    this.heading,
    this.link,
    this.inlineCode,
    this.list,
    this.checkbox,
    this.codeBlock,
    this.table,
    this.image,
    this.hr,
    this.sourceTag,
    this.latex,
    this.alert,
    this.blockSpacing,
  }) : assert(blockSpacing == null || blockSpacing >= 0);

  /// How blockquotes are drawn.
  final BlockQuoteStyle? blockQuote;

  /// How `#` headings are drawn.
  final HeadingStyle? heading;

  /// How links are drawn.
  final LinkStyle? link;

  /// How inline `code` is drawn.
  final InlineCodeStyle? inlineCode;

  /// How ordered and unordered lists are drawn.
  final ListStyle? list;

  /// How task-list checkboxes and radio buttons are drawn.
  final CheckboxStyle? checkbox;

  /// How fenced code blocks are drawn.
  final CodeBlockStyle? codeBlock;

  /// How tables are drawn.
  final TableStyle? table;

  /// How images are drawn.
  final ImageStyle? image;

  /// How horizontal rules are drawn.
  final HrStyle? hr;

  /// How `[1]` citation chips are drawn.
  final SourceTagStyle? sourceTag;

  /// How rendered maths are drawn.
  final LatexStyle? latex;

  /// How alerts — quotes opening with `[!NOTE]` and the like — are drawn.
  final AlertStyle? alert;

  /// Vertical space between blocks — paragraphs, headings, lists, code, tables
  /// and the rest — in logical pixels at a text scale of 1. It grows with the
  /// text scale, so the gap stays in proportion when a reader enlarges text.
  ///
  /// Defaults to one empty line: 1.15 × the font size, 16 pixels at the
  /// default 14. Extra blank lines in the source never add more; three or ten
  /// in a row give the same single gap. A block's own margin or padding, such
  /// as [BlockQuoteStyle.margin], is added on top.
  final double? blockSpacing;

  /// This sheet, with any unset value taken from [other], field by field.
  GptMarkdownStyleSheet merge(GptMarkdownStyleSheet? other) {
    if (other == null) {
      return this;
    }
    return GptMarkdownStyleSheet(
      blockQuote: blockQuote?.merge(other.blockQuote) ?? other.blockQuote,
      heading: heading?.merge(other.heading) ?? other.heading,
      link: link?.merge(other.link) ?? other.link,
      inlineCode: inlineCode?.merge(other.inlineCode) ?? other.inlineCode,
      list: list?.merge(other.list) ?? other.list,
      checkbox: checkbox?.merge(other.checkbox) ?? other.checkbox,
      codeBlock: codeBlock?.merge(other.codeBlock) ?? other.codeBlock,
      table: table?.merge(other.table) ?? other.table,
      image: image?.merge(other.image) ?? other.image,
      hr: hr?.merge(other.hr) ?? other.hr,
      sourceTag: sourceTag?.merge(other.sourceTag) ?? other.sourceTag,
      latex: latex?.merge(other.latex) ?? other.latex,
      alert: alert?.merge(other.alert) ?? other.alert,
      blockSpacing: blockSpacing ?? other.blockSpacing,
    );
  }

  /// A copy with the given fields replaced.
  GptMarkdownStyleSheet copyWith({
    BlockQuoteStyle? blockQuote,
    HeadingStyle? heading,
    LinkStyle? link,
    InlineCodeStyle? inlineCode,
    ListStyle? list,
    CheckboxStyle? checkbox,
    CodeBlockStyle? codeBlock,
    TableStyle? table,
    ImageStyle? image,
    HrStyle? hr,
    SourceTagStyle? sourceTag,
    LatexStyle? latex,
    AlertStyle? alert,
    double? blockSpacing,
  }) {
    return GptMarkdownStyleSheet(
      blockQuote: blockQuote ?? this.blockQuote,
      heading: heading ?? this.heading,
      link: link ?? this.link,
      inlineCode: inlineCode ?? this.inlineCode,
      list: list ?? this.list,
      checkbox: checkbox ?? this.checkbox,
      codeBlock: codeBlock ?? this.codeBlock,
      table: table ?? this.table,
      image: image ?? this.image,
      hr: hr ?? this.hr,
      sourceTag: sourceTag ?? this.sourceTag,
      latex: latex ?? this.latex,
      alert: alert ?? this.alert,
      blockSpacing: blockSpacing ?? this.blockSpacing,
    );
  }

  /// Linearly interpolates between two style sheets.
  static GptMarkdownStyleSheet? lerp(
    GptMarkdownStyleSheet? a,
    GptMarkdownStyleSheet? b,
    double t,
  ) {
    if (a == null && b == null) {
      return null;
    }
    return GptMarkdownStyleSheet(
      blockQuote: BlockQuoteStyle.lerp(a?.blockQuote, b?.blockQuote, t),
      heading: HeadingStyle.lerp(a?.heading, b?.heading, t),
      link: LinkStyle.lerp(a?.link, b?.link, t),
      inlineCode: InlineCodeStyle.lerp(a?.inlineCode, b?.inlineCode, t),
      list: ListStyle.lerp(a?.list, b?.list, t),
      checkbox: CheckboxStyle.lerp(a?.checkbox, b?.checkbox, t),
      codeBlock: CodeBlockStyle.lerp(a?.codeBlock, b?.codeBlock, t),
      table: TableStyle.lerp(a?.table, b?.table, t),
      image: ImageStyle.lerp(a?.image, b?.image, t),
      hr: HrStyle.lerp(a?.hr, b?.hr, t),
      sourceTag: SourceTagStyle.lerp(a?.sourceTag, b?.sourceTag, t),
      latex: LatexStyle.lerp(a?.latex, b?.latex, t),
      alert: AlertStyle.lerp(a?.alert, b?.alert, t),
      blockSpacing: lerpDouble(a?.blockSpacing, b?.blockSpacing, t),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is GptMarkdownStyleSheet &&
        other.blockQuote == blockQuote &&
        other.heading == heading &&
        other.link == link &&
        other.inlineCode == inlineCode &&
        other.list == list &&
        other.checkbox == checkbox &&
        other.codeBlock == codeBlock &&
        other.table == table &&
        other.image == image &&
        other.hr == hr &&
        other.sourceTag == sourceTag &&
        other.latex == latex &&
        other.alert == alert &&
        other.blockSpacing == blockSpacing;
  }

  @override
  int get hashCode => Object.hash(
    blockQuote,
    heading,
    link,
    inlineCode,
    list,
    checkbox,
    codeBlock,
    table,
    image,
    hr,
    sourceTag,
    latex,
    alert,
    blockSpacing,
  );
}
