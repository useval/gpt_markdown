import 'package:material_ui/material_ui.dart';
import 'style_lerp.dart';

/// How a task-list checkbox or radio button is drawn.
///
/// Every field is optional. An unset field falls back to the theme, then to
/// the value the package used before this style existed — so setting one
/// field changes one thing and nothing else moves.
///
/// A style on the widget wins over the theme **per field**, not per object.
@immutable
class CheckboxStyle {
  /// Creates a CheckboxStyle. Null fields defer to the theme, then to the default.
  const CheckboxStyle({
    this.size,
    this.checkedColor,
    this.uncheckedColor,
    this.checkColor,
    this.borderRadius,
    this.gapAfterBox,
    this.interactive,
  });

  /// Box size. Defaults to the Material default.
  final double? size;

  /// Fill when checked. Defaults to the Material default.
  final Color? checkedColor;

  /// Border when unchecked. Defaults to the Material default.
  final Color? uncheckedColor;

  /// The tick itself. Defaults to the Material default.
  final Color? checkColor;

  /// Corner rounding of a checkbox.
  final Radius? borderRadius;

  /// Space between the box and its label. Defaults to 5.
  final double? gapAfterBox;

  /// Whether taps are accepted. Defaults to false.
  final bool? interactive;

  /// This style, with any unset field taken from [other], field by field.
  CheckboxStyle merge(CheckboxStyle? other) {
    if (other == null) {
      return this;
    }
    return CheckboxStyle(
      size: size ?? other.size,
      checkedColor: checkedColor ?? other.checkedColor,
      uncheckedColor: uncheckedColor ?? other.uncheckedColor,
      checkColor: checkColor ?? other.checkColor,
      borderRadius: borderRadius ?? other.borderRadius,
      gapAfterBox: gapAfterBox ?? other.gapAfterBox,
      interactive: interactive ?? other.interactive,
    );
  }

  /// This style with every remaining default filled in.
  ///
  /// Colours left null use Material's own checkbox and radio defaults, so the
  /// widgets keep following the app theme.
  CheckboxStyle resolve(ColorScheme scheme) {
    return CheckboxStyle(
      size: size,
      checkedColor: checkedColor,
      uncheckedColor: uncheckedColor,
      checkColor: checkColor,
      borderRadius: borderRadius,
      gapAfterBox: gapAfterBox ?? 5,
      interactive: interactive ?? false,
    );
  }

  /// A copy with the given fields replaced.
  CheckboxStyle copyWith({
    double? size,
    Color? checkedColor,
    Color? uncheckedColor,
    Color? checkColor,
    Radius? borderRadius,
    double? gapAfterBox,
    bool? interactive,
  }) {
    return CheckboxStyle(
      size: size ?? this.size,
      checkedColor: checkedColor ?? this.checkedColor,
      uncheckedColor: uncheckedColor ?? this.uncheckedColor,
      checkColor: checkColor ?? this.checkColor,
      borderRadius: borderRadius ?? this.borderRadius,
      gapAfterBox: gapAfterBox ?? this.gapAfterBox,
      interactive: interactive ?? this.interactive,
    );
  }

  /// Linearly interpolates between two styles.
  static CheckboxStyle? lerp(CheckboxStyle? a, CheckboxStyle? b, double t) {
    if (a == null && b == null) {
      return null;
    }
    if (a == null) {
      return t < 0.5 ? null : b;
    }
    if (b == null) {
      return t < 0.5 ? a : null;
    }
    return CheckboxStyle(
      size: lerpDouble(a.size, b.size, t),
      checkedColor: Color.lerp(a.checkedColor, b.checkedColor, t),
      uncheckedColor: Color.lerp(a.uncheckedColor, b.uncheckedColor, t),
      checkColor: Color.lerp(a.checkColor, b.checkColor, t),
      borderRadius: Radius.lerp(a.borderRadius, b.borderRadius, t),
      gapAfterBox: lerpDouble(a.gapAfterBox, b.gapAfterBox, t),
      interactive: t < 0.5 ? a.interactive : b.interactive,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is CheckboxStyle &&
        other.size == size &&
        other.checkedColor == checkedColor &&
        other.uncheckedColor == uncheckedColor &&
        other.checkColor == checkColor &&
        other.borderRadius == borderRadius &&
        other.gapAfterBox == gapAfterBox &&
        other.interactive == interactive;
  }

  @override
  int get hashCode => Object.hash(
    size,
    checkedColor,
    uncheckedColor,
    checkColor,
    borderRadius,
    gapAfterBox,
    interactive,
  );
}
