import 'markdown_text_scaling.dart';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// A custom widget that displays an unordered list of items.
///
/// The [UnorderedListView] widget is used to create a list of items with bullet points.
/// It takes a [child] parameter which is the content of the list item,
/// a [spacing] parameter to set the spacing between items,
/// a [padding] parameter to set the padding of the list item,
class UnorderedListView extends StatelessWidget {
  const UnorderedListView({
    super.key,
    this.spacing = 8,
    this.padding = 12,
    this.bulletColor,
    this.bulletSize = 4,
    this.bulletShape = BoxShape.circle,
    this.textDirection = TextDirection.ltr,
    this.scalesItsOwnText = false,
    required this.child,
  });

  /// Whether this item has to scale its own text.
  ///
  /// A list item inside a paragraph must not: the paragraph lays its inline
  /// children out in scaled space and multiplies the result back, so scaling
  /// here as well counts it twice. Rendered as a sibling widget there is no
  /// paragraph left to do it, and opting out silently pins the item at 1x
  /// while the prose around it grows.
  final bool scalesItsOwnText;

  /// The size of the bullet point.
  final double bulletSize;

  /// Whether the bullet is a dot or a square.
  final BoxShape bulletShape;

  /// The spacing between items.
  final double spacing;

  /// The padding of the list item.
  final double padding;
  final TextDirection textDirection;

  /// The color of the bullet point.
  final Color? bulletColor;

  /// The child widget to be displayed in the list item.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // Rendered inside a `WidgetSpan`, and a paragraph lays inline children
    // out in scaled space: it hands them `maxWidth / scale` and multiplies
    // the reported size back. A child that also scales its own text is
    // counted twice. The markers here build their own `Text`, so they opt
    // out — the contract `config.getRich` already follows for nested
    // paragraphs.
    final Widget body = Directionality(
      textDirection: textDirection,
      child: _HangingItem(
        leading: padding,
        trailing: spacing,
        textDirection: textDirection,
        dotSize: bulletSize,
        dotColor: bulletColor,
        dotShape: bulletShape,
        child: child,
      ),
    );
    return MarkdownTextScaling.wrap(body, enabled: scalesItsOwnText);
  }
}

/// A custom widget that displays an ordered list of items.
///
/// The [OrderedListView] widget is used to create a list of items with numbered points.
/// It takes a [child] parameter which is the content of the list item,
/// a [spacing] parameter to set the spacing between items,
/// a [padding] parameter to set the padding of the list item,
class OrderedListView extends StatelessWidget {
  final String no;
  final double spacing;
  final double padding;
  const OrderedListView({
    super.key,
    this.spacing = 6,
    this.padding = 6,
    TextStyle? style,
    required this.child,
    this.textDirection = TextDirection.ltr,
    this.scalesItsOwnText = false,
    required this.no,
  }) : _style = style;

  /// Whether this item has to scale its own text. See
  /// [UnorderedListView.scalesItsOwnText].
  final bool scalesItsOwnText;

  /// The style of the text.
  final TextStyle? _style;

  /// The direction of the text.
  final TextDirection textDirection;

  /// The child widget to be displayed in the list item.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // Rendered inside a `WidgetSpan`, and a paragraph lays inline children
    // out in scaled space: it hands them `maxWidth / scale` and multiplies
    // the reported size back. A child that also scales its own text is
    // counted twice. The markers here build their own `Text`, so they opt
    // out — the contract `config.getRich` already follows for nested
    // paragraphs.
    final base = DefaultTextStyle.of(context).style;
    final Widget body = Directionality(
      textDirection: textDirection,
      child: _HangingItem(
        leading: padding,
        trailing: spacing,
        textDirection: textDirection,
        markerSpan: TextSpan(
          text: no,
          style: _style == null ? base : base.merge(_style),
        ),
        child: child,
      ),
    );
    return MarkdownTextScaling.wrap(body, enabled: scalesItsOwnText);
  }
}

/// The marker used to be drawn by a whole `Text.rich` holding a `WidgetSpan` —
/// an entire `RenderParagraph`, laid out per list item, to paint one dot. It
/// was there for its baseline: a `Row` aligning on baselines needs one from
/// the marker, and a coloured box has none.
///
/// That paragraph's geometry never depended on the item. It carries no text
/// and no style override, so it was laid out in the *ambient* default style
/// whatever size the list was set in — which is why the dot sat a flat 3.52
/// logical pixels above the baseline at 14pt and at 44pt alike. So this is one
/// measurement for the whole document rather than one per item.
class _BulletMetrics {
  const _BulletMetrics(this.baseline, this.lineHeight);

  /// Distance from the top of the marker box to the text baseline.
  final double baseline;

  /// The line box the old marker paragraph occupied.
  ///
  /// Reproduced so the row keeps its height. The marker used to be a paragraph
  /// and therefore reserved a full line; a bare dot reserves only its own
  /// diameter, which quietly tightened every list by a pixel or so per row.
  final double lineHeight;

