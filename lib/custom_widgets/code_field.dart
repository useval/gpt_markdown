import 'markdown_text_scaling.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:highlight/highlight.dart' show Node, highlight;

import '../styles/code_block_style.dart';

/// A widget that displays code with syntax highlighting and a copy button.
///
/// The [CodeField] widget takes a [name] parameter which is displayed as a label
/// above the code block, and a [codes] parameter containing the actual code text
/// to display.
///
/// Features:
/// - Displays code in a Material container with rounded corners
/// - Shows the code language/name as a label
/// - Provides a copy button to copy code to clipboard
/// - Visual feedback when code is copied
/// - Themed colors that adapt to light/dark mode
class CodeField extends StatefulWidget {
  const CodeField({
    super.key,
    required this.name,
    required this.codes,
    this.style = const CodeBlockStyle(),
    this.onCopy,
    this.highlightCode = true,
    this.scalesItsOwnText = false,
  });

  /// Whether this block scales from MediaQuery rather than an enclosing
  /// paragraph. Leave false when embedded in a WidgetSpan.
  final bool scalesItsOwnText;

  /// Whether to apply syntax highlighting to the current code.
  final bool highlightCode;

  /// The language written after the opening fence.
  final String name;

  /// The code itself.
  final String codes;

  /// Resolved appearance. Every field is already filled in.
  final CodeBlockStyle style;

  /// Called with the code after it is copied to the clipboard.
  final void Function(String code)? onCopy;

  @override
  State<CodeField> createState() => _CodeFieldState();
}

class _CodeFieldState extends State<CodeField> {
  bool _copied = false;
  bool _copying = false;

  /// Whether the copy control has been promoted to a full
  /// [IconButton]. Flipped by the first hover or tap; never back.
  /// Diameter of the copy button, and the size of the glyph inside it. Shared
  /// by both the cheap and the interactive form so hovering cannot resize it.
  static const double _copyButtonSize = 32;
  static const double _copyIconSize = 17;
  String? _cachedCode;
  String? _cachedLanguage;
  Brightness? _cachedBrightness;
  List<InlineSpan>? _cachedSpans;

  static const _languageAliases = <String, String>{
    'c#': 'cs',
    'c++': 'cpp',
    'csharp': 'cs',
    'docker': 'dockerfile',
    'golang': 'go',
    'h': 'cpp',
    'hpp': 'cpp',
    'html': 'xml',
    'js': 'javascript',
    'jsx': 'javascript',
    'kt': 'kotlin',
    'md': 'markdown',
    'objective-c': 'objectivec',
    'objc': 'objectivec',
    'py': 'python',
    'py3': 'python',
    'python3': 'python',
    'rb': 'ruby',
    'rs': 'rust',
    'sh': 'bash',
    'shell': 'bash',
    'shellscript': 'bash',
    'ts': 'typescript',
    'tsx': 'typescript',
    'yml': 'yaml',
  };

  static const _lightSyntaxColors = <String, Color>{
    'comment': Color(0xFF6A737D),
    'quote': Color(0xFF6A737D),
    'keyword': Color(0xFFD73A49),
    'selector-tag': Color(0xFF22863A),
    'literal': Color(0xFF005CC5),
    'number': Color(0xFF005CC5),
    'string': Color(0xFF032F62),
    'doctag': Color(0xFF032F62),
    'title': Color(0xFF6F42C1),
    'section': Color(0xFF005CC5),
    'type': Color(0xFF6F42C1),
    'name': Color(0xFF22863A),
    'attribute': Color(0xFF6F42C1),
    'attr': Color(0xFF005CC5),
    'variable': Color(0xFFE36209),
    'template-variable': Color(0xFFE36209),
    'regexp': Color(0xFF032F62),
    'link': Color(0xFF032F62),
    'symbol': Color(0xFF005CC5),
    'bullet': Color(0xFF735C0F),
    'built_in': Color(0xFF005CC5),
    'builtin-name': Color(0xFF005CC5),
    'meta': Color(0xFF6A737D),
    'deletion': Color(0xFFB31D28),
    'addition': Color(0xFF22863A),
    'character': Color(0xFF032F62),
    'class': Color(0xFF6F42C1),
    'code': Color(0xFF005CC5),
    'constructor': Color(0xFF6F42C1),
    'emphasis': Color(0xFF24292E),
    'formula': Color(0xFF005CC5),
    'function': Color(0xFF6F42C1),
    'identifier': Color(0xFF24292E),
    'meta-keyword': Color(0xFFD73A49),
    'meta-string': Color(0xFF032F62),
    'module': Color(0xFF6F42C1),
    'module-access': Color(0xFF005CC5),
    'module-def': Color(0xFF6F42C1),
    'operator': Color(0xFFD73A49),
    'params': Color(0xFFE36209),
    'pattern-match': Color(0xFF22863A),
    'rest_arg': Color(0xFFE36209),
    'selector-attr': Color(0xFF005CC5),
    'selector-class': Color(0xFF6F42C1),
    'selector-id': Color(0xFF005CC5),
    'selector-pseudo': Color(0xFFE36209),
    'strong': Color(0xFF24292E),
    'subst': Color(0xFFD73A49),
    'tag': Color(0xFF22863A),
    'template-tag': Color(0xFFD73A49),
    'typing': Color(0xFF6F42C1),
  };

