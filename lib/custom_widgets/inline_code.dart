/// Inline `code` decoration.
///
/// Flutter gives an [InlineSpan] exactly one decoration slot —
/// [TextStyle.background], a single [Paint]. One [Paint] is a fill *or* a
/// stroke, never both, and it has no corner radius and no padding. So the usual
/// way to draw a rounded, outlined code chip is a [WidgetSpan] wrapping a
/// [Container] — which cannot wrap across lines, breaks text selection, sits
/// off the surrounding baseline, and does not paint on iOS when it ends up
/// nested inside another [WidgetSpan] (a link label, for instance).
///
/// This library takes the approach CSS calls `box-decoration-break: clone`: the
/// code text stays a plain [TextSpan], and the chip is painted *underneath* the
/// paragraph, once per line fragment. Long inline code wraps and gets one
/// rounded chip per line, and everything a [TextSpan] gives you — selection,
/// wrapping, baseline alignment — is preserved.
library;

import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/rendering.dart';

/// The monospace family bundled with this package, also used by code blocks.
const String kGptMarkdownMonoFontFamily = 'JetBrainsMono';

/// The package that ships [kGptMarkdownMonoFontFamily].
const String kGptMarkdownFontPackage = 'gpt_markdown';

/// How inline `code` is drawn.
///
/// Every field is optional and falls back to a value derived from the ambient
/// [ColorScheme], so the common case is a one-liner:
///
/// ```dart
/// GptMarkdown(
///   text,
///   inlineCodeStyle: InlineCodeStyle(
///     fontFamily: 'GeistMono',
///     color: Colors.pink,
///     backgroundColor: Colors.pink.withValues(alpha: 0.06),
///     borderColor: Colors.pink.withValues(alpha: 0.2),
///   ),
/// )
/// ```
///
/// Set it on [GptMarkdownThemeData] instead to restyle every `GptMarkdown` in
/// the app at once.
@immutable
class InlineCodeStyle {
  /// Creates an inline code style. Null fields keep the resolved default.
  const InlineCodeStyle({
    this.fontFamily,
    this.fontFamilyPackage,
    this.fontFamilyFallback,
    this.fontSizeFactor,
    this.fontWeight,
    this.color,
    this.backgroundColor,
    this.borderColor,
    this.borderWidth,
    this.borderRadius,
    this.padding,
    this.boxHeightStyle,
  });

  /// The monospace family. Defaults to the bundled JetBrains Mono, the same
  /// family fenced code blocks use.
  final String? fontFamily;

  /// The package [fontFamily] is shipped in.
  ///
  /// Defaults to `gpt_markdown` **only** while [fontFamily] is also null. Set
  /// [fontFamily] to a family of your own and this stays null unless you say
  /// otherwise, which is what you want for an app-level font.
  final String? fontFamilyPackage;

  /// Fallback families, used when a glyph is missing from [fontFamily].
  final List<String>? fontFamilyFallback;

  /// Code font size relative to the surrounding text. Defaults to `0.94`.
  ///
  /// Monospace faces read larger than proportional ones at the same point size,
  /// so a small reduction keeps the line rhythm even.
  final double? fontSizeFactor;

  /// Weight of the code text. Defaults to the surrounding weight.
  final FontWeight? fontWeight;

  /// Colour of the code text. Defaults to `ColorScheme.onSurface`.
  final Color? color;

  /// Chip fill. Defaults to a tint of `ColorScheme.onSurface` — 10% on a light
  /// scheme, 14% on a dark one, since a light tint over a dark surface reads
  /// weaker than the same tint over a light one.
  final Color? backgroundColor;

  /// Chip outline. Defaults to a tint of `ColorScheme.onSurface` — 28% light,
  /// 34% dark.
  ///
  /// Set to [Colors.transparent] for a fill with no outline.
  final Color? borderColor;

  /// Outline thickness. Defaults to `1.0`. Zero disables the outline.
  final double? borderWidth;

