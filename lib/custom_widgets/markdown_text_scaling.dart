import 'package:flutter/widgets.dart';

/// Shared text-scaling contract for Markdown widgets and custom renderers.
///
/// Standalone blocks inherit the document's MediaQuery text scaler. A widget
/// inside a paragraph must not scale itself too: Flutter scales its entire
/// WidgetSpan box. Build ordinary Text widgets with unscaled font sizes.
/// Renderers that paint their own glyphs must use [fontSize] at build time.
abstract final class MarkdownTextScaling {
  /// Enable inherited scaling for standalone content, or suppress it when an
  /// enclosing paragraph owns scaling. The enabled path adds no widget.
  static Widget wrap(Widget child, {required bool enabled}) =>
      enabled ? child : MediaQuery.withNoTextScaling(child: child);

  /// Resolve a glyph size for a renderer that does not use Text/RichText.
  /// Do not apply this to Text's style: Text already uses the ambient scaler.
  static double fontSize(BuildContext context, double unscaledSize) =>
      MediaQuery.textScalerOf(context).scale(unscaledSize);
}
