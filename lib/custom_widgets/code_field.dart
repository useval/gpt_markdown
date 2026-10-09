import 'markdown_text_scaling.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:val_highlight/languages/all.dart';
import 'package:val_highlight/themes/dark.dart';
import 'package:val_highlight/themes/light.dart';
import 'package:val_highlight_flutter/val_highlight_flutter.dart'
    show CodeStyles, Highlighter, LanguageRegistry, documentSpans;

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

  /// Every built-in grammar, looked up by the fence's language tag. There is
  /// no fallback: a tag with no grammar renders as plain text.
  static final _languages = LanguageRegistry(allLanguages)
    ..add(pythonLanguage, aliases: const ['python3'])
    ..add(bashLanguage, aliases: const ['shellscript']);

  /// Shares [_languages] so Markdown and HTML resolve embedded languages.
  static final _highlighter = Highlighter(registry: _languages);
  static final _lightStyles = CodeStyles(lightTheme);
  static final _darkStyles = CodeStyles(darkTheme);

  List<InlineSpan> _highlightedCode(Brightness brightness) {
    final requested = widget.highlightCode
        ? widget.name.trim().toLowerCase()
        : '';
    if (_cachedCode == widget.codes &&
        _cachedLanguage == requested &&
        _cachedBrightness == brightness) {
      var cachedSpans = _cachedSpans;
      if (cachedSpans != null) {
        return cachedSpans;
      }
    }

    late final List<InlineSpan> spans;
    final language = requested.isEmpty ? null : _languages.lookup(requested);
    if (language == null) {
      spans = <InlineSpan>[TextSpan(text: widget.codes)];
    } else {
      try {
        final result = _highlighter.highlight(widget.codes, language: language);
        // Plain text keeps a null style, so it inherits `CodeBlockStyle`'s
        // text colour instead of the theme's root colour.
        spans = documentSpans(
          result,
          brightness == Brightness.dark ? _darkStyles : _lightStyles,
        );
      } catch (_) {
        // A grammar failure must never stop the surrounding response from
        // rendering.
        spans = <InlineSpan>[TextSpan(text: widget.codes)];
      }
    }

    _cachedCode = widget.codes;
    _cachedLanguage = requested;
    _cachedBrightness = brightness;
    _cachedSpans = spans;
    return spans;
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
    final label = _copied
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
                  transitionBuilder: (child, animation) =>
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
            border: borderColor == null
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
                                color: Theme.of(
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
                                      color: Theme.of(
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
