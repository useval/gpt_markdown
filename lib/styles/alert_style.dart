import 'package:material_ui/material_ui.dart';

import '../plusparse/ast.dart' show MarkdownAlertType;
import 'style_lerp.dart';

/// How alerts are drawn — quotes that open with a marker such as `[!NOTE]`:
///
/// ```markdown
/// > [!TIP]
/// > Pin the version in production.
/// ```
///
/// Every field is optional. The fields at the top level apply to every alert
/// type, and [note], [tip], [important], [warning] and [caution] override them
/// for one type, field by field:
///
/// ```dart
/// GptMarkdown(
///   text,
///   styleSheet: const GptMarkdownStyleSheet(
///     alert: AlertStyle(
///       barWidth: 4,
///       backgroundColor: Color(0x0A000000),
///       warning: AlertStyle(title: 'Heads up', icon: Icons.bolt),
///     ),
///   ),
/// )
/// ```
///
/// Anything still unset resolves per type: an accent colour for the light or
/// dark scheme, an icon, and an English title. For structure rather than looks,
/// use `GptMarkdown.alertBuilder`.
@immutable
class AlertStyle {
  /// Creates an alert style. Null fields fall back to the per-type override,
  /// then to this style, then to the theme, then to the default.
  const AlertStyle({
    this.color,
    this.backgroundColor,
    this.icon,
    this.iconSize,
    this.showIcon,
    this.title,
    this.titleStyle,
    this.titleGap,
    this.textStyle,
    this.barWidth,
    this.borderRadius,
    this.padding,
    this.margin,
    this.note,
    this.tip,
    this.important,
    this.warning,
    this.caution,
  });

  /// Accent colour of the bar, the icon and the title. Defaults to a colour
  /// per type, adjusted for a dark [ColorScheme].
  final Color? color;

  /// Fill behind the alert. Defaults to a faint tint of [color] — 8% opacity,
  /// 12% on a dark [ColorScheme] — which blends with whatever surface the
  /// alert sits on. `Colors.transparent` turns it off.
  final Color? backgroundColor;

  /// Icon before the title. Defaults to one per type.
  final IconData? icon;

  /// Size of the icon. Defaults to 1.15 × the title's font size.
  final double? iconSize;

  /// Whether the icon is drawn. Defaults to true.
  final bool? showIcon;

  /// Text of the title — "Note", "Tip", "Important", "Warning" or "Caution"
  /// by default. An empty string hides the title row.
  final String? title;

  /// Applied on top of the title's default: the surrounding text style in the
  /// accent [color], semi-bold.
  final TextStyle? titleStyle;

  /// Space between the title row and the body. Defaults to `4`.
  final double? titleGap;

  /// Applied on top of the surrounding text style for the body. Defaults to no
  /// change.
  final TextStyle? textStyle;

  /// Thickness of the bar down the side. Defaults to `3`.
  final double? barWidth;

  /// Rounding of the alert's corners. The bar is clipped to it as well.
  /// Defaults to `6`; `Radius.zero` gives square corners.
  final Radius? borderRadius;

  /// Space between the edges of the alert and its content, the bar included
  /// on the start side. Defaults to `12` at the sides and `8` at the top and
  /// bottom.
  final EdgeInsetsGeometry? padding;

  /// Space around the whole alert. Defaults to `vertical: 4`.
  final EdgeInsetsGeometry? margin;

  /// Overrides for `[!NOTE]`.
  final AlertStyle? note;

  /// Overrides for `[!TIP]`.
  final AlertStyle? tip;

  /// Overrides for `[!IMPORTANT]`.
  final AlertStyle? important;

  /// Overrides for `[!WARNING]`.
  final AlertStyle? warning;

  /// Overrides for `[!CAUTION]`.
  final AlertStyle? caution;

  /// The override for [type], or null.
  AlertStyle? overrideFor(MarkdownAlertType type) => switch (type) {
    MarkdownAlertType.note => note,
    MarkdownAlertType.tip => tip,
    MarkdownAlertType.important => important,
    MarkdownAlertType.warning => warning,
    MarkdownAlertType.caution => caution,
  };