  static const _darkSyntaxColors = <String, Color>{
    'comment': Color(0xFF8B949E),
    'quote': Color(0xFF8B949E),
    'keyword': Color(0xFFFF7B72),
    'selector-tag': Color(0xFF7EE787),
    'literal': Color(0xFF79C0FF),
    'number': Color(0xFF79C0FF),
    'string': Color(0xFFA5D6FF),
    'doctag': Color(0xFFA5D6FF),
    'title': Color(0xFFD2A8FF),
    'section': Color(0xFF79C0FF),
    'type': Color(0xFFD2A8FF),
    'name': Color(0xFF7EE787),
    'attribute': Color(0xFFD2A8FF),
    'attr': Color(0xFF79C0FF),
    'variable': Color(0xFFFFA657),
    'template-variable': Color(0xFFFFA657),
    'regexp': Color(0xFFA5D6FF),
    'link': Color(0xFFA5D6FF),
    'symbol': Color(0xFF79C0FF),
    'bullet': Color(0xFFF2CC60),
    'built_in': Color(0xFF79C0FF),
    'builtin-name': Color(0xFF79C0FF),
    'meta': Color(0xFF8B949E),
    'deletion': Color(0xFFFF7B72),
    'addition': Color(0xFF7EE787),
    'character': Color(0xFFA5D6FF),
    'class': Color(0xFFD2A8FF),
    'code': Color(0xFF79C0FF),
    'constructor': Color(0xFFD2A8FF),
    'emphasis': Color(0xFFC9D1D9),
    'formula': Color(0xFF79C0FF),
    'function': Color(0xFFD2A8FF),
    'identifier': Color(0xFFC9D1D9),
    'meta-keyword': Color(0xFFFF7B72),
    'meta-string': Color(0xFFA5D6FF),
    'module': Color(0xFFD2A8FF),
    'module-access': Color(0xFF79C0FF),
    'module-def': Color(0xFFD2A8FF),
    'operator': Color(0xFFFF7B72),
    'params': Color(0xFFFFA657),
    'pattern-match': Color(0xFF7EE787),
    'rest_arg': Color(0xFFFFA657),
    'selector-attr': Color(0xFF79C0FF),
    'selector-class': Color(0xFFD2A8FF),
    'selector-id': Color(0xFF79C0FF),
    'selector-pseudo': Color(0xFFFFA657),
    'strong': Color(0xFFC9D1D9),
    'subst': Color(0xFFFF7B72),
    'tag': Color(0xFF7EE787),
    'template-tag': Color(0xFFFF7B72),
    'typing': Color(0xFFD2A8FF),
  };

