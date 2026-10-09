import 'package:material_ui/material_ui.dart';
import 'style_lerp.dart';

/// How a horizontal rule is drawn.
///
/// Every field is optional. An unset field falls back to the theme, then to
/// the value the package used before this style existed — so setting one
/// field changes one thing and nothing else moves.
///
/// A style on the widget wins over the theme **per field**, not per object.
@immutable
class HrStyle {
  /// Creates a HrStyle. Null fields defer to the theme, then to the default.
  const HrStyle({this.thickness, this.color, this.padding});

  /// Line thickness. Defaults to the theme's `hrLineThickness`.
  final double? thickness;

  /// Line colour. Defaults to the theme's `hrLineColor`.
  final Color? color;

  /// Space around the line. Defaults to `hrLinePadding`.
  final EdgeInsetsGeometry? padding;

  /// This style, with any unset field taken from [other], field by field.
  HrStyle merge(HrStyle? other) {
    if (other == null) {
      return this;
    }
    return HrStyle(
      thickness: thickness ?? other.thickness,
      color: color ?? other.color,
      padding: padding ?? other.padding,
    );
  }

  /// This style with every remaining default filled in.
  ///
  /// Falls back to the `hrLine*` fields on `GptMarkdownThemeData`, which remain
  /// the app-wide way to set them.
  HrStyle resolve(ColorScheme scheme) {
    return HrStyle(thickness: thickness, color: color, padding: padding);
  }

  /// A copy with the given fields replaced.
  HrStyle copyWith({
    double? thickness,
    Color? color,
    EdgeInsetsGeometry? padding,
  }) {
    return HrStyle(
      thickness: thickness ?? this.thickness,
      color: color ?? this.color,
      padding: padding ?? this.padding,
    );
  }

  /// Linearly interpolates between two styles.
  static HrStyle? lerp(HrStyle? a, HrStyle? b, double t) {
    if (a == null && b == null) {
      return null;
    }
    if (a == null) {
      return t < 0.5 ? null : b;
    }
    if (b == null) {
      return t < 0.5 ? a : null;
    }
    return HrStyle(
      thickness: lerpDouble(a.thickness, b.thickness, t),
      color: Color.lerp(a.color, b.color, t),
      padding: EdgeInsetsGeometry.lerp(a.padding, b.padding, t),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is HrStyle &&
        other.thickness == thickness &&
        other.color == color &&
        other.padding == padding;
  }

  @override
  int get hashCode => Object.hash(thickness, color, padding);
}