  /// This style, with any unset field taken from [other], field by field —
  /// the per-type overrides included.
  AlertStyle merge(AlertStyle? other) {
    if (other == null) {
      return this;
    }
    return AlertStyle(
      color: color ?? other.color,
      backgroundColor: backgroundColor ?? other.backgroundColor,
      icon: icon ?? other.icon,
      iconSize: iconSize ?? other.iconSize,
      showIcon: showIcon ?? other.showIcon,
      title: title ?? other.title,
      titleStyle: titleStyle ?? other.titleStyle,
      titleGap: titleGap ?? other.titleGap,
      textStyle: textStyle ?? other.textStyle,
      barWidth: barWidth ?? other.barWidth,
      borderRadius: borderRadius ?? other.borderRadius,
      padding: padding ?? other.padding,
      margin: margin ?? other.margin,
      note: note?.merge(other.note) ?? other.note,
      tip: tip?.merge(other.tip) ?? other.tip,
      important: important?.merge(other.important) ?? other.important,
      warning: warning?.merge(other.warning) ?? other.warning,
      caution: caution?.merge(other.caution) ?? other.caution,
    );
  }

  /// The style of one [type] with every remaining default filled in.
  ///
  /// The per-type override wins over the shared fields. The result carries no
  /// per-type overrides of its own.
  AlertStyle resolve(MarkdownAlertType type, ColorScheme scheme) {
    final own = overrideFor(type);
    final s = own == null ? this : own.merge(this);
    final dark = scheme.brightness == Brightness.dark;
    final color = s.color ?? _defaultColor(type, dark);
    return AlertStyle(
      color: color,
      backgroundColor:
          s.backgroundColor ?? color.withValues(alpha: dark ? 0.12 : 0.08),
      icon: s.icon ?? _defaultIcon(type),
      iconSize: s.iconSize,
      showIcon: s.showIcon ?? true,
      title: s.title ?? _defaultTitle(type),
      titleStyle: s.titleStyle,
      titleGap: s.titleGap ?? 4,
      textStyle: s.textStyle,
      barWidth: s.barWidth ?? 3,
      borderRadius: s.borderRadius ?? const Radius.circular(6),
      padding: s.padding ?? const EdgeInsetsDirectional.fromSTEB(12, 8, 12, 8),
      margin: s.margin ?? const EdgeInsets.symmetric(vertical: 4),
    );
  }

  static Color _defaultColor(MarkdownAlertType type, bool dark) =>
      switch (type) {
        MarkdownAlertType.note =>
          dark ? const Color(0xFF4493F8) : const Color(0xFF0969DA),
        MarkdownAlertType.tip =>
          dark ? const Color(0xFF3FB950) : const Color(0xFF1A7F37),
        MarkdownAlertType.important =>
          dark ? const Color(0xFFAB7DF8) : const Color(0xFF8250DF),
        MarkdownAlertType.warning =>
          dark ? const Color(0xFFD29922) : const Color(0xFF9A6700),
        MarkdownAlertType.caution =>
          dark ? const Color(0xFFF85149) : const Color(0xFFCF222E),
      };

  static IconData _defaultIcon(MarkdownAlertType type) => switch (type) {
    MarkdownAlertType.note => Icons.info_outline,
    MarkdownAlertType.tip => Icons.lightbulb_outline,
    MarkdownAlertType.important => Icons.feedback_outlined,
    MarkdownAlertType.warning => Icons.warning_amber_rounded,
    MarkdownAlertType.caution => Icons.report_outlined,
  };

  static String _defaultTitle(MarkdownAlertType type) => switch (type) {
    MarkdownAlertType.note => 'Note',
    MarkdownAlertType.tip => 'Tip',
    MarkdownAlertType.important => 'Important',
    MarkdownAlertType.warning => 'Warning',
    MarkdownAlertType.caution => 'Caution',
  };