  List<InlineSpan> _highlightedCode(Brightness brightness) {
    final requested =
        widget.highlightCode ? widget.name.trim().toLowerCase() : '';
    if (_cachedCode == widget.codes &&
        _cachedLanguage == requested &&
        _cachedBrightness == brightness) {
      return _cachedSpans!;
    }

    late final List<InlineSpan> spans;
    if (requested.isEmpty) {
      spans = <InlineSpan>[TextSpan(text: widget.codes)];
    } else {
      final language = _languageAliases[requested] ?? requested;
      try {
        final result = highlight.parse(widget.codes, language: language);
        final colors =
            brightness == Brightness.dark
                ? _darkSyntaxColors
                : _lightSyntaxColors;
        spans = _spansForNodes(result.nodes ?? const <Node>[], colors);
      } catch (_) {
        // Markdown language tags are free-form. An unknown tag must never stop
        // the surrounding response from rendering.
        spans = <InlineSpan>[TextSpan(text: widget.codes)];
      }
    }

    _cachedCode = widget.codes;
    _cachedLanguage = requested;
    _cachedBrightness = brightness;
    _cachedSpans = spans;
    return spans;
  }

  List<InlineSpan> _spansForNodes(List<Node> nodes, Map<String, Color> colors) {
    return nodes
        .map((node) {
          final children = node.children;
          final color = node.className == null ? null : colors[node.className!];
          final isStrong = node.className == 'strong';
          final isEmphasis = node.className == 'emphasis';
          return TextSpan(
            text: node.value,
            style:
                color == null && !isStrong && !isEmphasis
                    ? null
                    : TextStyle(
                      color: color,
                      fontWeight: isStrong ? FontWeight.bold : null,
                      fontStyle: isEmphasis ? FontStyle.italic : null,
                    ),
            children:
                children == null ? null : _spansForNodes(children, colors),
          );
        })
        .toList(growable: false);
  }

  /// The copy control.
  ///
  /// One form, always the real one. It used to be drawn as a plain icon until
  /// a pointer arrived and only then swapped for an interactive button, to
  /// save the ~340 us that the interactive form costs per code block. That
  /// saving was real — a document of 20 fenced blocks mounted about 7 ms
  /// faster — and it was not worth what it cost:
  ///
  ///  * a keyboard user could never reach it. The cheap form had no `Focus`,
  ///    so it was not in the tab order, and neither way of promoting it — a
  ///    pointer entering, or a tap — can be triggered by a key. The control
  ///    was unreachable for the life of the widget.
  ///  * the first stylus contact was swallowed. A pen is tracked as a mouse,
  ///    so touching down promoted the button, which unmounted the recogniser
  ///    mid-gesture and rejected it: the first tap copied nothing.
  ///  * press and hold meant opposite things before and after promotion —
  ///    copy, then tooltip-and-no-copy.
  ///  * the first touch had no ripple and no press highlight, because the ink
  ///    surface did not exist yet, which reads as a tap that did not register.
  ///
  /// Keep this as one form. If the build cost ever needs attacking again, the
  /// thing to reach for is fewer code blocks built at once, not a control that
  /// only half exists.
  Widget _copyButton(BuildContext context) {
    final label =
        _copied
            ? (widget.style.copiedLabel ?? 'Copied!')
            : (widget.style.copyLabel ?? 'Copy code');
    final icon = _copied ? Icons.check_rounded : Icons.content_copy_rounded;
    final scheme = Theme.of(context).colorScheme;

    // Both states are drawn by this, and that is the point. They used to be a
    // bare `Container` and an `IconButton`, which agreed on paper — both asked
    // for 32 by 32 — and disagreed on screen: `IconButton` folds
    // `visualDensity` into the constraints and reserves its own tap target, so
    // it resolved to a 24-pixel circle inside a 40-pixel box. Hovering swapped
    // one for the other, and the button visibly shrank and jumped.
    Widget circle(Widget child) => Container(
      width: _copyButtonSize,
      height: _copyButtonSize,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        shape: BoxShape.circle,
      ),
      child: child,
    );

