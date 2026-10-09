import 'package:material_ui/material_ui.dart';

/// How rendered maths is drawn.
///
/// Every field is optional. An unset field falls back to the theme, then to
/// the value the package used before this style existed — so setting one
/// field changes one thing and nothing else moves.
///
/// A style on the widget wins over the theme **per field**, not per object.
@immutable
class LatexStyle {
  /// Creates a LatexStyle. Null fields defer to the theme, then to the default.
  const LatexStyle({
    this.textStyle,
    this.padding,
    this.backgroundColor,
    this.borderRadius,
    this.scrollBlockHorizontally,
  });

  /// Applied on top of the surrounding style.
  final TextStyle? textStyle;

  /// Space around block maths. Defaults to none.
  final EdgeInsetsGeometry? padding;

  /// Fill behind block maths. Defaults to none.
  final Color? backgroundColor;

  /// Corner rounding of that fill.
  final Radius? borderRadius;

  /// Whether block maths scrolls sideways rather than overflowing. Defaults to false.
  final bool? scrollBlockHorizontally;

  /// This style, with any unset field taken from [other], field by field.
  LatexStyle merge(LatexStyle? other) {
    if (other == null) {
      return this;
    }
    return LatexStyle(
      textStyle: textStyle ?? other.textStyle,
      padding: padding ?? other.padding,
      backgroundColor: backgroundColor ?? other.backgroundColor,
      borderRadius: borderRadius ?? other.borderRadius,
      scrollBlockHorizontally:
          scrollBlockHorizontally ?? other.scrollBlockHorizontally,
    );
  }

  /// This style with every remaining default filled in.
  LatexStyle resolve(ColorScheme scheme) {
    return LatexStyle(
      textStyle: textStyle,
      padding: padding,
      backgroundColor: backgroundColor,
      borderRadius: borderRadius,
      scrollBlockHorizontally: scrollBlockHorizontally ?? false,
    );
  }

  /// A copy with the given fields replaced.
  LatexStyle copyWith({
    TextStyle? textStyle,
    EdgeInsetsGeometry? padding,
    Color? backgroundColor,
    Radius? borderRadius,
    bool? scrollBlockHorizontally,
  }) {
    return LatexStyle(
      textStyle: textStyle ?? this.textStyle,
      padding: padding ?? this.padding,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      borderRadius: borderRadius ?? this.borderRadius,
      scrollBlockHorizontally:
          scrollBlockHorizontally ?? this.scrollBlockHorizontally,
    );
  }

  /// Linearly interpolates between two styles.
  static LatexStyle? lerp(LatexStyle? a, LatexStyle? b, double t) {
    if (a == null && b == null) {
      return null;
    }
    if (a == null) {
      return t < 0.5 ? null : b;
    }
    if (b == null) {
      return t < 0.5 ? a : null;
    }
    return LatexStyle(
      textStyle: TextStyle.lerp(a.textStyle, b.textStyle, t),
      padding: EdgeInsetsGeometry.lerp(a.padding, b.padding, t),
      backgroundColor: Color.lerp(a.backgroundColor, b.backgroundColor, t),
      borderRadius: Radius.lerp(a.borderRadius, b.borderRadius, t),
      scrollBlockHorizontally: t < 0.5
          ? a.scrollBlockHorizontally
          : b.scrollBlockHorizontally,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is LatexStyle &&
        other.textStyle == textStyle &&
        other.padding == padding &&
        other.backgroundColor == backgroundColor &&
        other.borderRadius == borderRadius &&
        other.scrollBlockHorizontally == scrollBlockHorizontally;
  }

  @override
  int get hashCode => Object.hash(
    textStyle,
    padding,
    backgroundColor,
    borderRadius,
    scrollBlockHorizontally,
  );
}
