part of '../gpt_markdown.dart';

/// Viewport-lazy Markdown for long documents, placed in CustomScrollView.slivers.
///
/// Unlike GptMarkdown's compact column, this creates spans and widgets only
/// for segments requested by the viewport (including its cache extent).
/// Segmentation is eager; custom syntax matchers also run to find boundaries.
/// Built-in AST parsing and widget rendering are lazy. A very large individual
/// table, list, or fence is still one segment, not virtualized internally.
///
/// This API displays source updates immediately; character reveal is provided
/// by the compact GptMarkdown widget. Wrap the scroll view in SelectionArea
/// for text selection. Selection only includes mounted content.
///
/// Legacy component lists preserve whole-document semantics by using one
/// SliverToBoxAdapter; they intentionally do not opt into lazy segmentation.
class SliverGptMarkdown extends StatefulWidget {
  const SliverGptMarkdown(
    this.data, {
    super.key,
    this.config = const GptMarkdownConfig(),
    this.useDollarSignsForLatex = false,
  });
  final String data;
  final GptMarkdownConfig config;
  final bool useDollarSignsForLatex;

  @override
  State<SliverGptMarkdown> createState() => _SliverGptMarkdownState();
}

class _SliverGptMarkdownState extends State<SliverGptMarkdown> {
  final _segments = MarkdownSegmentCache();
  String _source = '';
  List<String> _sources = const [];

  @override
  void initState() {
    super.initState();
    _updateSource();
  }

  @override
  void didUpdateWidget(covariant SliverGptMarkdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data != widget.data ||
        oldWidget.useDollarSignsForLatex != widget.useDollarSignsForLatex ||
        !identical(oldWidget.config, widget.config)) {
      _updateSource();
    }
  }

  void _updateSource() {
    final config = widget.config;
    _source =
        _normalizeMarkdownSource(
          widget.data,
          widget.useDollarSignsForLatex,
          config.inlineDirectives,
          blockRegistry:
              config.components == null && config.inlineComponents == null
                  ? config.blockRegistry
                  : null,
        ).text;
    // Legacy inline patterns match original source, not the modern parser's
    // masked tokens. Do not mask or invoke modern syntaxes on this route.
    if (config.components != null || config.inlineComponents != null) return;
    final patterns = config.inlinePatterns;
    if (patterns != null && patterns.isNotEmpty) {
      _source = maskInlinePatterns(
        _source,
        patterns,
        blockRegistry: config.blockRegistry,
      );
    }
    _sources = _segments.update(_source, blockRegistry: config.blockRegistry);
  }

  @override
  Widget build(BuildContext context) {
    final config = widget.config;
    final Widget sliver;
    if (config.components != null || config.inlineComponents != null) {
      sliver = SliverToBoxAdapter(
        child: MdWidget(context, _source, true, isRoot: true, config: config),
      );
    } else {
      final gap = blockGap(context, config);
      sliver = SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) => Padding(
            padding: EdgeInsets.only(top: index == 0 ? 0 : gap),
            child: _IncrementalMdView(text: _sources[index], config: config),
          ),
          childCount: _sources.length,
        ),
      );
    }
    final directed = Directionality(
      textDirection: config.textDirection,
      child: sliver,
    );
    final scaler = config.textScaler;
    return scaler == null
        ? directed
        : MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: scaler),
          child: directed,
        );
  }
}
