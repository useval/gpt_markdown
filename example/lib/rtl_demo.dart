import 'package:flutter/material.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

import 'demo_theme.dart';
import 'rtl_sample.dart';

/// Run directly: flutter run -d macos -t lib/rtl_demo.dart
void main() => runApp(DemoApp(
      title: 'RTL block alignment',
      pageBuilder: (toggleTheme) => RtlPage(onToggleTheme: toggleTheme),
    ));

class RtlPage extends StatefulWidget {
  const RtlPage({super.key, this.onToggleTheme});
  final VoidCallback? onToggleTheme;

  @override
  State<RtlPage> createState() => _RtlPageState();
}

class _RtlPageState extends State<RtlPage> {
  String _renderer = 'Plusparse';
  TextDirection _direction = TextDirection.rtl;
  double _scale = 1;

  @override
  Widget build(BuildContext context) {
    const source = rtlShowcaseMarkdown;
    final style = Theme.of(context).textTheme.bodyLarge;
    final scaler = TextScaler.linear(_scale);
    final config = GptMarkdownConfig(
      textDirection: _direction,
      style: style,
      textScaler: scaler,
      inlinePatterns: rtlInlinePatterns,
      inlineDirectives: rtlInlineDirectives,
      imageBuilder: rtlImageBuilder,
    );
    // Keep the host page LTR deliberately: the Markdown's explicit direction
    // must control block placement independently of the surrounding app.
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(title: const Text('RTL block alignment'), actions: [
          if (widget.onToggleTheme != null)
            IconButton(
                onPressed: widget.onToggleTheme,
                tooltip: 'Toggle theme',
                icon: const Icon(Icons.brightness_6)),
        ]),
        body: Column(children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 16,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                DropdownButton<String>(
                  key: const ValueKey('rtl-renderer'),
                  value: _renderer,
                  items: ['Plusparse', 'Legacy regex', 'Lazy sliver']
                      .map((value) =>
                          DropdownMenuItem(value: value, child: Text(value)))
                      .toList(),
                  onChanged: (value) => setState(() => _renderer = value!),
                ),
                TextButton.icon(
                  key: const ValueKey('rtl-direction'),
                  icon: Icon(_direction == TextDirection.rtl
                      ? Icons.format_textdirection_r_to_l
                      : Icons.format_textdirection_l_to_r),
                  label: Text(_direction == TextDirection.rtl ? 'RTL' : 'LTR'),
                  onPressed: () => setState(() => _direction =
                      _direction == TextDirection.rtl
                          ? TextDirection.ltr
                          : TextDirection.rtl),
                ),
                DropdownButton<double>(
                  value: _scale,
                  items: [1.0, 1.5, 2.0]
                      .map((value) => DropdownMenuItem(
                          value: value, child: Text('Text ${value}x')))
                      .toList(),
                  onChanged: (value) => setState(() => _scale = value!),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Text(
                'One sample: blocks, nested lists and quotes, inline elements and custom badges. '
                'Code keeps its left-to-right reading order.'),
          ),
          const SizedBox(height: 12),
          Expanded(
              child: Center(
                  child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Container(
              key: const ValueKey('rtl-preview'),
              decoration: BoxDecoration(
                  border:
                      Border.all(color: Theme.of(context).colorScheme.outline)),
              child: SelectionArea(
                child: _renderer == 'Lazy sliver'
                    ? CustomScrollView(
                        key: const ValueKey('rtl-sliver'),
                        slivers: [
                          SliverPadding(
                              padding: const EdgeInsets.all(16),
                              sliver: SliverGptMarkdown(source, config: config))
                        ],
                      )
                    : SingleChildScrollView(
                        key: ValueKey(_renderer),
                        padding: const EdgeInsets.all(16),
                        child: SizedBox(
                            width: double.infinity,
                            child: GptMarkdown(
                              source,
                              textDirection: _direction,
                              // ignore: deprecated_member_use
                              incremental: _renderer == 'Plusparse',
                              style: style,
                              textScaler: scaler,
                              inlinePatterns: rtlInlinePatterns,
                              inlineDirectives: rtlInlineDirectives,
                              imageBuilder: rtlImageBuilder,
                            )),
                      ),
              ),
            ),
          ))),
        ]),
      ),
    );
  }
}

// Shared by all three renderers so switching only changes the pipeline.
final rtlInlinePatterns = <InlinePattern>[
  InlinePattern(
    pattern: RegExp(r'@librarian'),
    builder: (context, match, style) => TextSpan(
      text: match.group(0),
      style: style.copyWith(color: Theme.of(context).colorScheme.primary),
    ),
  ),
  InlinePattern(
    pattern: RegExp(r':ready:'),
    builder: (context, match, style) => WidgetSpan(
      alignment: PlaceholderAlignment.middle,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.secondaryContainer,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          child: Text('جاهز', style: style),
        ),
      ),
    ),
  ),
];

final rtlInlineDirectives = <InlineDirective>[
  InlineDirective(
    open: '{{',
    close: '}}',
    builder: (context, payload, style) => TextSpan(
      text: payload,
      style: style.copyWith(fontWeight: FontWeight.bold),
    ),
  ),
];

// A local illustration keeps image placement testable offline on every device.
Widget rtlImageBuilder(
        BuildContext context, String url, double? width, double? height) =>
    Semantics(
      label: 'رسم مكتبة',
      image: true,
      child: Container(
        width: width ?? 160,
        height: height ?? 90,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.tertiaryContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const FittedBox(
          child: Padding(
              padding: EdgeInsets.all(8), child: Icon(Icons.local_library)),
        ),
      ),
    );