  /// A copy with the given fields replaced.
  AlertStyle copyWith({
    Color? color,
    Color? backgroundColor,
    IconData? icon,
    double? iconSize,
    bool? showIcon,
    String? title,
    TextStyle? titleStyle,
    double? titleGap,
    TextStyle? textStyle,
    double? barWidth,
    Radius? borderRadius,
    EdgeInsetsGeometry? padding,
    EdgeInsetsGeometry? margin,
    AlertStyle? note,
    AlertStyle? tip,
    AlertStyle? important,
    AlertStyle? warning,
    AlertStyle? caution,
  }) {
    return AlertStyle(
      color: color ?? this.color,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      icon: icon ?? this.icon,
      iconSize: iconSize ?? this.iconSize,
      showIcon: showIcon ?? this.showIcon,
      title: title ?? this.title,
      titleStyle: titleStyle ?? this.titleStyle,
      titleGap: titleGap ?? this.titleGap,
      textStyle: textStyle ?? this.textStyle,
      barWidth: barWidth ?? this.barWidth,
      borderRadius: borderRadius ?? this.borderRadius,
      padding: padding ?? this.padding,
      margin: margin ?? this.margin,
      note: note ?? this.note,
      tip: tip ?? this.tip,
      important: important ?? this.important,
      warning: warning ?? this.warning,
      caution: caution ?? this.caution,
    );
  }

  /// Linearly interpolates between two alert styles.
  static AlertStyle? lerp(AlertStyle? a, AlertStyle? b, double t) {
    if (a == null && b == null) {
      return null;
    }
    if (a == null) {
      return t < 0.5 ? null : b;
    }
    if (b == null) {
      return t < 0.5 ? a : null;
    }
    return AlertStyle(
      color: Color.lerp(a.color, b.color, t),
      backgroundColor: Color.lerp(a.backgroundColor, b.backgroundColor, t),
      icon: t < 0.5 ? a.icon : b.icon,
      iconSize: lerpDouble(a.iconSize, b.iconSize, t),
      showIcon: t < 0.5 ? a.showIcon : b.showIcon,
      title: t < 0.5 ? a.title : b.title,
      titleStyle: TextStyle.lerp(a.titleStyle, b.titleStyle, t),
      titleGap: lerpDouble(a.titleGap, b.titleGap, t),
      textStyle: TextStyle.lerp(a.textStyle, b.textStyle, t),
      barWidth: lerpDouble(a.barWidth, b.barWidth, t),
      borderRadius: Radius.lerp(a.borderRadius, b.borderRadius, t),
      padding: EdgeInsetsGeometry.lerp(a.padding, b.padding, t),
      margin: EdgeInsetsGeometry.lerp(a.margin, b.margin, t),
      note: lerp(a.note, b.note, t),
      tip: lerp(a.tip, b.tip, t),
      important: lerp(a.important, b.important, t),
      warning: lerp(a.warning, b.warning, t),
      caution: lerp(a.caution, b.caution, t),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is AlertStyle &&
        other.color == color &&
        other.backgroundColor == backgroundColor &&
        other.icon == icon &&
        other.iconSize == iconSize &&
        other.showIcon == showIcon &&
        other.title == title &&
        other.titleStyle == titleStyle &&
        other.titleGap == titleGap &&
        other.textStyle == textStyle &&
        other.barWidth == barWidth &&
        other.borderRadius == borderRadius &&
        other.padding == padding &&
        other.margin == margin &&
        other.note == note &&
        other.tip == tip &&
        other.important == important &&
        other.warning == warning &&
        other.caution == caution;
  }

  @override
  int get hashCode => Object.hash(
    color,
    backgroundColor,
    icon,
    iconSize,
    showIcon,
    title,
    titleStyle,
    titleGap,
    textStyle,
    barWidth,
    borderRadius,
    padding,
    margin,
    note,
    tip,
    important,
    warning,
    caution,
  );
}
