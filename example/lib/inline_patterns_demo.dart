import 'package:flutter/gestures.dart';
import 'package:material_ui/material_ui.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

import 'demo_theme.dart';

/// Standalone demo of [GptMarkdown.inlinePatterns].
///
/// Run it directly with:
/// ```
/// flutter run -t lib/inline_patterns_demo.dart
/// ```
void main() => runApp(const InlinePatternsApp());

/// Channels this demo knows about. Anything else keeps its `#` as plain text —
/// which is the point: `#2959` below stays an issue number, not a channel.
const demoChannels = ['general', 'random', 'design', 'design-review'];

/// People this demo knows about.
const demoPeople = ['ada', 'grace', 'linus'];

/// Emoji shortcodes this demo knows about.
const demoEmoji = {
  'tada': '🎉',
  'rocket': '🚀',
  'fire': '🔥',
  'eyes': '👀',
};

/// The three syntaxes chat apps layer on top of Markdown, plus one built on a
/// [TextSpan] instead of a [WidgetSpan].
///
/// [onTap] receives a short description of whatever was tapped.
List<InlinePattern> demoInlinePatterns(
  BuildContext context, {
  void Function(String label)? onTap,
}) {
  final colors = Theme.of(context).colorScheme;

  return [
    // ---- #channel -------------------------------------------------------
    // No `genericTokenPattern`, so only known channel names are claimed.
    InlinePattern.prefixed(
      prefix: '#',
      knownNames: demoChannels,
      builder: (context, match, style) {
        final name = match.group(0)!.substring(1);
        return WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: _Chip(
            icon: Icons.tag_rounded,
            label: name,
            style: style,
            background: colors.primaryContainer,
            foreground: colors.onPrimaryContainer,
            onTap: () => onTap?.call('channel #$name'),
          ),
        );
      },
    ),

    // ---- @mention -------------------------------------------------------
    InlinePattern.prefixed(
      prefix: '@',
      knownNames: demoPeople,
      builder: (context, match, style) {
        final name = match.group(0)!.substring(1);
        return WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: _Chip(
            icon: Icons.alternate_email_rounded,
            label: name,
            style: style,
            background: colors.tertiaryContainer,
            foreground: colors.onTertiaryContainer,
            onTap: () => onTap?.call('mention @$name'),
          ),
        );
      },
    ),

    // ---- :emoji: --------------------------------------------------------
    // `prefixed` cannot express this — it has no closing delimiter — so
    // shortcodes use `delimited`, which consumes both colons.
    InlinePattern.delimited(
      open: ':',
      knownNames: demoEmoji.keys,
      builder: (context, match, style) {
        final name = match.namedGroup('name');
        final glyph = name == null ? null : demoEmoji[name];
        if (glyph == null) {
          // Unknown shortcode: render what the author typed.
          return TextSpan(text: match.group(0), style: style);
        }
        // A glyph is a character, so no placeholder is needed — this stays
        // selectable and wraps with the paragraph.
        return TextSpan(
          text: glyph,
          style: style.copyWith(fontSize: (style.fontSize ?? 14) * 1.15),
          mouseCursor: SystemMouseCursors.click,
          recognizer: TapGestureRecognizer()
            ..onTap = () => onTap?.call('emoji :$name:'),
        );
      },
    ),

    // ---- GH-123, built as a TextSpan ------------------------------------
    // No placeholder: this stays selectable, wraps across lines, and sits on
    // the surrounding baseline. Prefer this shape whenever the design allows.
    InlinePattern(
      pattern: RegExp(r'(?<![\w-])GH-(\d+)\b'),
      builder: (context, match, style) => TextSpan(
        text: match.group(0),
        style: style.copyWith(
          color: colors.primary,
          fontWeight: FontWeight.w600,
        ),
        recognizer: TapGestureRecognizer()
          ..onTap = () => onTap?.call('issue ${match.group(0)}'),
      ),
    ),
  ];
}

