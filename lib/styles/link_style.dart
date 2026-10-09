import 'package:material_ui/material_ui.dart';
import 'style_lerp.dart';

/// How a link is drawn.
///
/// Every field is optional. An unset field falls back to the theme, then to
/// the value the package used before this style existed — so setting one
/// field changes one thing and nothing else moves.
///
/// A style on the widget wins over the theme **per field**, not per object.
@immutable
class LinkStyle {
  /// Creates a LinkStyle. Null fields defer to the theme, then to the default.
  const LinkStyle({
    this.color,
    this.hoverColor,
    this.decoration,
    this.decorationThickness,
    this.fontWeight,
  });

  /// Link colour. Defaults to the theme's `linkColor`.
  final Color? color;

  /// Colour under the pointer. Defaults to `linkHoverColor`.
  final Color? hoverColor;

  /// Defaults to an underline.
  final TextDecoration? decoration;

  /// Underline thickness. Defaults to the font's.
  final double? decorationThickness;

  /// Weight of link text. Defaults to the surrounding weight.
  final FontWeight? fontWeight;

  /// This style, with any unset field taken from [other], field by field.
  LinkStyle merge(LinkStyle? other) {
    if (other == null) {
      return this;
    }
    return LinkStyle(
      color: color ?? other.color,
      hoverColor: hoverColor ?? other.hoverColor,
      decoration: decoration ?? other.decoration,
      decorationThickness: decorationThickness ?? other.decorationThickness,
      fontWeight: fontWeight ?? other.fontWeight,
    );
  }

  /// This style with every remaining default filled in.
  ///
  /// Colours fall back to the theme's `linkColor` and `linkHoverColor`, which
  /// remain the app-wide way to set them.
  LinkStyle resolve(ColorScheme scheme) {
    return LinkStyle(
      color: color,
      hoverColor: hoverColor,
      decoration: decoration,
      decorationThickness: decorationThickness,
      fontWeight: fontWeight,
    );
  }

  /// A copy with the given fields replaced.
  LinkStyle copyWith({
    Color? color,
    Color? hoverColor,
    TextDecoration? decoration,
    double? decorationThickness,
    FontWeight? fontWeight,
  }) {
    return LinkStyle(
      color: color ?? this.color,
      hoverColor: hoverColor ?? this.hoverColor,
      decoration: decoration ?? this.decoration,
      decorationThickness: decorationThickness ?? this.decorationThickness,
      fontWeight: fontWeight ?? this.fontWeight,
    );
  }

  /// Linearly interpolates between two styles.
  static LinkStyle? lerp(LinkStyle? a, LinkStyle? b, double t) {
    if (a == null && b == null) {
      return null;
    }
    if (a == null) {
      return t < 0.5 ? null : b;
    }
    if (b == null) {
      return t < 0.5 ? a : null;
    }
    return LinkStyle(
      color: Color.lerp(a.color, b.color, t),
      hoverColor: Color.lerp(a.hoverColor, b.hoverColor, t),
      decoration: t < 0.5 ? a.decoration : b.decoration,
      decorationThickness: lerpDouble(
        a.decorationThickness,
        b.decorationThickness,
        t,
      ),
      fontWeight: FontWeight.lerp(a.fontWeight, b.fontWeight, t),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is LinkStyle &&
        other.color == color &&
        other.hoverColor == hoverColor &&
        other.decoration == decoration &&
        other.decorationThickness == decorationThickness &&
        other.fontWeight == fontWeight;
  }

  @override
  int get hashCode => Object.hash(
    color,
    hoverColor,
    decoration,
    decorationThickness,
    fontWeight,
  );
}
