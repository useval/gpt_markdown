import 'package:flutter/material.dart';
import 'style_lerp.dart';

/// How a fenced code block is drawn.
///
/// Every field is optional. An unset field falls back to the theme, then to
/// the value the package used before this style existed — so setting one
/// field changes one thing and nothing else moves.
///
/// A style on the widget wins over the theme **per field**, not per object.
@immutable
class CodeBlockStyle {
  /// Creates a CodeBlockStyle. Null fields defer to the theme, then to the default.
  const CodeBlockStyle({
    this.backgroundColor,
    this.borderColor,
    this.borderWidth,
    this.borderRadius,
    this.padding,
    this.headerPadding,
    this.fontFamily,
    this.fontFamilyPackage,
    this.fontSize,
    this.textColor,
    this.showLanguageLabel,
    this.languageStyle,
    this.showCopyButton,
    this.copyLabel,
    this.copiedLabel,
    this.highlightWhileStreaming,
  });

  /// Whether to highlight an unfinished fence on every source update.
  /// Defaults to true for compatibility. False renders plain code until the
  /// closing fence arrives, avoiding repeated highlighting of large blocks.
  final bool? highlightWhileStreaming;

  /// Panel fill. Defaults to `ColorScheme.surfaceContainer`.
  final Color? backgroundColor;

  /// Panel outline. Defaults to `ColorScheme.outlineVariant`.
  final Color? borderColor;

  /// Outline thickness. Defaults to 1 when a colour is set.
  final double? borderWidth;

  /// Corner rounding. Defaults to 12.
  final Radius? borderRadius;

  /// Space around the code. Defaults to 16, with a tighter top inset.
  final EdgeInsetsGeometry? padding;

  /// Space around the header row.
  final EdgeInsetsGeometry? headerPadding;

  /// Code font. Defaults to the bundled JetBrains Mono.
  final String? fontFamily;

  /// Package the font ships in.
  final String? fontFamilyPackage;

  /// Code size. Defaults to the surrounding size.
  final double? fontSize;

  /// Code colour. Defaults to the surrounding colour.
  final Color? textColor;

  /// Whether the language is shown. Defaults to true.
  final bool? showLanguageLabel;

  /// Style of that label.
  final TextStyle? languageStyle;

  /// Whether the copy button is shown. Defaults to true.
  final bool? showCopyButton;

  /// Accessible copy-button tooltip. Defaults to `Copy code`.
  final String? copyLabel;

  /// Accessible copy-button tooltip after copying. Defaults to `Copied!`.
  final String? copiedLabel;

  /// This style, with any unset field taken from [other], field by field.
  CodeBlockStyle merge(CodeBlockStyle? other) {
    if (other == null) {
      return this;
    }
    return CodeBlockStyle(
      backgroundColor: backgroundColor ?? other.backgroundColor,
      borderColor: borderColor ?? other.borderColor,
      borderWidth: borderWidth ?? other.borderWidth,
      borderRadius: borderRadius ?? other.borderRadius,
      padding: padding ?? other.padding,
      headerPadding: headerPadding ?? other.headerPadding,
      fontFamily: fontFamily ?? other.fontFamily,
      fontFamilyPackage: fontFamilyPackage ?? other.fontFamilyPackage,
      fontSize: fontSize ?? other.fontSize,
      textColor: textColor ?? other.textColor,
      showLanguageLabel: showLanguageLabel ?? other.showLanguageLabel,
      languageStyle: languageStyle ?? other.languageStyle,
      showCopyButton: showCopyButton ?? other.showCopyButton,
      copyLabel: copyLabel ?? other.copyLabel,
      copiedLabel: copiedLabel ?? other.copiedLabel,
      highlightWhileStreaming:
          highlightWhileStreaming ?? other.highlightWhileStreaming,
    );
  }

  /// This style with every remaining default filled in.
  CodeBlockStyle resolve(ColorScheme scheme) {
    return CodeBlockStyle(
      backgroundColor: backgroundColor ?? scheme.surfaceContainer,
      borderColor: borderColor ?? scheme.outlineVariant.withValues(alpha: 0.65),
      borderWidth: borderWidth ?? 1,
      borderRadius: borderRadius ?? const Radius.circular(12),
      padding: padding ?? const EdgeInsets.fromLTRB(16, 10, 16, 16),
      headerPadding: headerPadding ?? const EdgeInsets.fromLTRB(10, 8, 8, 2),
      fontFamily: fontFamily,
      fontFamilyPackage: fontFamilyPackage,
      fontSize: fontSize,
      textColor: textColor,
      showLanguageLabel: showLanguageLabel ?? true,
      languageStyle:
          languageStyle ??
          TextStyle(
            color: scheme.onSurfaceVariant,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.35,
          ),
      showCopyButton: showCopyButton ?? true,
      copyLabel: copyLabel ?? 'Copy code',
      copiedLabel: copiedLabel ?? 'Copied!',
      highlightWhileStreaming: highlightWhileStreaming ?? true,
    );
  }

