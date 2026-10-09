import 'package:material_ui/material_ui.dart';

import 'style_lerp.dart';

/// How a blockquote is drawn.
///
/// Every field is optional. An unset field falls back to the theme's value,
/// then to a default derived from the ambient [ColorScheme] — so setting one
/// field changes one thing and leaves the rest alone:
///
/// ```dart
/// GptMarkdown(
///   text,
///   styleSheet: const GptMarkdownStyleSheet(
///     blockQuote: BlockQuoteStyle(barWidth: 4),
///   ),
/// )
/// ```
///
/// Set it on [GptMarkdownThemeData] instead to restyle every blockquote in the
/// app. A value on the widget wins over the theme **per field**, not per
/// object, so a widget that sets only `barWidth` keeps the theme's `barColor`.
@immutable
class BlockQuoteStyle {
  /// Creates a blockquote style. Null fields defer to the theme, then to the
  /// resolved default.
  const BlockQuoteStyle({
    this.barWidth,
    this.barColor,
    this.barRadius,
    this.backgroundColor,
    this.padding,
    this.margin,
    this.textStyle,
  });

  /// Thickness of the bar down the side. Defaults to `3`.
  final double? barWidth;

  /// Colour of the bar. Defaults to `ColorScheme.onSurfaceVariant`.
  final Color? barColor;

  /// Rounding of the bar. Defaults to square corners.
  final Radius? barRadius;

  /// Fill behind the quote. Defaults to none.
  final Color? backgroundColor;

  /// Space between the bar and the quoted content. Defaults to `start: 8`.
  final EdgeInsetsGeometry? padding;

  /// Space around the whole quote. Defaults to `vertical: 2`.
  final EdgeInsetsGeometry? margin;

  /// Applied on top of the surrounding text style. Defaults to no change.
  final TextStyle? textStyle;

  /// This style, with any unset field taken from [other].
  ///
  /// Per field, not per object: a style setting only `barWidth` keeps
  /// [other]'s colour and padding.
  BlockQuoteStyle merge(BlockQuoteStyle? other) {
    if (other == null) {
      return this;
    }
    return BlockQuoteStyle(
      barWidth: barWidth ?? other.barWidth,
      barColor: barColor ?? other.barColor,
      barRadius: barRadius ?? other.barRadius,
      backgroundColor: backgroundColor ?? other.backgroundColor,
      padding: padding ?? other.padding,
      margin: margin ?? other.margin,
      textStyle: textStyle ?? other.textStyle,
    );
  }

  /// This style with every remaining null filled in.
  ///
  /// The defaults are the values the package used before blockquotes were
  /// configurable, so an app that sets nothing sees no change.
  BlockQuoteStyle resolve(ColorScheme scheme) {
    return BlockQuoteStyle(
      barWidth: barWidth ?? 3,
      barColor: barColor ?? scheme.onSurfaceVariant,
      barRadius: barRadius,
      backgroundColor: backgroundColor,
      padding: padding ?? const EdgeInsetsDirectional.only(start: 8),
      margin: margin ?? const EdgeInsets.symmetric(vertical: 2),
      textStyle: textStyle,
    );
  }

  /// A copy with the given fields replaced.
  BlockQuoteStyle copyWith({
    double? barWidth,
    Color? barColor,
    Radius? barRadius,
    Color? backgroundColor,
    EdgeInsetsGeometry? padding,
    EdgeInsetsGeometry? margin,
    TextStyle? textStyle,
  }) {
    return BlockQuoteStyle(
      barWidth: barWidth ?? this.barWidth,
      barColor: barColor ?? this.barColor,
      barRadius: barRadius ?? this.barRadius,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      padding: padding ?? this.padding,
      margin: margin ?? this.margin,
      textStyle: textStyle ?? this.textStyle,
    );
  }

  /// Linearly interpolates between two blockquote styles.
  static BlockQuoteStyle? lerp(
    BlockQuoteStyle? a,
    BlockQuoteStyle? b,
    double t,
  ) {
    if (a == null && b == null) {
      return null;
    }
    if (a == null) {
      return t < 0.5 ? null : b;
    }
    if (b == null) {
      return t < 0.5 ? a : null;
    }
    return BlockQuoteStyle(
      barWidth: lerpDouble(a.barWidth, b.barWidth, t),
      barColor: Color.lerp(a.barColor, b.barColor, t),
      barRadius: Radius.lerp(a.barRadius, b.barRadius, t),
      backgroundColor: Color.lerp(a.backgroundColor, b.backgroundColor, t),
      padding: EdgeInsetsGeometry.lerp(a.padding, b.padding, t),
      margin: EdgeInsetsGeometry.lerp(a.margin, b.margin, t),
      textStyle: TextStyle.lerp(a.textStyle, b.textStyle, t),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is BlockQuoteStyle &&
        other.barWidth == barWidth &&
        other.barColor == barColor &&
        other.barRadius == barRadius &&
        other.backgroundColor == backgroundColor &&
        other.padding == padding &&
        other.margin == margin &&
        other.textStyle == textStyle;
  }

  @override
  int get hashCode => Object.hash(
    barWidth,
    barColor,
    barRadius,
    backgroundColor,
    padding,
    margin,
    textStyle,
  );
}
