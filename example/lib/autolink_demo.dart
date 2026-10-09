import 'package:material_ui/material_ui.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

import 'demo_theme.dart';

/// Standalone demo of autolinking.
///
/// Run it directly with:
/// ```
/// flutter run -t lib/autolink_demo.dart
/// ```
void main() => runApp(const AutolinkApp());

/// Sample text covering every rule the autolinker has to get right.
const autolinkMarkdown = r'''# Autolinks

Bare URLs are linked with no pre-processing:
https://pub.dev/packages/gpt_markdown

## The fiddly cases

- a trailing period stays outside: see https://example.com.
- trailing punctuation stacks: really https://example.com?!
- an unbalanced paren stays outside: (https://example.com)
- balanced parens stay in: https://en.wikipedia.org/wiki/Curry_(programming)
- an entity reference stays outside: https://example.com&amp;
- underscores in a path survive: https://example.com/a_b_c
- a `www.` host is linked over http: www.example.com
- an email becomes a mailto link: ada@example.com

## Emphasis does not leak into the href

**https://example.com** and *https://example.com* both point at the URL alone.
A pre-processor would have produced `[url](url**)` here — that is the bug this
replaces.

## Code is still code

`https://example.com` inside backticks stays text.

## Angle autolinks

<https://example.com> and <ada@example.com> follow CommonMark, and accept any
scheme without an allowlist: <myapp://open?id=7>

## Not linked by default

A bare unknown scheme is left alone: myapp://open?id=7

Turn the allowlist on above and it becomes a link. A bare deep link into
another app — buzz://message?channel=x — stays plain text either way, unless
you add its scheme too.

## What is never touched

- an explicit link: [the docs](https://example.com)
- a URL inside a label: [https://a.com](https://b.com) points at `b.com`
- a URL mid-word: xhttps://example.com
- a host with an underscore in its last two segments: www.foo_bar.com
''';

/// The demo app shell.
class AutolinkApp extends StatelessWidget {
  /// Creates the demo app.
  const AutolinkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return DemoApp(
      title: 'gpt_markdown — autolinks',
      pageBuilder: (toggleTheme) => AutolinkPage(onToggleTheme: toggleTheme),
    );
  }
}

/// Editor, live preview, and the two switches that change what gets linked.
class AutolinkPage extends StatefulWidget {
  /// Creates the demo page.
  const AutolinkPage({super.key, this.onToggleTheme});

  /// Flips the app between light and dark.
  final VoidCallback? onToggleTheme;

  @override
  State<AutolinkPage> createState() => _AutolinkPageState();
}

class _AutolinkPageState extends State<AutolinkPage> {
  late final TextEditingController _controller = TextEditingController(
    text: autolinkMarkdown,
  );
  bool _autolink = true;
  bool _allowMyApp = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _report(String url, String title) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 2),
          content: Text('$title  →  $url'),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isWide = MediaQuery.of(context).size.width > 900;

    final editor = TextField(
      controller: _controller,
      maxLines: null,
      expands: true,
      textAlignVertical: TextAlignVertical.top,
      style: const TextStyle(
        fontFamily: 'monospace',
        fontSize: 13,
        height: 1.5,
      ),
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
        autolink: _autolink,
        autolinkSchemes: _allowMyApp ? const {'myapp'} : const {},
        onLinkTap: _report,
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Autolinks'),
        actions: [DemoThemeButton(onToggle: widget.onToggleTheme)],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Switch(
                  value: _autolink,
                  onChanged: (v) => setState(() => _autolink = v),
                ),
                const Text('autolink'),
                const SizedBox(width: 20),
                Switch(
                  value: _allowMyApp,
                  onChanged:
                      _autolink ? (v) => setState(() => _allowMyApp = v) : null,
                ),
                const Flexible(
                  child: Text(
                    "autolinkSchemes: {'myapp'}",
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: isWide
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _pane(theme, editor)),
                VerticalDivider(
                  width: 1,
                  color: theme.colorScheme.outlineVariant,
                ),
                Expanded(child: preview),
              ],
            )
          : Column(
              children: [
                SizedBox(height: 200, child: _pane(theme, editor)),
                Divider(height: 1, color: theme.colorScheme.outlineVariant),
                Expanded(child: preview),
              ],
            ),
    );
  }

  Widget _pane(ThemeData theme, Widget editor) => ColoredBox(
        color:
            theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        child: editor,
      );
}
