part of 'gpt_markdown.dart';

/// Builds one custom block. Blocks are atomic during character reveal; use
/// blockAnimation for an entrance. The renderer receives the parsed payload,
/// so theme changes do not need to run the syntax parser again.
typedef MarkdownBlockBuilder =
    Widget Function(
      BuildContext context,
      MdCustomBlock node,
      GptMarkdownConfig config,
    );

/// Registers a syntax and its renderer on the modern cached pipeline.
///
/// Keep component instances stable (for example, in a State field). Replacing
/// the list's entries invalidates parsing and rendering. Legacy `components`
/// or `inlineComponents` take precedence when supplied; blockComponents are
/// ignored on that legacy path. Existing InlinePattern and InlineDirective
/// APIs remain available for inline extensions on both pipelines.
class MarkdownBlockComponent {
  const MarkdownBlockComponent({required this.syntax, required this.builder});
  final MarkdownBlockSyntax syntax;
  final MarkdownBlockBuilder builder;
}
