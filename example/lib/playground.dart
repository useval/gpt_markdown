import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:val_latex_flutter/val_latex_flutter.dart' show Math, MathSpan;

import 'autolink_demo.dart';
import 'inline_code_demo.dart';
import 'inline_patterns_demo.dart';
import 'selection_demo.dart';
// import 'package:gpt_markdown/custom_widgets/selectable_adapter.dart';

void main() {
  runApp(const PlaygroundApp());
}

const _samples = {
  'Selection': selectionMarkdown,
  'Autolinks': autolinkMarkdown,
  'Inline Code': inlineCodeMarkdown,
  'Inline Patterns': demoMarkdown,
  'Overview': r'''## Welcome to gpt_markdown Playground

Type any Markdown or LaTeX in the editor and see it rendered instantly.

**Bold**, *italic*, ~~strikethrough~~, `inline code`, and <u>underline</u> all work.

---

### LaTeX Math

Inline: \( E = mc^2 \) and \( x = \frac{-b \pm \sqrt{b^2 - 4ac}}{2a} \)

Block:
\[
\int_{-\infty}^{\infty} e^{-x^2}\,dx = \sqrt{\pi}
\]

### Table

| Feature | Supported |
|---|:---:|
| Markdown | ✅ |
| LaTeX | ✅ |
| Tables | ✅ |
| Code blocks | ✅ |
| Selectable | ✅ |

### Code Block

```dart
GptMarkdown(
  '**Hello** from _gpt_markdown_!',
  style: TextStyle(fontSize: 16),
)
```

### Task List
- [x] Install gpt_markdown
- [x] Render Markdown
- [ ] Ship your AI app
''',
  'LaTeX': r'''## LaTeX Examples

### Inline Math
The quadratic formula: \( x = \frac{-b \pm \sqrt{b^2-4ac}}{2a} \)

Euler's identity: \( e^{i\pi} + 1 = 0 \)

### Block Math

\[
\sum_{n=1}^{\infty} \frac{1}{n^2} = \frac{\pi^2}{6}
\]

\[
\begin{bmatrix}
1 & 2 & 3 \\
4 & 5 & 6 \\
7 & 8 & 9
\end{bmatrix}
\]

\[
\nabla \cdot \mathbf{E} = \frac{\rho}{\varepsilon_0}
\]

### Maxwell's Equations
\[ \nabla \times \mathbf{B} = \mu_0 \mathbf{J} + \mu_0\varepsilon_0 \frac{\partial \mathbf{E}}{\partial t} \]
''',
  'AI Chat': r'''## ChatGPT-style Response

Here is how to **reverse a linked list** in Python:

```python
class ListNode:
    def __init__(self, val=0, next=None):
        self.val = val
        self.next = next

def reverse_list(head: ListNode) -> ListNode:
    prev = None
    curr = head
    while curr:
        next_node = curr.next
        curr.next = prev
        prev = curr
        curr = next_node
    return prev
```

**Time complexity**: \( O(n) \)
**Space complexity**: \( O(1) \)

### Steps

1. Initialize `prev = None` and `curr = head`
2. On each iteration, save `curr.next` before overwriting it
3. Point `curr.next` backwards to `prev`
4. Advance both pointers forward
5. Return `prev` — the new head

> **Tip**: This is one of the most common interview questions. Practice until it's automatic.
''',
  'Tables': r'''## Table Examples

### Basic Table

| Name | Language | Stars |
|---|---|---|
| Flutter | Dart | ⭐ 170k |
| React | JS | ⭐ 225k |
| SwiftUI | Swift | ⭐ 7k |

### Aligned Columns

| Left | Center | Right |
|:---|:---:|---:|
| Apple | 🍎 | $1.20 |
| Banana | 🍌 | $0.50 |
| Cherry | 🍒 | $3.00 |

### Mixed Content

| Syntax | Example | Result |
|---|---|---|
| Bold | `**text**` | **text** |
| Italic | `*text*` | *text* |
| Code | `` `code` `` | `code` |
| Strike | `~~text~~` | ~~text~~ |
''',
};

class PlaygroundApp extends StatefulWidget {
  const PlaygroundApp({super.key});

  @override
  State<PlaygroundApp> createState() => _PlaygroundAppState();
}

class _PlaygroundAppState extends State<PlaygroundApp> {
  ThemeMode _themeMode = ThemeMode.dark;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'gpt_markdown Playground',
      themeMode: _themeMode,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorSchemeSeed: const Color(0xFF6366F1),
        extensions: [
          GptMarkdownThemeData(brightness: Brightness.light),
        ],
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: const Color(0xFF6366F1),
        extensions: [
          GptMarkdownThemeData(brightness: Brightness.dark),
        ],
      ),
      home: PlaygroundPage(
        onToggleTheme: () => setState(() {
          _themeMode =
              _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
        }),
        themeMode: _themeMode,
      ),
    );
  }
}