/// Sample text exercising every pattern above.
const demoMarkdown = r'''# Inline patterns

Chat apps layer their own tokens on top of Markdown. gpt_markdown does not
define what they mean — you supply the regex and the builder.

Hey @ada, the mock is ready :tada: — see #design-review for the thread.

## What is *not* claimed

Only the names the app knows about become chips. Everything else stays text:

- `#general` is a known channel, so it renders as a chip → #general
- `#2959` is not, so it stays an issue number → #2959
- `@nobody` is not a known person → @nobody
- an email keeps its `@` → ada@example.com

## Inside link labels

Patterns do not fire inside a link label by default, so this stays readable
instead of rendering blank: [#design](https://example.com/design).

## TextSpan patterns

`GH-123` is built as a `TextSpan` rather than a `WidgetSpan`, so it stays
selectable and wraps with the paragraph: fixed in GH-6124, follow-up GH-5257.

## Still ordinary Markdown

| Channel | Owner | Status |
|---|---|:---:|
| #general | @grace | 🔥 |
| #random | @linus | 👀 |

> Patterns work in headings, lists, tables and quotes — see #random :rocket:
''';

/// The demo app shell.
class InlinePatternsApp extends StatelessWidget {
  /// Creates the demo app.
  const InlinePatternsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return DemoApp(
      title: 'gpt_markdown — inline patterns',
      pageBuilder: (toggleTheme) =>
          InlinePatternsPage(onToggleTheme: toggleTheme),
    );
  }
}

/// An editor and a live preview, with the patterns toggleable so the
/// difference is visible.
class InlinePatternsPage extends StatefulWidget {
  /// Creates the demo page.
  const InlinePatternsPage({super.key, this.onToggleTheme});

  /// Flips the app between light and dark.
  final VoidCallback? onToggleTheme;

  @override
  State<InlinePatternsPage> createState() => _InlinePatternsPageState();
}

class _InlinePatternsPageState extends State<InlinePatternsPage> {
  late final TextEditingController _controller = TextEditingController(
    text: demoMarkdown,
  );
  bool _patternsOn = true;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _report(String label) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
            content: Text('Tapped $label'),
            duration: const Duration(seconds: 1)),
      );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isWide = MediaQuery.of(context).size.width > 800;

    final editor = TextField(
      controller: _controller,
      maxLines: null,
      expands: true,
      textAlignVertical: TextAlignVertical.top,
      style:
          const TextStyle(fontFamily: 'monospace', fontSize: 13, height: 1.5),
      decoration: const InputDecoration(
        contentPadding: EdgeInsets.all(16),
        border: InputBorder.none,
        hintText: 'Type Markdown here…',
      ),
      onChanged: (_) => setState(() {}),
    );

    final preview = SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: GptMarkdown(
        _controller.text,
        inlinePatterns:
            _patternsOn ? demoInlinePatterns(context, onTap: _report) : null,
        onLinkTap: (url, title) => _report('link $url'),
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inline patterns'),
        actions: [
          DemoThemeButton(onToggle: widget.onToggleTheme),
          Row(
            children: [
              Text(_patternsOn ? 'Patterns on' : 'Patterns off'),
              Switch(
                value: _patternsOn,
                onChanged: (v) => setState(() => _patternsOn = v),
              ),
              const SizedBox(width: 8),
            ],
          ),
        ],
      ),
      body: isWide
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: ColoredBox(
                    color: theme.colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.35),
                    child: editor,
                  ),
                ),
                VerticalDivider(
                  width: 1,
                  color: theme.colorScheme.outlineVariant,
                ),
                Expanded(child: preview),
              ],
            )
          : Column(
              children: [
                SizedBox(
                  height: 220,
                  child: ColoredBox(
                    color: theme.colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.35),
                    child: editor,
                  ),
                ),
                Divider(height: 1, color: theme.colorScheme.outlineVariant),
                Expanded(child: preview),
              ],
            ),
    );
  }
}

/// A rounded token chip, sized to sit on the surrounding text baseline.
class _Chip extends StatelessWidget {
  const _Chip({
    required this.icon,
    required this.label,
    required this.style,
    required this.background,
    required this.foreground,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final TextStyle style;
  final Color background;
  final Color foreground;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final fontSize = style.fontSize ?? 14;
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: fontSize * 0.95, color: foreground),
          const SizedBox(width: 2),
          Text(
            label,
            style: style.copyWith(
              color: foreground,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return chip;
    return GestureDetector(onTap: onTap, child: chip);
  }
}
