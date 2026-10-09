import 'package:material_ui/material_ui.dart';
import 'style_lerp.dart';

/// How a `#` heading is drawn.
///
/// Every field is optional. An unset field falls back to the theme, then to
/// the value the package used before this style existed — so setting one
/// field changes one thing and nothing else moves.
///
/// A style on the widget wins over the theme **per field**, not per object.
@immutable
class HeadingStyle {
  /// Creates a HeadingStyle. Null fields defer to the theme, then to the default.
  const HeadingStyle({
    this.textStyle,
    this.padding,
    this.showDivider,
    this.dividerColor,
    this.dividerThickness,
    this.dividerPadding,
  });

  /// Applied on top of the level style from the theme.
  final TextStyle? textStyle;

  /// Space around the heading. Defaults to none.
  final EdgeInsetsGeometry? padding;

  /// Whether a rule is drawn under the heading.
  final bool? showDivider;

  /// Colour of that rule.
  final Color? dividerColor;

  /// Thickness of that rule.
  final double? dividerThickness;

  /// Space around that rule.
  final EdgeInsetsGeometry? dividerPadding;

  /// This style, with any unset field taken from [other], field by field.
  HeadingStyle merge(HeadingStyle? other) {
    if (other == null) {
      return this;
    }
    return HeadingStyle(
      textStyle: textStyle ?? other.textStyle,
      padding: padding ?? other.padding,
      showDivider: showDivider ?? other.showDivider,
      dividerColor: dividerColor ?? other.dividerColor,
      dividerThickness: dividerThickness ?? other.dividerThickness,
      dividerPadding: dividerPadding ?? other.dividerPadding,
    );
  }

  /// This style with every remaining default filled in.
  ///
  /// Heading defaults live on `GptMarkdownThemeData` as `h1`-`h6`,
  /// `autoAddDividerLineAfterH1` and the `hrLine*` fields. Anything left null here
  /// keeps using those, so existing themes keep working unchanged.
  HeadingStyle resolve(ColorScheme scheme) {
    return HeadingStyle(
      textStyle: textStyle,
      padding: padding,
      showDivider: showDivider,
      dividerColor: dividerColor,
      dividerThickness: dividerThickness,
      dividerPadding: dividerPadding,
    );
  }

  /// A copy with the given fields replaced.
  HeadingStyle copyWith({
    TextStyle? textStyle,
    EdgeInsetsGeometry? padding,
    bool? showDivider,
    Color? dividerColor,
    double? dividerThickness,
    EdgeInsetsGeometry? dividerPadding,
  }) {
    return HeadingStyle(
      textStyle: textStyle ?? this.textStyle,
      padding: padding ?? this.padding,
      showDivider: showDivider ?? this.showDivider,
      dividerColor: dividerColor ?? this.dividerColor,
      dividerThickness: dividerThickness ?? this.dividerThickness,
      dividerPadding: dividerPadding ?? this.dividerPadding,
    );
  }

  /// Linearly interpolates between two styles.
  static HeadingStyle? lerp(HeadingStyle? a, HeadingStyle? b, double t) {
    if (a == null && b == null) {
      return null;
    }
    if (a == null) {
      return t < 0.5 ? null : b;
    }
    if (b == null) {
      return t < 0.5 ? a : null;
    }
    return HeadingStyle(
      textStyle: TextStyle.lerp(a.textStyle, b.textStyle, t),
      padding: EdgeInsetsGeometry.lerp(a.padding, b.padding, t),
      showDivider: t < 0.5 ? a.showDivider : b.showDivider,
      dividerColor: Color.lerp(a.dividerColor, b.dividerColor, t),
      dividerThickness: lerpDouble(a.dividerThickness, b.dividerThickness, t),
      dividerPadding: EdgeInsetsGeometry.lerp(
        a.dividerPadding,
        b.dividerPadding,
        t,
      ),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is HeadingStyle &&
        other.textStyle == textStyle &&
        other.padding == padding &&
        other.showDivider == showDivider &&
        other.dividerColor == dividerColor &&
        other.dividerThickness == dividerThickness &&
        other.dividerPadding == dividerPadding;
  }

  @override
  int get hashCode => Object.hash(
    textStyle,
    padding,
    showDivider,
    dividerColor,
    dividerThickness,
    dividerPadding,
  );
}