    // Deliberately always enabled. Disabling it — with `IgnorePointer` or
    // `AbsorbPointer` — does not stop the tap reaching an ancestor, because an
    // ancestor is already on the hit-test path; it only stops the button
    // claiming the gesture, so the tap fell through to whatever wraps the code
    // block (a tap-to-collapse, in a chat UI). The duplicate-clipboard guard
    // lives in `_copyCode`.
    // `InkWell` contributes neither an accessible name nor a button role, and
    // a `Tooltip` supplies only a tooltip string — so without this the control
    // reaches a screen reader as an unlabelled tappable node.
    return Semantics(
      label: label,
      button: true,
      child: Tooltip(
        message: label,
        child: circle(
          Material(
            type: MaterialType.transparency,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              hoverColor: scheme.onSurface.withValues(alpha: 0.08),
              highlightColor: scheme.onSurface.withValues(alpha: 0.12),
              onTap: _copyCode,
              child: Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 160),
                  transitionBuilder:
                      (child, animation) =>
                          ScaleTransition(scale: animation, child: child),
                  child: Icon(
                    icon,
                    key: ValueKey(_copied),
                    size: _copyIconSize,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _copyCode() async {
    if (_copying || _copied) return;
    setState(() => _copying = true);

    try {
      await Clipboard.setData(ClipboardData(text: widget.codes));
      widget.onCopy?.call(widget.codes);
    } catch (_) {
      if (mounted) setState(() => _copying = false);
      return;
    }

    if (!mounted) return;
    setState(() {
      _copying = false;
      _copied = true;
    });
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    setState(() => _copied = false);
  }

  @override
  Widget build(BuildContext context) {
    final borderColor = widget.style.borderColor;
    final showLabel = widget.style.showLanguageLabel ?? true;
    final showCopy = widget.style.showCopyButton ?? true;
    final displayName = widget.name.trim().isEmpty ? 'Code' : widget.name;
    final family = widget.style.fontFamily;
    final codeStyle = TextStyle(
      // A caller-supplied family is not looked up inside this package.
      fontFamily: family ?? 'JetBrainsMono',
      package: family == null ? 'gpt_markdown' : widget.style.fontFamilyPackage,
      fontSize: widget.style.fontSize,
      color: widget.style.textColor,
    );
    // Nested blocks are scaled by their enclosing paragraph. Standalone
    // blocks must instead let the body and header inherit MediaQuery scaling.
    final panelRadius = BorderRadius.all(
      widget.style.borderRadius ?? const Radius.circular(12),
    );
    final body = DefaultTextStyle.merge(
      // `DecoratedBox`, not `Material`. The pixels are the same — a rounded
      // rect, a border, a fill — but `Material` also installs an ink surface
      // and a shape painter, which measured ~78 us per block for a panel that
      // never ripples.
      //
      // `Material` was quietly supplying one more thing: an
      // `AnimatedDefaultTextStyle` from `textTheme.bodyMedium`. `CodeBlockStyle`
      // deliberately leaves `fontSize` and `textColor` null and documents them
      // as defaulting to the surrounding size and colour — and that surrounding
      // *was* this `Material`. So the default is resolved explicitly here
      // instead; dropping it silently resized and recoloured every code block.
      style: Theme.of(context).textTheme.bodyMedium,
      child: ClipRRect(
        borderRadius: panelRadius,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color:
                widget.style.backgroundColor ??
                Theme.of(context).colorScheme.surfaceContainer,
            borderRadius: panelRadius,
            border:
                borderColor == null
                    ? null
                    : Border.all(
                      color: borderColor,
                      width: widget.style.borderWidth ?? 1,
                    ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (showLabel || showCopy)
                Padding(
                  padding:
                      widget.style.headerPadding ??
                      const EdgeInsets.fromLTRB(10, 8, 8, 2),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      if (showLabel)
                        Flexible(
                          child: Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color:
                                    Theme.of(
                                      context,
                                    ).colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(7),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 9,
                                  vertical: 5,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.terminal_rounded,
                                      size: 13,
                                      color:
                                          Theme.of(
                                            context,
                                          ).colorScheme.onSurfaceVariant,
                                    ),
                                    const SizedBox(width: 5),
                                    Flexible(
                                      child: Text(
                                        displayName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: widget.style.languageStyle,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      if (showLabel && showCopy) const SizedBox(width: 8),
                      if (!showLabel) const Spacer(),
                      if (showCopy) _copyButton(context),
                    ],
                  ),
                ),
              // Markdown blocks follow RTL, but source code and its
              // horizontal scroll origin keep their LTR reading order.
              Directionality(
                textDirection: TextDirection.ltr,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding:
                      widget.style.padding ??
                      const EdgeInsets.fromLTRB(16, 10, 16, 16),
                  child: Text.rich(
                    TextSpan(
                      style: codeStyle,
                      children: _highlightedCode(Theme.of(context).brightness),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return MarkdownTextScaling.wrap(body, enabled: widget.scalesItsOwnText);
  }
}