  static final Map<(TextStyle, TextScaler), _BulletMetrics> _cache =
      <(TextStyle, TextScaler), _BulletMetrics>{};

  /// Cache metrics by style and scaler, shared by items in the document.
  static _BulletMetrics of(TextStyle style, TextScaler scaler) {
    final key = (style, scaler);
    final cached = _cache[key];
    if (cached != null) {
      return cached;
    }
    final painter = TextPainter(
      text: TextSpan(text: 'x', style: style),
      textScaler: scaler,
      textDirection: TextDirection.ltr,
    )..layout();
    final ascent = painter.computeDistanceToActualBaseline(
      TextBaseline.alphabetic,
    );
    final lineHeight = painter.height;
    painter.dispose();
    final metrics = _BulletMetrics(ascent, lineHeight);
    if (_cache.length >= 128) _cache.clear();
    _cache[key] = metrics;
    return metrics;
  }
}

/// A list item drawn as a hanging indent: the marker sits in the gutter and
/// the content wraps against a straight left edge.
///
/// This replaces a `Row` of a padded marker box and a `Flexible` child. That
/// shape needed seven render objects per item to draw one dot — a baseline
/// reporter, two sized boxes, a padding, a centre and a decoration — and a
/// streaming reply pays for every one of them on every chunk, because paint
/// walks the whole document even where a viewport clips it. Measured over 200
/// items the row shape cost 2.64 ms per rebuild against 1.66 ms for this,
/// which is within noise of a bare paragraph with no marker at all.
///
/// The layout it reproduces is `CrossAxisAlignment.baseline`: marker and
/// first line of content share a baseline, and the item is as tall as the
/// taller of the two around it.
class _HangingItem extends SingleChildRenderObjectWidget {
  const _HangingItem({
    required this.leading,
    required this.trailing,
    required this.textDirection,
    this.dotSize = 0,
    this.dotColor,
    this.dotShape = BoxShape.circle,
    this.markerSpan,
    required Widget child,
  }) : super(child: child);

  /// Space before the marker.
  final double leading;

  /// Space between the marker and the content.
  final double trailing;

  final TextDirection textDirection;

  /// Diameter of the dot, for an unordered item. Zero draws no marker and
  /// keeps only the indent.
  final double dotSize;

  final Color? dotColor;

  /// Whether the dot is drawn round or square.
  final BoxShape dotShape;

  /// The marker as text, for an ordered item. Wins over [dotSize].
  final InlineSpan? markerSpan;

  double _scaledDot(BuildContext context) {
    final size = DefaultTextStyle.of(context).style.fontSize ?? 14;
    if (size <= 0) return dotSize;
    return dotSize * MediaQuery.textScalerOf(context).scale(size) / size;
  }

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderHangingItem(
    leading: leading,
    trailing: trailing,
    textDirection: textDirection,
    metrics: _BulletMetrics.of(
      DefaultTextStyle.of(context).style,
      MediaQuery.textScalerOf(context),
    ),
    textScaler: MediaQuery.textScalerOf(context),
    dotSize: _scaledDot(context),
    dotColor: dotColor,
    dotShape: dotShape,
    markerSpan: markerSpan,
  );

  @override
  void updateRenderObject(BuildContext context, _RenderHangingItem render) {
    render
      ..leading = leading
      ..trailing = trailing
      ..textDirection = textDirection
      ..metrics = _BulletMetrics.of(
        DefaultTextStyle.of(context).style,
        MediaQuery.textScalerOf(context),
      )
      ..textScaler = MediaQuery.textScalerOf(context)
      ..dotSize = _scaledDot(context)
      ..dotColor = dotColor
      ..dotShape = dotShape
      ..markerSpan = markerSpan;
  }
}

class _RenderHangingItem extends RenderShiftedBox {
  _RenderHangingItem({
    required double leading,
    required double trailing,
    required TextDirection textDirection,
    required _BulletMetrics metrics,
    required TextScaler textScaler,
    required double dotSize,
    required Color? dotColor,
    required BoxShape dotShape,
    required InlineSpan? markerSpan,
  }) : _leading = leading,
       _trailing = trailing,
       _textDirection = textDirection,
       _metrics = metrics,
       _textScaler = textScaler,
       _dotSize = dotSize,
       _dotColor = dotColor,
       _dotShape = dotShape,
       _markerSpan = markerSpan,
       super(null);

  double _leading;
  set leading(double value) {
    if (_leading == value) {
      return;
    }
    _leading = value;
    markNeedsLayout();
  }

  double _trailing;
  set trailing(double value) {
    if (_trailing == value) {
      return;
    }
    _trailing = value;
    markNeedsLayout();
  }

  TextDirection _textDirection;
  set textDirection(TextDirection value) {
    if (_textDirection == value) {
      return;
    }
    _textDirection = value;
    _painter?.dispose();
    _painter = null;
    markNeedsLayout();
  }

