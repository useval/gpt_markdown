import 'package:material_ui/material_ui.dart';
import 'style_lerp.dart';

/// How a `[1]` citation chip is drawn.
///
/// Every field is optional. An unset field falls back to the theme, then to
/// the value the package used before this style existed — so setting one
/// field changes one thing and nothing else moves.
///
/// A style on the widget wins over the theme **per field**, not per object.
@immutable
class SourceTagStyle {
  /// Creates a SourceTagStyle. Null fields defer to the theme, then to the default.
  const SourceTagStyle({
    this.backgroundColor,
    this.textStyle,
    this.size,
    this.shape,
    this.padding,
  });

  /// Chip fill. Defaults to `ColorScheme.onInverseSurface`.
  final Color? backgroundColor;

  /// Number style. Defaults to the surrounding style.
  final TextStyle? textStyle;

  /// Chip diameter. Defaults to 20.
  final double? size;

  /// Chip shape. Defaults to a circle.
  final BoxShape? shape;

  /// Space around the chip. Defaults to 2.
  final EdgeInsetsGeometry? padding;

  /// This style, with any unset field taken from [other], field by field.
  SourceTagStyle merge(SourceTagStyle? other) {
    if (other == null) {
      return this;
    }
    return SourceTagStyle(
      backgroundColor: backgroundColor ?? other.backgroundColor,
      textStyle: textStyle ?? other.textStyle,
      size: size ?? other.size,
      shape: shape ?? other.shape,
      padding: padding ?? other.padding,
    );
  }

  /// This style with every remaining default filled in.
  SourceTagStyle resolve(ColorScheme scheme) {
    return SourceTagStyle(
      backgroundColor: backgroundColor ?? scheme.onInverseSurface,
      textStyle: textStyle,
      size: size ?? 20,
      shape: shape ?? BoxShape.circle,
      padding: padding ?? const EdgeInsets.all(2),
    );
  }

  /// A copy with the given fields replaced.
  SourceTagStyle copyWith({
    Color? backgroundColor,
    TextStyle? textStyle,
    double? size,
    BoxShape? shape,
    EdgeInsetsGeometry? padding,
  }) {
    return SourceTagStyle(
      backgroundColor: backgroundColor ?? this.backgroundColor,
      textStyle: textStyle ?? this.textStyle,
      size: size ?? this.size,
      shape: shape ?? this.shape,
      padding: padding ?? this.padding,
    );
  }

  /// Linearly interpolates between two styles.
  static SourceTagStyle? lerp(SourceTagStyle? a, SourceTagStyle? b, double t) {
    if (a == null && b == null) {
      return null;
    }
    if (a == null) {
      return t < 0.5 ? null : b;
    }
    if (b == null) {
      return t < 0.5 ? a : null;
    }
    return SourceTagStyle(
      backgroundColor: Color.lerp(a.backgroundColor, b.backgroundColor, t),
      textStyle: TextStyle.lerp(a.textStyle, b.textStyle, t),
      size: lerpDouble(a.size, b.size, t),
      shape: t < 0.5 ? a.shape : b.shape,
      padding: EdgeInsetsGeometry.lerp(a.padding, b.padding, t),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is SourceTagStyle &&
        other.backgroundColor == backgroundColor &&
        other.textStyle == textStyle &&
        other.size == size &&
        other.shape == shape &&
        other.padding == padding;
  }

  @override
  int get hashCode =>
      Object.hash(backgroundColor, textStyle, size, shape, padding);
}
