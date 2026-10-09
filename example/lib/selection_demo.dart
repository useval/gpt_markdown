import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

import 'demo_theme.dart';

/// Standalone demo of text selection and copy.
///
/// Drag across the rendered Markdown on the left. The panel on the right shows
/// exactly what Flutter would put on the clipboard, so gaps and out-of-order
/// fragments are visible rather than something you only notice after pasting.
///
/// Run it directly with:
/// ```
/// flutter run -t lib/selection_demo.dart
/// ```
void main() => runApp(const SelectionApp());

/// Content chosen to exercise each thing that sits between two runs of text.
const selectionMarkdown = r'''# Selection

Drag across any of these and watch the panel. The cases below the divider are
the ones that come out wrong today.

## Plain text

This whole paragraph is ordinary text with nothing embedded in it, so selecting
across it should copy exactly what you see.

## Text with a link in the middle

Check the [setup docs](https://example.com/setup) for the next step.

## Text with inline code

Run `flutter pub get` and then `flutter run` to start.

## Text with inline math

The identity \( e^{i\pi} + 1 = 0 \) closes the paragraph.

## Several links in a row

See [one](https://example.com/1), [two](https://example.com/2) and
[three](https://example.com/3) for the details.

## A link inside bold text

**Read the [changelog](https://example.com/changelog) first.**

## A bare URL

Autolinked: https://example.com/bare — still a link, still in the sentence.

---

## A list — items run together

- first item
- second item
- third item

Copies as `firstitemseconditemthirditem`, with no line breaks between items.

## Checkboxes — same

- [x] done
- [ ] todo

## A table — no cell or row separators

| Name | Link |
|---|---|
| Docs | [open](https://example.com/docs) |
| Repo | [open](https://example.com/repo) |

Copies as one run of characters with nothing between the cells.

## A code block — picks up the chrome

```dart
var x = 1;
```

The language label and the Copy button caption end up in the copied text.

## An image — contributes nothing

Before ![alt text](https://example.com/i.png) after.

The alt text is not copied; there is just a gap where the image was.
''';

/// The demo app shell.
class SelectionApp extends StatelessWidget {
  /// Creates the demo app.
  const SelectionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return DemoApp(
      title: 'gpt_markdown — selection',
      pageBuilder: (toggleTheme) => SelectionPage(onToggleTheme: toggleTheme),
    );
  }
}

/// Rendered Markdown on one side, the live selection on the other.
class SelectionPage extends StatefulWidget {
  /// Creates the demo page.
  const SelectionPage({super.key, this.onToggleTheme});

  /// Flips the app between light and dark.
  final VoidCallback? onToggleTheme;

  @override
  State<SelectionPage> createState() => _SelectionPageState();
}

class _SelectionPageState extends State<SelectionPage> {
  String? _selected;
  bool _selectionEnabled = true;
  bool _showMarkers = true;

  /// Makes whitespace visible, so a missing space or a stray line break in the
  /// copied text is something you can see rather than infer.
  String _annotate(String text) {
    if (!_showMarkers) {
      return text;
    }
    return text.replaceAll('\n', '⏎\n').replaceAll(' ', '·');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isWide = MediaQuery.of(context).size.width > 900;

    Widget markdown = SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: GptMarkdown(
        selectionMarkdown,
        onLinkTap: (url, title) {
          ScaffoldMessenger.of(context)
            ..clearSnackBars()
            ..showSnackBar(
              SnackBar(
                duration: const Duration(seconds: 1),
                content: Text('Tapped $url'),
              ),
            );
        },
      ),
    );

    if (_selectionEnabled) {
      markdown = SelectionArea(
        onSelectionChanged: (content) =>
            setState(() => _selected = content?.plainText),
        child: markdown,
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Selection'),
        actions: [DemoThemeButton(onToggle: widget.onToggleTheme)],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Switch(
                  value: _selectionEnabled,
                  onChanged: (v) => setState(() {
                    _selectionEnabled = v;
                    _selected = null;
                  }),
                ),
                const Text('SelectionArea'),
                const SizedBox(width: 20),
                Switch(
                  value: _showMarkers,
                  onChanged: (v) => setState(() => _showMarkers = v),
                ),
                const Flexible(
                  child: Text(
                    'show · and ⏎',
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
                Expanded(child: markdown),
                VerticalDivider(
                  width: 1,
                  color: theme.colorScheme.outlineVariant,
                ),
                SizedBox(width: 360, child: _panel(theme)),
              ],
            )
          : Column(
              children: [
                Expanded(child: markdown),
                Divider(height: 1, color: theme.colorScheme.outlineVariant),
                SizedBox(height: 220, child: _panel(theme)),
              ],
            ),
    );
  }

  Widget _panel(ThemeData theme) {
    final selected = _selected;
    return ColoredBox(
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    selected == null || selected.isEmpty
                        ? 'What would be copied'
                        : 'What would be copied — '
                            '${selected.length} characters',
                    style: theme.textTheme.labelLarge,
                  ),
                ),
                IconButton(
                  tooltip: 'Copy to clipboard',
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  onPressed: selected == null || selected.isEmpty
                      ? null
                      : () => Clipboard.setData(
                            ClipboardData(text: selected),
                          ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: selected == null || selected.isEmpty
                  ? Text(
                      _selectionEnabled
                          ? 'Drag across the Markdown to select some of it.'
                          : 'Selection is off. Turn the switch on above.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    )
                  : SelectableText(
                      _annotate(selected),
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        height: 1.5,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
