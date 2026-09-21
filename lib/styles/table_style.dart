import 'package:flutter/material.dart';
import 'style_lerp.dart';

/// How a table is drawn.
///
/// Every field is optional. An unset field falls back to the theme, then to
/// the value the package used before this style existed — so setting one
/// field changes one thing and nothing else moves.
///
/// A style on the widget wins over the theme **per field**, not per object.
@immutable
class TableStyle {
  /// Creates a TableStyle. Null fields defer to the theme, then to the default.
  const TableStyle({
    this.borderColor,
    this.borderWidth,
    this.borderRadius,
    this.cellPadding,
    this.headerBackground,
    this.headerTextStyle,
    this.rowStripeColor,
    this.columnWidth,
  });

  /// Grid colour. Defaults to `ColorScheme.onSurface`.
  final Color? borderColor;

  /// Grid thickness. Defaults to 1.
  final double? borderWidth;

  /// Outer corner rounding. Defaults to square.
  final Radius? borderRadius;

  /// Space inside a cell. Defaults to 8 by 4.
  final EdgeInsetsGeometry? cellPadding;

  /// Header row fill. Defaults to `surfaceContainerHighest`.
  final Color? headerBackground;

  /// Header text style. Defaults to the body style.
  final TextStyle? headerTextStyle;

  /// Optional width policy for every column. FixedColumnWidth skips content
  /// measurement and is useful for large streaming tables. Null preserves
  /// content-sized columns. Flex widths require a bounded table width.
  final TableColumnWidth? columnWidth;

  /// Fill for alternating rows. Defaults to none.
  final Color? rowStripeColor;

  /// This style, with any unset field taken from [other], field by field.
  TableStyle merge(TableStyle? other) {
    if (other == null) {
      return this;
    }
    return TableStyle(
      borderColor: borderColor ?? other.borderColor,
      borderWidth: borderWidth ?? other.borderWidth,
      borderRadius: borderRadius ?? other.borderRadius,
      cellPadding: cellPadding ?? other.cellPadding,
      headerBackground: headerBackground ?? other.headerBackground,
      headerTextStyle: headerTextStyle ?? other.headerTextStyle,
      rowStripeColor: rowStripeColor ?? other.rowStripeColor,
      columnWidth: columnWidth ?? other.columnWidth,
    );
  }

  /// This style with every remaining default filled in.
  TableStyle resolve(ColorScheme scheme) {
    return TableStyle(
      borderColor: borderColor ?? scheme.onSurface,
      borderWidth: borderWidth ?? 1,
      borderRadius: borderRadius,
      cellPadding:
          cellPadding ?? const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      headerBackground: headerBackground ?? scheme.surfaceContainerHighest,
      headerTextStyle: headerTextStyle,
      rowStripeColor: rowStripeColor,
      columnWidth: columnWidth,
    );
  }

  /// A copy with the given fields replaced.
  TableStyle copyWith({
    Color? borderColor,
    double? borderWidth,
    Radius? borderRadius,
    EdgeInsetsGeometry? cellPadding,
    Color? headerBackground,
    TextStyle? headerTextStyle,
    Color? rowStripeColor,
    TableColumnWidth? columnWidth,
  }) {
    return TableStyle(
      borderColor: borderColor ?? this.borderColor,
      borderWidth: borderWidth ?? this.borderWidth,
      borderRadius: borderRadius ?? this.borderRadius,
      cellPadding: cellPadding ?? this.cellPadding,
      headerBackground: headerBackground ?? this.headerBackground,
      headerTextStyle: headerTextStyle ?? this.headerTextStyle,
      rowStripeColor: rowStripeColor ?? this.rowStripeColor,
      columnWidth: columnWidth ?? this.columnWidth,
    );
  }

  /// Linearly interpolates between two styles.
  static TableStyle? lerp(TableStyle? a, TableStyle? b, double t) {
    if (a == null && b == null) {
      return null;
    }
    if (a == null) {
      return t < 0.5 ? null : b;
    }
    if (b == null) {
      return t < 0.5 ? a : null;
    }
    return TableStyle(
      borderColor: Color.lerp(a.borderColor, b.borderColor, t),
      borderWidth: lerpDouble(a.borderWidth, b.borderWidth, t),
      borderRadius: Radius.lerp(a.borderRadius, b.borderRadius, t),
      cellPadding: EdgeInsetsGeometry.lerp(a.cellPadding, b.cellPadding, t),
      headerBackground: Color.lerp(a.headerBackground, b.headerBackground, t),
      headerTextStyle: TextStyle.lerp(a.headerTextStyle, b.headerTextStyle, t),
      rowStripeColor: Color.lerp(a.rowStripeColor, b.rowStripeColor, t),
      columnWidth: t < 0.5 ? a.columnWidth : b.columnWidth,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is TableStyle &&
        other.borderColor == borderColor &&
        other.borderWidth == borderWidth &&
        other.borderRadius == borderRadius &&
        other.cellPadding == cellPadding &&
        other.headerBackground == headerBackground &&
        other.headerTextStyle == headerTextStyle &&
        other.rowStripeColor == rowStripeColor &&
        other.columnWidth == columnWidth;
  }

  @override
  int get hashCode => Object.hash(
    borderColor,
    borderWidth,
    borderRadius,
    cellPadding,
    headerBackground,
    headerTextStyle,
    rowStripeColor,
    columnWidth,
  );
}