  /// Corner radius. Defaults to `Radius.circular(4)`.
  final Radius? borderRadius;

  /// Space between the text and the chip edge. Defaults to
  /// `EdgeInsets.symmetric(vertical: 1)` — no horizontal padding, so the chip
  /// hugs the code and the surrounding words keep their normal spacing.
  ///
  /// Horizontal padding, when set, is applied to the outer edges of a wrapped
  /// run only — a chip continuing onto the next line is not padded at the
  /// break, so the two halves read as one run.
  final EdgeInsets? padding;

  /// How the height of each line fragment is measured.
  ///
  /// Defaults to [ui.BoxHeightStyle.tight], which follows the code font's own
  /// metrics. Use [ui.BoxHeightStyle.strut] for chips that fill the line box.
  final ui.BoxHeightStyle? boxHeightStyle;

  /// This style, with any unset field taken from [other], field by field.
  ///
  /// Per field, not per object: a style setting only `color` keeps [other]'s
  /// font, padding and border.
  InlineCodeStyle merge(InlineCodeStyle? other) {
    if (other == null) {
      return this;
    }
    return InlineCodeStyle(
      fontFamily: fontFamily ?? other.fontFamily,
      fontFamilyPackage: fontFamilyPackage ?? other.fontFamilyPackage,
      fontFamilyFallback: fontFamilyFallback ?? other.fontFamilyFallback,
      fontSizeFactor: fontSizeFactor ?? other.fontSizeFactor,
      fontWeight: fontWeight ?? other.fontWeight,
      color: color ?? other.color,
      backgroundColor: backgroundColor ?? other.backgroundColor,
      borderColor: borderColor ?? other.borderColor,
      borderWidth: borderWidth ?? other.borderWidth,
      borderRadius: borderRadius ?? other.borderRadius,
      padding: padding ?? other.padding,
      boxHeightStyle: boxHeightStyle ?? other.boxHeightStyle,
    );
  }

  /// This style with every null field filled in from [scheme].
  InlineCodeStyle resolve(ColorScheme scheme) {
    final hasCustomFamily = fontFamily != null;
    final isDark = scheme.brightness == Brightness.dark;
    return InlineCodeStyle(
      fontFamily: fontFamily ?? kGptMarkdownMonoFontFamily,
      fontFamilyPackage:
          fontFamilyPackage ??
          (hasCustomFamily ? null : kGptMarkdownFontPackage),
      fontFamilyFallback: fontFamilyFallback,
      fontSizeFactor: fontSizeFactor ?? 0.94,
      fontWeight: fontWeight,
      color: color ?? scheme.onSurface,
      // Tints have to be stronger on a dark scheme: the same alpha of a light
      // ink over a dark ground separates less than dark ink over a light one.
      backgroundColor:
          backgroundColor ??
          scheme.onSurface.withValues(alpha: isDark ? 0.14 : 0.10),
      borderColor:
          borderColor ??
          scheme.onSurface.withValues(alpha: isDark ? 0.34 : 0.28),
      borderWidth: borderWidth ?? 1.0,
      borderRadius: borderRadius ?? const Radius.circular(4),
      padding: padding ?? const EdgeInsets.symmetric(vertical: 1),
      boxHeightStyle: boxHeightStyle ?? ui.BoxHeightStyle.tight,
    );
  }