  /// A copy with the given fields replaced.
  CodeBlockStyle copyWith({
    Color? backgroundColor,
    Color? borderColor,
    double? borderWidth,
    Radius? borderRadius,
    EdgeInsetsGeometry? padding,
    EdgeInsetsGeometry? headerPadding,
    String? fontFamily,
    String? fontFamilyPackage,
    double? fontSize,
    Color? textColor,
    bool? showLanguageLabel,
    TextStyle? languageStyle,
    bool? showCopyButton,
    String? copyLabel,
    String? copiedLabel,
    bool? highlightWhileStreaming,
  }) {
    return CodeBlockStyle(
      backgroundColor: backgroundColor ?? this.backgroundColor,
      borderColor: borderColor ?? this.borderColor,
      borderWidth: borderWidth ?? this.borderWidth,
      borderRadius: borderRadius ?? this.borderRadius,
      padding: padding ?? this.padding,
      headerPadding: headerPadding ?? this.headerPadding,
      fontFamily: fontFamily ?? this.fontFamily,
      fontFamilyPackage: fontFamilyPackage ?? this.fontFamilyPackage,
      fontSize: fontSize ?? this.fontSize,
      textColor: textColor ?? this.textColor,
      showLanguageLabel: showLanguageLabel ?? this.showLanguageLabel,
      languageStyle: languageStyle ?? this.languageStyle,
      showCopyButton: showCopyButton ?? this.showCopyButton,
      copyLabel: copyLabel ?? this.copyLabel,
      copiedLabel: copiedLabel ?? this.copiedLabel,
      highlightWhileStreaming:
          highlightWhileStreaming ?? this.highlightWhileStreaming,
    );
  }

  /// Linearly interpolates between two styles.
  static CodeBlockStyle? lerp(CodeBlockStyle? a, CodeBlockStyle? b, double t) {
    if (a == null && b == null) {
      return null;
    }
    if (a == null) {
      return t < 0.5 ? null : b;
    }
    if (b == null) {
      return t < 0.5 ? a : null;
    }
    return CodeBlockStyle(
      backgroundColor: Color.lerp(a.backgroundColor, b.backgroundColor, t),
      borderColor: Color.lerp(a.borderColor, b.borderColor, t),
      borderWidth: lerpDouble(a.borderWidth, b.borderWidth, t),
      borderRadius: Radius.lerp(a.borderRadius, b.borderRadius, t),
      padding: EdgeInsetsGeometry.lerp(a.padding, b.padding, t),
      headerPadding: EdgeInsetsGeometry.lerp(
        a.headerPadding,
        b.headerPadding,
        t,
      ),
      fontFamily: t < 0.5 ? a.fontFamily : b.fontFamily,
      fontFamilyPackage: t < 0.5 ? a.fontFamilyPackage : b.fontFamilyPackage,
      fontSize: lerpDouble(a.fontSize, b.fontSize, t),
      textColor: Color.lerp(a.textColor, b.textColor, t),
      showLanguageLabel: t < 0.5 ? a.showLanguageLabel : b.showLanguageLabel,
      languageStyle: TextStyle.lerp(a.languageStyle, b.languageStyle, t),
      showCopyButton: t < 0.5 ? a.showCopyButton : b.showCopyButton,
      copyLabel: t < 0.5 ? a.copyLabel : b.copyLabel,
      copiedLabel: t < 0.5 ? a.copiedLabel : b.copiedLabel,
      highlightWhileStreaming:
          t < 0.5 ? a.highlightWhileStreaming : b.highlightWhileStreaming,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is CodeBlockStyle &&
        other.backgroundColor == backgroundColor &&
        other.borderColor == borderColor &&
        other.borderWidth == borderWidth &&
        other.borderRadius == borderRadius &&
        other.padding == padding &&
        other.headerPadding == headerPadding &&
        other.fontFamily == fontFamily &&
        other.fontFamilyPackage == fontFamilyPackage &&
        other.fontSize == fontSize &&
        other.textColor == textColor &&
        other.showLanguageLabel == showLanguageLabel &&
        other.languageStyle == languageStyle &&
        other.showCopyButton == showCopyButton &&
        other.copyLabel == copyLabel &&
        other.copiedLabel == copiedLabel &&
        other.highlightWhileStreaming == highlightWhileStreaming;
  }

  @override
  int get hashCode => Object.hash(
    backgroundColor,
    borderColor,
    borderWidth,
    borderRadius,
    padding,
    headerPadding,
    fontFamily,
    fontFamilyPackage,
    fontSize,
    textColor,
    showLanguageLabel,
    languageStyle,
    showCopyButton,
    copyLabel,
    copiedLabel,
    highlightWhileStreaming,
  );
}