class PlaygroundPage extends StatefulWidget {
  const PlaygroundPage({
    super.key,
    required this.onToggleTheme,
    required this.themeMode,
  });
  final VoidCallback onToggleTheme;
  final ThemeMode themeMode;

  @override
  State<PlaygroundPage> createState() => _PlaygroundPageState();
}

class _PlaygroundPageState extends State<PlaygroundPage> {
  late final TextEditingController _controller;
  String _activeSample = 'Overview';
  bool _selectable = false;
  bool _useDollarLatex = false;
  bool _inlinePatterns = true;
  bool _autolink = true;
  TextDirection _direction = TextDirection.ltr;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _samples['Overview']!);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _loadSample(String name) {
    setState(() {
      _activeSample = name;
      _controller.text = _samples[name]!;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isWide = MediaQuery.of(context).size.width > 800;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: Column(
        children: [
          _buildTopBar(theme, isDark),
          _buildSampleBar(theme),
          Expanded(
            child: isWide ? _buildWideLayout(theme) : _buildNarrowLayout(theme),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(ThemeData theme, bool isDark) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outlineVariant,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Center(
              child: Text(
                'M',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'gpt_markdown',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
          Text(
            ' playground',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w400,
            ),
          ),
          const Spacer(),
          _ToolbarButton(
            tooltip: _useDollarLatex ? 'Dollar LaTeX: ON' : 'Dollar LaTeX: OFF',
            icon: Icons.functions,
            active: _useDollarLatex,
            onTap: () => setState(() => _useDollarLatex = !_useDollarLatex),
            theme: theme,
          ),
          const SizedBox(width: 4),
          _ToolbarButton(
            tooltip: _autolink ? 'Autolink: ON' : 'Autolink: OFF',
            icon: Icons.link_rounded,
            active: _autolink,
            onTap: () => setState(() => _autolink = !_autolink),
            theme: theme,
          ),
          const SizedBox(width: 4),
          _ToolbarButton(
            tooltip: _inlinePatterns
                ? 'Inline patterns: ON'
                : 'Inline patterns: OFF',
            icon: Icons.alternate_email_rounded,
            active: _inlinePatterns,
            onTap: () => setState(() => _inlinePatterns = !_inlinePatterns),
            theme: theme,
          ),
          const SizedBox(width: 4),
          _ToolbarButton(
            tooltip: _selectable ? 'Selectable: ON' : 'Selectable: OFF',
            icon: Icons.select_all_rounded,
            active: _selectable,
            onTap: () => setState(() => _selectable = !_selectable),
            theme: theme,
          ),
          const SizedBox(width: 4),
          _ToolbarButton(
            tooltip: _direction == TextDirection.ltr
                ? 'Switch to RTL'
                : 'Switch to LTR',
            label: _direction == TextDirection.ltr ? 'LTR' : 'RTL',
            active: _direction == TextDirection.rtl,
            onTap: () => setState(() {
              _direction = _direction == TextDirection.ltr
                  ? TextDirection.rtl
                  : TextDirection.ltr;
            }),
            theme: theme,
          ),
          const SizedBox(width: 4),
          _ToolbarButton(
            tooltip: 'Toggle theme',
            icon: isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
            onTap: widget.onToggleTheme,
            theme: theme,
          ),
          const SizedBox(width: 12),
          _PubBadge(theme: theme),
        ],
      ),
    );
  }

  Widget _buildSampleBar(ThemeData theme) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: Row(
        children: [
          Text(
            'Examples:',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 10),
          ..._samples.keys.map((name) => Padding(
                padding: const EdgeInsets.only(right: 6),
                child: _SampleChip(
                  label: name,
                  active: _activeSample == name,
                  onTap: () => _loadSample(name),
                  theme: theme,
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildWideLayout(ThemeData theme) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: _buildEditor(theme)),
        VerticalDivider(
          width: 1,
          color: theme.colorScheme.outlineVariant,
        ),
        Expanded(child: _buildPreview(theme)),
      ],
    );
  }

  Widget _buildNarrowLayout(ThemeData theme) {
    return Column(
      children: [
        SizedBox(height: 280, child: _buildEditor(theme)),
        Divider(height: 1, color: theme.colorScheme.outlineVariant),
        Expanded(child: _buildPreview(theme)),
      ],
    );
  }

  Widget _buildEditor(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    return Column(
      children: [
        _PaneHeader(label: 'Editor', icon: Icons.edit_rounded, theme: theme),
        Expanded(
          child: Container(
            color: isDark ? const Color(0xFF0D1117) : const Color(0xFFF8F9FA),
            child: TextField(
              controller: _controller,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 13.5,
                height: 1.6,
                color:
                    isDark ? const Color(0xFFE6EDF3) : const Color(0xFF1C2128),
              ),
              cursorColor: const Color(0xFF6366F1),
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.all(20),
                border: InputBorder.none,
                hintText: 'Type Markdown here…',
                hintStyle: TextStyle(
                  color:
                      theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                  fontFamily: 'monospace',
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPreview(ThemeData theme) {
    return Column(
      children: [
        _PaneHeader(
          label: 'Preview',
          icon: Icons.preview_rounded,
          theme: theme,
          trailing: _CopyButton(text: _controller.text, theme: theme),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              ListenableBuilder(
                listenable: _controller,
                builder: (context, _) {
                  Widget md = GptMarkdown(
                    _controller.text,
                    textDirection: _direction,
                    useDollarSignsForLatex: _useDollarLatex,
                    autolink: _autolink,
                    inlinePatterns:
                        _inlinePatterns ? demoInlinePatterns(context) : null,
                    // Inline maths as a span, so the formula sits on the
                    // baseline and joins text selection.
                    inlineLatexBuilder: (latex) =>
                        MathSpan(latex.tex, style: latex.style),
                    // A display formula wraps to the width, and scrolls what
                    // cannot break.
                    blockLatexBuilder: (latex) => Container(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Math.tex(
                        latex.tex,
                        displayMode: true,
                        textStyle: latex.style,
                        onError: (context, result) => Text(
                          latex.tex,
                          style: TextStyle(
                            color: theme.colorScheme.error,
                            fontFamily: 'monospace',
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                    // Styling only — no builder needed, and the chip keeps
                    // wrapping, selection and baseline alignment.
                    inlineCodeStyle: InlineCodeStyle(
                      color: const Color(0xFF6366F1),
                      backgroundColor:
                          const Color(0xFF6366F1).withValues(alpha: 0.12),
                      borderColor:
                          const Color(0xFF6366F1).withValues(alpha: 0.35),
                    ),
                    onLinkTap: (url, title) {},
                  );

                  if (_selectable) {
                    md = SelectionArea(child: md);
                  }
                  return md;
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PaneHeader extends StatelessWidget {
  const _PaneHeader({
    required this.label,
    required this.icon,
    required this.theme,
    this.trailing,
  });
  final String label;
  final IconData icon;
  final ThemeData theme;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        border: Border(
          bottom: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const Spacer(),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  const _ToolbarButton({
    required this.theme,
    required this.onTap,
    this.icon,
    this.label,
    this.tooltip = '',
    this.active = false,
  });
  final ThemeData theme;
  final VoidCallback onTap;
  final IconData? icon;
  final String? label;
  final String tooltip;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: active
                ? const Color(0xFF6366F1).withValues(alpha: 0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Center(
            child: icon != null
                ? Icon(
                    icon,
                    size: 18,
                    color: active
                        ? const Color(0xFF6366F1)
                        : theme.colorScheme.onSurfaceVariant,
                  )
                : Text(
                    label ?? '',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: active
                          ? const Color(0xFF6366F1)
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _SampleChip extends StatelessWidget {
  const _SampleChip({
    required this.label,
    required this.active,
    required this.onTap,
    required this.theme,
  });
  final String label;
  final bool active;
  final VoidCallback onTap;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: active
              ? const Color(0xFF6366F1)
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: active ? Colors.white : theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _CopyButton extends StatefulWidget {
  const _CopyButton({required this.text, required this.theme});
  final String text;
  final ThemeData theme;

  @override
  State<_CopyButton> createState() => _CopyButtonState();
}

class _CopyButtonState extends State<_CopyButton> {
  bool _copied = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        await Clipboard.setData(ClipboardData(text: widget.text));
        setState(() => _copied = true);
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) setState(() => _copied = false);
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _copied ? Icons.check_rounded : Icons.copy_rounded,
            size: 13,
            color: _copied
                ? Colors.green
                : widget.theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 4),
          Text(
            _copied ? 'Copied' : 'Copy',
            style: TextStyle(
              fontSize: 11,
              color: _copied
                  ? Colors.green
                  : widget.theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _PubBadge extends StatelessWidget {
  const _PubBadge({required this.theme});
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF6366F1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Text(
        'pub.dev ↗',
        style: TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