  _BulletMetrics _metrics;
  set metrics(_BulletMetrics value) {
    if (_metrics == value) {
      return;
    }
    _metrics = value;
    markNeedsLayout();
  }

  double _dotSize;
  set dotSize(double value) {
    if (_dotSize == value) {
      return;
    }
    _dotSize = value;
    markNeedsLayout();
  }

  Color? _dotColor;
  set dotColor(Color? value) {
    if (_dotColor == value) {
      return;
    }
    _dotColor = value;
    markNeedsPaint();
  }

  /// Circle or square. Geometry is identical either way — the square is
  /// inscribed in the same box the dot occupies — so only paint is dirtied.
  BoxShape _dotShape;
  set dotShape(BoxShape value) {
    if (_dotShape == value) {
      return;
    }
    _dotShape = value;
    markNeedsPaint();
  }

  InlineSpan? _markerSpan;
  set markerSpan(InlineSpan? value) {
    if (_markerSpan == value) {
      return;
    }
    _markerSpan = value;
    _painter?.dispose();
    _painter = null;
    markNeedsLayout();
  }

  TextScaler _textScaler;
  set textScaler(TextScaler value) {
    if (_textScaler == value) return;
    _textScaler = value;
    _painter?.dispose();
    _painter = null;
    markNeedsLayout();
  }

  TextPainter? _painter;

  /// The laid-out marker text, or null for a dot or a bare indent.
  TextPainter? get _marker {
    final span = _markerSpan;
    if (span == null) {
      return null;
    }
    return _painter ??= TextPainter(
      text: span,
      textDirection: _textDirection,
      textScaler: _textScaler,
    )..layout();
  }

  /// Where the content starts, measured from the item's leading edge.
  double get _indent {
    final marker = _marker;
    final width = marker?.width ?? _dotSize;
    return _leading + width + _trailing;
  }

  /// Distance from the top of the marker to its baseline, and the height it
  /// reserves. A dot has neither of its own, so it borrows the line box the
  /// surrounding text would have occupied — otherwise a list of one-line
  /// items sits tighter than the prose around it.
  (double, double) get _markerExtent {
    final marker = _marker;
    if (marker != null) {
      return (
        marker.computeDistanceToActualBaseline(TextBaseline.alphabetic),
        marker.height,
      );
    }
    return (_metrics.baseline, math.max(_metrics.lineHeight, _dotSize));
  }

  @override
  void dispose() {
    _painter?.dispose();
    _painter = null;
    super.dispose();
  }

  @override
  void performLayout() {
    final child = this.child;
    if (child == null) {
      size = constraints.smallest;
      return;
    }
    final indent = _indent;
    child.layout(
      constraints.deflate(EdgeInsets.only(left: indent)),
      parentUsesSize: true,
    );
    final childBaseline =
        child.getDistanceToBaseline(TextBaseline.alphabetic, onlyReal: true) ??
        child.size.height;
    final (markerBaseline, markerHeight) = _markerExtent;

    // The baseline algorithm a `Row` with `CrossAxisAlignment.baseline` runs:
    // both boxes hang from the lowest shared baseline, and the item is as
    // tall as whichever descends furthest below it.
    final baseline = math.max(markerBaseline, childBaseline);
    final height = math.max(
      baseline + (child.size.height - childBaseline),
      baseline + (markerHeight - markerBaseline),
    );
    _baseline = baseline;
    _markerTop = baseline - markerBaseline;
    _markerHeight = markerHeight;

    size = constraints.constrain(Size(indent + child.size.width, height));
    final ltr = _textDirection == TextDirection.ltr;
    (child.parentData! as BoxParentData).offset = Offset(
      ltr ? indent : 0,
      baseline - childBaseline,
    );
  }

  double _baseline = 0;
  double _markerTop = 0;
  double _markerHeight = 0;

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) => _baseline;

  @override
  void paint(PaintingContext context, Offset offset) {
    super.paint(context, offset);
    final ltr = _textDirection == TextDirection.ltr;
    final marker = _marker;
    if (marker != null) {
      final width = marker.width;
      final dx = ltr ? _leading : size.width - _leading - width;
      marker.paint(context.canvas, offset + Offset(dx, _markerTop));
      return;
    }
    if (_dotSize <= 0) {
      return;
    }
    final radius = _dotSize / 2;
    final dx = ltr ? _leading + radius : size.width - _leading - radius;
    final centre = offset + Offset(dx, _markerTop + _markerHeight / 2);
    final paint = Paint()..color = _dotColor ?? const Color(0xFF000000);
    if (_dotShape == BoxShape.rectangle) {
      context.canvas.drawRect(
        Rect.fromCenter(center: centre, width: _dotSize, height: _dotSize),
        paint,
      );
      return;
    }
    context.canvas.drawCircle(centre, radius, paint);
  }
}