  /// A copy of this style with the given fields replaced.
  InlineCodeStyle copyWith({
    String? fontFamily,
    String? fontFamilyPackage,
    List<String>? fontFamilyFallback,
    double? fontSizeFactor,
    FontWeight? fontWeight,
    Color? color,
    Color? backgroundColor,
    Color? borderColor,
    double? borderWidth,
    Radius? borderRadius,
    EdgeInsets? padding,
    ui.BoxHeightStyle? boxHeightStyle,
  }) {
    return InlineCodeStyle(
      fontFamily: fontFamily ?? this.fontFamily,
      fontFamilyPackage: fontFamilyPackage ?? this.fontFamilyPackage,
      fontFamilyFallback: fontFamilyFallback ?? this.fontFamilyFallback,
      fontSizeFactor: fontSizeFactor ?? this.fontSizeFactor,
      fontWeight: fontWeight ?? this.fontWeight,
      color: color ?? this.color,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      borderColor: borderColor ?? this.borderColor,
      borderWidth: borderWidth ?? this.borderWidth,
      borderRadius: borderRadius ?? this.borderRadius,
      padding: padding ?? this.padding,
      boxHeightStyle: boxHeightStyle ?? this.boxHeightStyle,
    );
  }

  /// Linearly interpolates between two inline code styles.
  static InlineCodeStyle? lerp(
    InlineCodeStyle? a,
    InlineCodeStyle? b,
    double t,
  ) {
    if (a == null && b == null) {
      return null;
    }
    if (a == null) {
      return t < 0.5 ? null : b;
    }
    if (b == null) {
      return t < 0.5 ? a : null;
    }
    return InlineCodeStyle(
      fontFamily: t < 0.5 ? a.fontFamily : b.fontFamily,
      fontFamilyPackage: t < 0.5 ? a.fontFamilyPackage : b.fontFamilyPackage,
      fontFamilyFallback: t < 0.5 ? a.fontFamilyFallback : b.fontFamilyFallback,
      fontSizeFactor: ui.lerpDouble(a.fontSizeFactor, b.fontSizeFactor, t),
      fontWeight: FontWeight.lerp(a.fontWeight, b.fontWeight, t),
      color: Color.lerp(a.color, b.color, t),
      backgroundColor: Color.lerp(a.backgroundColor, b.backgroundColor, t),
      borderColor: Color.lerp(a.borderColor, b.borderColor, t),
      borderWidth: ui.lerpDouble(a.borderWidth, b.borderWidth, t),
      borderRadius: Radius.lerp(a.borderRadius, b.borderRadius, t),
      padding: EdgeInsets.lerp(a.padding, b.padding, t),
      boxHeightStyle: t < 0.5 ? a.boxHeightStyle : b.boxHeightStyle,
    );
  }

  /// [base] with this style's typography applied.
  ///
  /// Colours other than [color] are painted by [InlineCodeDecoration], not
  /// carried on the [TextStyle] — that is what lets the chip have a radius, an
  /// outline and padding while the text still wraps.
  TextStyle applyTo(TextStyle base) {
    final family = fontFamily;
    final package = fontFamilyPackage;
    final baseSize = base.fontSize;
    final factor = fontSizeFactor;
    return base.copyWith(
      fontFamily: family == null || package == null
          ? family
          : 'packages/$package/$family',
      fontFamilyFallback: fontFamilyFallback,
      fontSize: baseSize == null || factor == null
          ? baseSize
          : baseSize * factor,
      fontWeight: fontWeight,
      color: color,
      // A stale background Paint from the caller's style would double-paint
      // under the chip.
      background: null,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is InlineCodeStyle &&
        other.fontFamily == fontFamily &&
        other.fontFamilyPackage == fontFamilyPackage &&
        listEquals(other.fontFamilyFallback, fontFamilyFallback) &&
        other.fontSizeFactor == fontSizeFactor &&
        other.fontWeight == fontWeight &&
        other.color == color &&
        other.backgroundColor == backgroundColor &&
        other.borderColor == borderColor &&
        other.borderWidth == borderWidth &&
        other.borderRadius == borderRadius &&
        other.padding == padding &&
        other.boxHeightStyle == boxHeightStyle;
  }

  @override
  int get hashCode => Object.hash(
    fontFamily,
    fontFamilyPackage,
    Object.hashAll(fontFamilyFallback ?? const <String>[]),
    fontSizeFactor,
    fontWeight,
    color,
    backgroundColor,
    borderColor,
    borderWidth,
    borderRadius,
    padding,
    boxHeightStyle,
  );
}

/// Wraps [child] in a [WidgetSpan] that sits on the surrounding text baseline.
///
/// A widget in a paragraph defaults to being centred on the line box, which
/// leaves it visibly off the baseline of the words around it. Use this from an
/// [InlineCodeBuilder] when the design genuinely needs a widget:
///
/// ```dart
/// inlineCodeBuilder: (context, code, style, codeStyle) =>
///     baselineWidgetSpan(MyCodeChip(code: code, style: style)),
/// ```
///
/// A [WidgetSpan] still cannot wrap across lines and is skipped by text
/// selection — prefer returning a [CodeTextSpan] where the design allows.
WidgetSpan baselineWidgetSpan(Widget child) {
  return WidgetSpan(
    alignment: PlaceholderAlignment.baseline,
    baseline: TextBaseline.alphabetic,
    // A paragraph scales an inline widget's box for you; a child that also
    // scales its own text is counted twice. See `GptMarkdownConfig.getRich`.
    child: MediaQuery.withNoTextScaling(child: child),
  );
}

/// A [TextSpan] carrying inline `code`, tagged so the paragraph can find it and
/// paint a chip behind it.
///
/// Behaves as an ordinary [TextSpan] everywhere else, so code text stays
/// selectable, wraps, and sits on the surrounding baseline.
class CodeTextSpan extends TextSpan {
  /// Creates a tagged inline-code span.
  const CodeTextSpan({
    required String super.text,
    required this.codeStyle,
    super.style,
    super.recognizer,
    super.mouseCursor,
    super.semanticsLabel,
  });

