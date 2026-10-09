import 'package:material_ui/material_ui.dart';
import 'style_lerp.dart';

/// How an image is drawn.
///
/// Every field is optional. An unset field falls back to the theme, then to
/// the value the package used before this style existed — so setting one
/// field changes one thing and nothing else moves.
///
/// A style on the widget wins over the theme **per field**, not per object.
@immutable
class ImageStyle {
  /// Creates a ImageStyle. Null fields defer to the theme, then to the default.
  const ImageStyle({
    this.borderRadius,
    this.padding,
    this.fit,
    this.maxWidth,
    this.maxHeight,
  });

  /// Corner rounding. Defaults to square.
  final Radius? borderRadius;

  /// Space around the image. Defaults to none.
  final EdgeInsetsGeometry? padding;

  /// How the image fills its box. Defaults to the widget default.
  final BoxFit? fit;

  /// Upper bound on width. Defaults to unbounded.
  final double? maxWidth;

  /// Upper bound on height. Defaults to unbounded.
  final double? maxHeight;

  /// This style, with any unset field taken from [other], field by field.
  ImageStyle merge(ImageStyle? other) {
    if (other == null) {
      return this;
    }
    return ImageStyle(
      borderRadius: borderRadius ?? other.borderRadius,
      padding: padding ?? other.padding,
      fit: fit ?? other.fit,
      maxWidth: maxWidth ?? other.maxWidth,
      maxHeight: maxHeight ?? other.maxHeight,
    );
  }

  /// This style with every remaining default filled in.
  ImageStyle resolve(ColorScheme scheme) {
    return ImageStyle(
      borderRadius: borderRadius,
      padding: padding,
      fit: fit,
      maxWidth: maxWidth,
      maxHeight: maxHeight,
    );
  }

  /// A copy with the given fields replaced.
  ImageStyle copyWith({
    Radius? borderRadius,
    EdgeInsetsGeometry? padding,
    BoxFit? fit,
    double? maxWidth,
    double? maxHeight,
  }) {
    return ImageStyle(
      borderRadius: borderRadius ?? this.borderRadius,
      padding: padding ?? this.padding,
      fit: fit ?? this.fit,
      maxWidth: maxWidth ?? this.maxWidth,
      maxHeight: maxHeight ?? this.maxHeight,
    );
  }

  /// Linearly interpolates between two styles.
  static ImageStyle? lerp(ImageStyle? a, ImageStyle? b, double t) {
    if (a == null && b == null) {
      return null;
    }
    if (a == null) {
      return t < 0.5 ? null : b;
    }
    if (b == null) {
      return t < 0.5 ? a : null;
    }
    return ImageStyle(
      borderRadius: Radius.lerp(a.borderRadius, b.borderRadius, t),
      padding: EdgeInsetsGeometry.lerp(a.padding, b.padding, t),
      fit: t < 0.5 ? a.fit : b.fit,
      maxWidth: lerpDouble(a.maxWidth, b.maxWidth, t),
      maxHeight: lerpDouble(a.maxHeight, b.maxHeight, t),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is ImageStyle &&
        other.borderRadius == borderRadius &&
        other.padding == padding &&
        other.fit == fit &&
        other.maxWidth == maxWidth &&
        other.maxHeight == maxHeight;
  }

  @override
  int get hashCode =>
      Object.hash(borderRadius, padding, fit, maxWidth, maxHeight);
}