  /// Creates a tagged span over already-built [children] instead of one text
  /// run.
  ///
  /// This is the form the streaming reveal emits while a code span's last
  /// characters are still arriving: the pieces are separate spans, and the
  /// container rebuilt around them has to keep the tag or the chip is not
  /// painted until the whole paragraph settles. Measured by its subtree in
  /// [collectInlineCodeRuns].
  const CodeTextSpan.revealing({
    required List<InlineSpan> super.children,
    required this.codeStyle,
    super.style,
    super.recognizer,
    super.mouseCursor,
    super.semanticsLabel,
  });

  /// The resolved style the chip behind this span is drawn with.
  final InlineCodeStyle codeStyle;
}

/// A resolved inline-code run: a range of the paragraph's plain text, and the
/// style its chip is drawn with.
@immutable
class InlineCodeRun {
  /// Creates an inline-code run.
  const InlineCodeRun({
    required this.start,
    required this.end,
    required this.style,
  });

  /// First code unit of the run, in the paragraph's plain text.
  final int start;

  /// One past the last code unit of the run.
  final int end;

  /// The resolved style for this run.
  final InlineCodeStyle style;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InlineCodeRun &&
          other.start == start &&
          other.end == end &&
          other.style == style;

  @override
  int get hashCode => Object.hash(start, end, style);
}

/// Every [CodeTextSpan] in [root], as plain-text ranges.
///
/// Offsets count a placeholder as the single U+FFFC code unit the engine lays
/// out, so they line up with [RenderParagraph.getBoxesForSelection].
List<InlineCodeRun> collectInlineCodeRuns(InlineSpan root) {
  final runs = <InlineCodeRun>[];
  var offset = 0;

  void visit(InlineSpan span) {
    if (span is TextSpan) {
      final start = offset;
      offset += span.text?.length ?? 0;
      final children = span.children;
      if (children != null) {
        for (final child in children) {
          visit(child);
        }
      }
      // Measured after the subtree, so a tagged span built over children —
      // [CodeTextSpan.revealing], the reveal's partially arrived form —
      // covers everything inside it, not just its own (absent) text.
      if (span is CodeTextSpan && offset > start) {
        runs.add(
          InlineCodeRun(start: start, end: offset, style: span.codeStyle),
        );
      }
    } else if (span is PlaceholderSpan) {
      offset += 1;
    } else {
      offset += span.toPlainText(includePlaceholders: true).length;
    }
  }

  visit(root);
  return runs;
}

/// Paints a rounded chip behind every inline-code run, once per line fragment.
///
/// Mix into any [RenderParagraph] subclass. Painting happens before
/// `super.paint`, so the chip sits under the glyphs.
mixin InlineCodeDecoration on RenderParagraph {
  List<InlineCodeRun> _inlineCodeRuns = const <InlineCodeRun>[];

  /// The runs to decorate.
  List<InlineCodeRun> get inlineCodeRuns => _inlineCodeRuns;

  set inlineCodeRuns(List<InlineCodeRun> value) {
    if (listEquals(_inlineCodeRuns, value)) {
      return;
    }
    _inlineCodeRuns = value;
    markNeedsPaint();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (_inlineCodeRuns.isNotEmpty) {
      _paintInlineCode(context.canvas, offset);
    }
    super.paint(context, offset);
  }

  void _paintInlineCode(Canvas canvas, Offset offset) {
    for (final run in _inlineCodeRuns) {
      final style = run.style;
      final boxes = getBoxesForSelection(
        TextSelection(baseOffset: run.start, extentOffset: run.end),
        boxHeightStyle: style.boxHeightStyle ?? ui.BoxHeightStyle.tight,
      );
      if (boxes.isEmpty) {
        continue;
      }

      final fragments = _mergeByLine(boxes);
      final padding = style.padding ?? EdgeInsets.zero;
      final radius = style.borderRadius ?? Radius.zero;
      final background = style.backgroundColor;
      final borderColor = style.borderColor;
      final borderWidth = style.borderWidth ?? 0;

      for (var i = 0; i < fragments.length; i++) {
        // Only the outer edges of a wrapped run are padded, so the two halves
        // of a chip broken over a line end read as one run rather than as two
        // separate chips.
        final isFirst = i == 0;
        final isLast = i == fragments.length - 1;
        final rect = Rect.fromLTRB(
          fragments[i].left - (isFirst ? padding.left : 0),
          fragments[i].top - padding.top,
          fragments[i].right + (isLast ? padding.right : 0),
          fragments[i].bottom + padding.bottom,
        ).shift(offset);

        final rrect = RRect.fromRectAndCorners(
          rect,
          topLeft: isFirst ? radius : Radius.zero,
          bottomLeft: isFirst ? radius : Radius.zero,
          topRight: isLast ? radius : Radius.zero,
          bottomRight: isLast ? radius : Radius.zero,
        );

        if (background != null && background.a > 0) {
          canvas.drawRRect(rrect, Paint()..color = background);
        }
        if (borderWidth > 0 && borderColor != null && borderColor.a > 0) {
          canvas.drawRRect(
            rrect.deflate(borderWidth / 2),
            Paint()
              ..color = borderColor
              ..style = PaintingStyle.stroke
              ..strokeWidth = borderWidth,
          );
        }
      }
    }
  }

  /// Collapses the per-style-run boxes the engine returns into one rect per
  /// line, so a chip is drawn once per line rather than once per run.
  static List<Rect> _mergeByLine(List<ui.TextBox> boxes) {
    final merged = <Rect>[];
    for (final box in boxes) {
      final rect = box.toRect();
      if (rect.isEmpty && rect.width == 0) {
        continue;
      }
      var joined = false;
      for (var i = 0; i < merged.length; i++) {
        // Same line when the vertical extents overlap; the engine emits boxes
        // in visual order, which for RTL runs is not left to right.
        if (rect.top < merged[i].bottom && rect.bottom > merged[i].top) {
          merged[i] = merged[i].expandToInclude(rect);
          joined = true;
          break;
        }
      }
      if (!joined) {
        merged.add(rect);
      }
    }
    return merged;
  }
}
