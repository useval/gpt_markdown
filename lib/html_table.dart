part of 'gpt_markdown.dart';

// ---------------------------------------------------------------------------
// HTML tables
// ---------------------------------------------------------------------------
//
// A Markdown pipe table is a plain grid: every row has a header row above it
// and one cell per column, which is exactly what Flutter's [Table] draws. An
// HTML table is not: cells span columns (`colspan`) and rows (`rowspan`), a
// table may have no header at all or several header rows, and `<tfoot>` goes
// last wherever it is written. [Table] cannot merge cells, so HTML tables are
// placed on a grid here ([_HtmlTableGrid]) and drawn by a render object of
// their own ([_RenderHtmlTable]) that sizes columns the way [RenderTable]
// does — the same [TableColumnWidth], the same [TableStyle] — and lets a cell
// cover more than one slot.

/// A cell placed on the grid.
class _HtmlGridCell {
  _HtmlGridCell({
    required this.data,
    required this.row,
    required this.column,
    required this.rowSpan,
    required this.columnSpan,
    required this.header,
    required this.align,
  });

  final HtmlElementData data;
  final int row;
  final int column;
  final int rowSpan;
  final int columnSpan;

  /// A `<th>`, or any cell of a row in `<thead>`.
  final bool header;

  final MdAlign align;
}

/// Largest `colspan` or `rowspan` honoured, so a stray `colspan="100000"`
/// cannot make a grid of a hundred thousand slots.
const int _maxHtmlSpan = 100;

/// An HTML table's cells placed on a grid, as a browser places them.
class _HtmlTableGrid {
  _HtmlTableGrid._(
    this.caption,
    this.cells,
    this.rowCount,
    this.columnCount,
    this.headerRows,
  );

  /// Places the cells of the `<table>` element [table].
  ///
  /// Rows in `<thead>` come first and rows in `<tfoot>` last; everything else
  /// keeps its order. Each cell takes the first column of its row that no
  /// cell above still covers, and covers `colspan` columns and `rowspan` rows
  /// — `rowspan="0"`, and any span past the end, to the end of its section.
  factory _HtmlTableGrid.of(HtmlElementData table) {
    HtmlElementData? caption;
    final head = <List<HtmlElementData>>[];
    final body = <List<HtmlElementData>>[];
    final foot = <List<HtmlElementData>>[];
    List<HtmlElementData>? loose;
    for (final node in table.children) {
      if (node case MdCustomBlock(:final HtmlElementData data)) {
        if (data.name != 'tr') {
          loose = null;
        }
        switch (data.name) {
          case 'caption':
            caption ??= data;
          case 'thead' || 'tbody' || 'tfoot':
            final rows = [
              for (final row in data.children)
                if (row case MdCustomBlock(:final HtmlElementData data)) data,
            ];
            (data.name == 'thead'
                    ? head
                    : data.name == 'tfoot'
                    ? foot
                    : body)
                .add(rows);
          case 'tr':
            if (loose == null) {
              body.add(loose = []);
            }
            loose.add(data);
        }
      }
    }

    final cells = <_HtmlGridCell>[];
    final headerRows = <bool>[];
    final covered = <List<bool>>[];
    var columns = 0;
    var r = 0;
    for (final (sections, inHead) in [
      (head, true),
      (body, false),
      (foot, false),
    ]) {
      for (final rows in sections) {
        final sectionEnd = r + rows.length;
        for (final row in rows) {
          final rowAlign = htmlAlign(row.attributes);
          final rowCells = [
            for (final cell in row.children)
              if (cell case MdCustomBlock(:final HtmlElementData data)) data,
          ];
          headerRows.add(inHead || rowCells.every((cell) => cell.name == 'th'));
          while (covered.length <= r) {
            covered.add(<bool>[]);
          }
          var c = 0;
          for (final cell in rowCells) {
            final line = covered[r];
            while (c < line.length && line[c]) {
              c += 1;
            }
            final columnSpan =
                (int.tryParse(cell.attributes['colspan'] ?? '') ?? 1).clamp(
                  1,
                  _maxHtmlSpan,
                );
            var rowSpan = int.tryParse(cell.attributes['rowspan'] ?? '') ?? 1;
            if (rowSpan <= 0 || r + rowSpan > sectionEnd) {
              rowSpan = sectionEnd - r;
            }
            rowSpan = rowSpan.clamp(1, _maxHtmlSpan);
            for (var y = r; y < r + rowSpan; y++) {
              while (covered.length <= y) {
                covered.add(<bool>[]);
              }
              final slots = covered[y];
              while (slots.length < c + columnSpan) {
                slots.add(false);
              }
              for (var x = c; x < c + columnSpan; x++) {
                slots[x] = true;
              }
            }
            final align = htmlAlign(cell.attributes);
            cells.add(
              _HtmlGridCell(
                data: cell,
                row: r,
                column: c,
                rowSpan: rowSpan,
                columnSpan: columnSpan,
                header: inHead || cell.name == 'th',
                align: align == MdAlign.none ? rowAlign : align,
              ),
            );
            c += columnSpan;
            if (c > columns) {
              columns = c;
            }
          }
          r += 1;
        }
      }
    }
    return _HtmlTableGrid._(caption, cells, r, columns, headerRows);
  }

  final HtmlElementData? caption;
  final List<_HtmlGridCell> cells;
  final int rowCount;
  final int columnCount;

  /// Per row: whether it is a header row — in `<thead>`, or all `<th>`.
  final List<bool> headerRows;
}

/// The `<table>` element [data] as a grid.
List<InlineSpan> _htmlTableSpans(
  BuildContext context,
  HtmlElementData data,
  GptMarkdownConfig config,
) {
  final grid = _HtmlTableGrid.of(data);
  final caption = grid.caption;
  Widget? captionWidget;
  if (caption != null && caption.children.isNotEmpty) {
    captionWidget = Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: config.getRich(
        ambientScaling: config.blocksRenderDirectly,
        TextSpan(
          children: PlusparseRenderer._inlineSpans(
            context,
            caption.children,
            config,
          ),
        ),
      ),
    );
  }
  if (grid.cells.isEmpty) {
    return [
      if (captionWidget != null) PlusparseRenderer._blockSpan(captionWidget),
    ];
  }

  final Widget table;
  final tableBuilder = config.tableBuilder;
  if (tableBuilder != null) {
    // The builder takes one field per column, so a spanning cell gives its
    // text to its first slot and leaves the others empty.
    final fields = List.generate(
      grid.rowCount,
      (_) => List.generate(
        grid.columnCount,
        (_) => CustomTableField(data: '', alignment: TextAlign.left),
      ),
    );
    for (final cell in grid.cells) {
      fields[cell.row][cell.column] = CustomTableField(
        data: PlusparseRenderer._plainText(cell.data.children),
        alignment: _textAlignOf(cell.align),
      );
    }
    table = tableBuilder(
      context,
      [
        for (var r = 0; r < grid.rowCount; r++)
          CustomTableRow(isHeader: grid.headerRows[r], fields: fields[r]),
      ],
      config.style ?? const TextStyle(),
      config,
    );
  } else {
    final scheme = Theme.of(context).colorScheme;
    final tableStyle =
        (resolvedStyleSheet(context, config).table ?? const TableStyle())
            .resolve(scheme);
    // As in a pipe table: a left-aligned cell's text fills its slot, so only
    // a caller who set a `textAlign` needs it overridden there.
    final ambientAlign = config.textAlign;
    final leftConfig =
        (ambientAlign == null ||
            ambientAlign == TextAlign.left ||
            ambientAlign == TextAlign.start)
        ? config
        : config.copyWith(textAlign: TextAlign.left);
    final padding =
        tableStyle.cellPadding ??
        const EdgeInsets.symmetric(horizontal: 8, vertical: 4);
    final headerStyle = tableStyle.headerTextStyle;

    Widget cellWidget(_HtmlGridCell cell) {
      if (cell.data.children.isEmpty) {
        return const SizedBox();
      }
      final align = _textAlignOf(cell.align);
      final cellConfig = align == TextAlign.left ? leftConfig : config;
      Widget content = Padding(
        padding: padding,
        child: cellConfig.getRich(
          ambientScaling: config.blocksRenderDirectly,
          TextSpan(
            children: PlusparseRenderer._inlineSpans(
              context,
              cell.data.children,
              cellConfig,
            ),
          ),
        ),
      );
      if (cell.header && headerStyle != null) {
        content = DefaultTextStyle.merge(style: headerStyle, child: content);
      }
      return switch (align) {
        TextAlign.center => Center(child: content),
        TextAlign.right => Align(
          alignment: Alignment.centerRight,
          child: content,
        ),
        _ => content,
      };
    }

    final radius = tableStyle.borderRadius;
    table = _TableViewport(
      overflow: tableStyle.overflow ?? TableOverflow.scroll,
      child: _HtmlTableLayout(
        rowCount: grid.rowCount,
        columnCount: grid.columnCount,
        headerRows: grid.headerRows,
        columnWidth:
            tableStyle.columnWidth ??
            _defaultTableColumnWidth(tableStyle.overflow, grid.columnCount),
        textDirection: config.textDirection,
        borderColor: tableStyle.borderColor ?? scheme.onSurface,
        borderWidth: tableStyle.borderWidth ?? 1,
        borderRadius: radius == null
            ? BorderRadius.zero
            : BorderRadius.all(radius),
        headerBackground:
            tableStyle.headerBackground ?? scheme.surfaceContainerHighest,
        stripeColor: tableStyle.rowStripeColor,
        children: [
          for (final cell in grid.cells)
            _HtmlTableSlot(
              row: cell.row,
              column: cell.column,
              rowSpan: cell.rowSpan,
              columnSpan: cell.columnSpan,
              header: cell.header,
              child: cellWidget(cell),
            ),
        ],
      ),
    );
  }

  return [
    PlusparseRenderer._blockSpan(
      captionWidget == null
          ? table
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [captionWidget, table],
            ),
    ),
  ];
}

TextAlign _textAlignOf(MdAlign align) => switch (align) {
  MdAlign.center => TextAlign.center,
  MdAlign.right => TextAlign.right,
  _ => TextAlign.left,
};

/// Where a cell sits on an HTML table's grid.
class _HtmlTableParentData extends ContainerBoxParentData<RenderBox> {
  int row = 0;
  int column = 0;
  int rowSpan = 1;
  int columnSpan = 1;
  bool header = false;
}

/// Places [child] on the grid of the enclosing [_HtmlTableLayout].
class _HtmlTableSlot extends ParentDataWidget<_HtmlTableParentData> {
  const _HtmlTableSlot({
    required this.row,
    required this.column,
    required this.rowSpan,
    required this.columnSpan,
    required this.header,
    required super.child,
  });

  final int row;
  final int column;
  final int rowSpan;
  final int columnSpan;
  final bool header;

  @override
  void applyParentData(RenderObject renderObject) {
    final data = renderObject.parentData! as _HtmlTableParentData;
    if (data.row == row &&
        data.column == column &&
        data.rowSpan == rowSpan &&
        data.columnSpan == columnSpan &&
        data.header == header) {
      return;
    }
    data
      ..row = row
      ..column = column
      ..rowSpan = rowSpan
      ..columnSpan = columnSpan
      ..header = header;
    renderObject.parent?.markNeedsLayout();
  }

  @override
  Type get debugTypicalAncestorWidgetClass => _HtmlTableLayout;
}

/// A grid of [_HtmlTableSlot] children, each covering one or more slots.
class _HtmlTableLayout extends MultiChildRenderObjectWidget {
  const _HtmlTableLayout({
    required this.rowCount,
    required this.columnCount,
    required this.headerRows,
    required this.columnWidth,
    required this.textDirection,
    required this.borderColor,
    required this.borderWidth,
    required this.borderRadius,
    required this.headerBackground,
    required this.stripeColor,
    required super.children,
  });

  final int rowCount;
  final int columnCount;
  final List<bool> headerRows;
  final TableColumnWidth columnWidth;
  final TextDirection? textDirection;
  final Color borderColor;
  final double borderWidth;
  final BorderRadius borderRadius;
  final Color headerBackground;
  final Color? stripeColor;

  @override
  _RenderHtmlTable createRenderObject(BuildContext context) => _RenderHtmlTable(
    rowCount: rowCount,
    columnCount: columnCount,
    headerRows: headerRows,
    columnWidth: columnWidth,
    textDirection: textDirection ?? Directionality.of(context),
    borderColor: borderColor,
    borderWidth: borderWidth,
    borderRadius: borderRadius,
    headerBackground: headerBackground,
    stripeColor: stripeColor,
  );

  @override
  void updateRenderObject(BuildContext context, _RenderHtmlTable renderObject) {
    renderObject
      ..rowCount = rowCount
      ..columnCount = columnCount
      ..headerRows = headerRows
      ..columnWidth = columnWidth
      ..textDirection = textDirection ?? Directionality.of(context)
      ..borderColor = borderColor
      ..borderWidth = borderWidth
      ..borderRadius = borderRadius
      ..headerBackground = headerBackground
      ..stripeColor = stripeColor;
  }
}

/// Lays out an HTML table's cells on a grid.
///
/// Columns are sized as [RenderTable] sizes them, from the same
/// [TableColumnWidth]: its ideal and minimum widths per column, from the
/// cells that sit in that column alone, then grown to the minimum width and
/// shrunk to the maximum one. A cell spanning columns that are together
/// narrower than it wants shares the difference out between them. Rows are
/// as tall as their tallest single-row cell, and a cell spanning rows that
/// are together shorter than it shares that difference out the same way.
/// Cells sit in the middle of their area, and the grid lines go round each
/// cell's area rather than through it.
class _RenderHtmlTable extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _HtmlTableParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _HtmlTableParentData> {
  _RenderHtmlTable({
    required this._rowCount,
    required this._columnCount,
    required this._headerRows,
    required this._columnWidth,
    required this._textDirection,
    required this._borderColor,
    required this._borderWidth,
    required this._borderRadius,
    required this._headerBackground,
    required this._stripeColor,
  });

  int get rowCount => _rowCount;
  int _rowCount;
  set rowCount(int value) {
    if (value == _rowCount) return;
    _rowCount = value;
    markNeedsLayout();
  }

  int get columnCount => _columnCount;
  int _columnCount;
  set columnCount(int value) {
    if (value == _columnCount) return;
    _columnCount = value;
    markNeedsLayout();
  }

  List<bool> get headerRows => _headerRows;
  List<bool> _headerRows;
  set headerRows(List<bool> value) {
    if (listEquals(value, _headerRows)) return;
    _headerRows = value;
    markNeedsPaint();
  }

  TableColumnWidth get columnWidth => _columnWidth;
  TableColumnWidth _columnWidth;
  set columnWidth(TableColumnWidth value) {
    if (value == _columnWidth) return;
    _columnWidth = value;
    markNeedsLayout();
  }

  TextDirection get textDirection => _textDirection;
  TextDirection _textDirection;
  set textDirection(TextDirection value) {
    if (value == _textDirection) return;
    _textDirection = value;
    markNeedsLayout();
  }

  Color get borderColor => _borderColor;
  Color _borderColor;
  set borderColor(Color value) {
    if (value == _borderColor) return;
    _borderColor = value;
    markNeedsPaint();
  }

  double get borderWidth => _borderWidth;
  double _borderWidth;
  set borderWidth(double value) {
    if (value == _borderWidth) return;
    _borderWidth = value;
    markNeedsPaint();
  }

  BorderRadius get borderRadius => _borderRadius;
  BorderRadius _borderRadius;
  set borderRadius(BorderRadius value) {
    if (value == _borderRadius) return;
    _borderRadius = value;
    markNeedsPaint();
  }

  Color get headerBackground => _headerBackground;
  Color _headerBackground;
  set headerBackground(Color value) {
    if (value == _headerBackground) return;
    _headerBackground = value;
    markNeedsPaint();
  }

  Color? get stripeColor => _stripeColor;
  Color? _stripeColor;
  set stripeColor(Color? value) {
    if (value == _stripeColor) return;
    _stripeColor = value;
    markNeedsPaint();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _HtmlTableParentData) {
      child.parentData = _HtmlTableParentData();
    }
  }

  // Geometry from the last layout, for paint.
  List<double> _columnLefts = const [];
  List<double> _columnWidths = const [];
  List<double> _rowTops = const [];

  /// Per slot, the index of the child covering it, or -1.
  List<List<int>> _owners = const [];

  static _HtmlTableParentData _slot(RenderBox child) =>
      child.parentData! as _HtmlTableParentData;

  /// Each column's ideal and minimum width and flex for [containerWidth],
  /// spanning cells included.
  ({List<double> widths, List<double> mins, List<double?> flexes})
  _columnIntrinsics(double containerWidth) {
    final columns = _columnCount;
    final alone = List.generate(columns, (_) => <RenderBox>[]);
    final spanning = <RenderBox>[];
    var child = firstChild;
    while (child != null) {
      final slot = _slot(child);
      if (slot.column < columns) {
        if (slot.columnSpan == 1) {
          alone[slot.column].add(child);
        } else {
          spanning.add(child);
        }
      }
      child = childAfter(child);
    }
    final widths = List<double>.filled(columns, 0);
    final mins = List<double>.filled(columns, 0);
    final flexes = List<double?>.filled(columns, null);
    for (var x = 0; x < columns; x++) {
      widths[x] = _columnWidth.maxIntrinsicWidth(alone[x], containerWidth);
      mins[x] = _columnWidth.minIntrinsicWidth(alone[x], containerWidth);
      flexes[x] = _columnWidth.flex(alone[x]);
    }
    // Narrow spans first, so a wide span sees what the narrow ones added.
    spanning.sort((a, b) => _slot(a).columnSpan.compareTo(_slot(b).columnSpan));
    for (final cell in spanning) {
      final slot = _slot(cell);
      final end = min(slot.column + slot.columnSpan, columns);
      void share(List<double> sizes, double wanted) {
        var have = 0.0;
        for (var x = slot.column; x < end; x++) {
          have += sizes[x];
        }
        if (wanted > have) {
          final extra = (wanted - have) / (end - slot.column);
          for (var x = slot.column; x < end; x++) {
            sizes[x] += extra;
          }
        }
      }

      share(widths, _columnWidth.maxIntrinsicWidth([cell], containerWidth));
      share(mins, _columnWidth.minIntrinsicWidth([cell], containerWidth));
    }
    for (var x = 0; x < columns; x++) {
      if (widths[x] < mins[x]) {
        widths[x] = mins[x];
      }
    }
    return (widths: widths, mins: mins, flexes: flexes);
  }

  /// The column widths for [constraints] — [RenderTable]'s algorithm, from
  /// [_columnIntrinsics].
  List<double> _computeColumnWidths(BoxConstraints constraints) {
    final columns = _columnCount;
    final (:widths, mins: minWidths, :flexes) = _columnIntrinsics(
      constraints.maxWidth,
    );
    var tableWidth = 0.0;
    var unflexedTableWidth = 0.0;
    var totalFlex = 0.0;
    for (var x = 0; x < columns; x++) {
      tableWidth += widths[x];
      final flex = flexes[x];
      if (flex != null) {
        totalFlex += flex;
      } else {
        unflexedTableWidth += widths[x];
      }
    }
    final maxWidthConstraint = constraints.maxWidth;
    final minWidthConstraint = constraints.minWidth;

    // Grow the flex columns to the maximum width, or the minimum one when the
    // maximum is unbounded.
    if (totalFlex > 0) {
      final targetWidth = maxWidthConstraint.isFinite
          ? maxWidthConstraint
          : minWidthConstraint;
      if (tableWidth < targetWidth) {
        final remainingWidth = max(0.0, targetWidth - unflexedTableWidth);
        for (var x = 0; x < columns; x++) {
          final flex = flexes[x];
          if (flex != null) {
            final flexedWidth = remainingWidth * flex / totalFlex;
            if (widths[x] < flexedWidth) {
              tableWidth += flexedWidth - widths[x];
              widths[x] = flexedWidth;
            }
          }
        }
      }
    } else if (tableWidth < minWidthConstraint) {
      // No flex columns: grow every column to the minimum width.
      final delta = (minWidthConstraint - tableWidth) / columns;
      for (var x = 0; x < columns; x++) {
        widths[x] += delta;
      }
      tableWidth = minWidthConstraint;
    }

    // Shrink to the maximum width: flex columns first, in proportion, then
    // every column equally, none below its minimum.
    if (tableWidth > maxWidthConstraint) {
      var deficit = tableWidth - maxWidthConstraint;
      var availableColumns = columns;
      while (deficit > precisionErrorTolerance &&
          totalFlex > precisionErrorTolerance) {
        var newTotalFlex = 0.0;
        for (var x = 0; x < columns; x++) {
          final flex = flexes[x];
          if (flex != null) {
            final newWidth = widths[x] - deficit * flex / totalFlex;
            if (newWidth <= minWidths[x]) {
              deficit -= widths[x] - minWidths[x];
              widths[x] = minWidths[x];
              flexes[x] = null;
              availableColumns -= 1;
            } else {
              deficit -= widths[x] - newWidth;
              widths[x] = newWidth;
              newTotalFlex += flex;
            }
          }
        }
        totalFlex = newTotalFlex;
      }
      while (deficit > precisionErrorTolerance && availableColumns > 0) {
        final delta = deficit / availableColumns;
        var newAvailableColumns = 0;
        for (var x = 0; x < columns; x++) {
          final availableDelta = widths[x] - minWidths[x];
          if (availableDelta > 0) {
            if (availableDelta <= delta) {
              deficit -= availableDelta;
              widths[x] = minWidths[x];
            } else {
              deficit -= delta;
              widths[x] -= delta;
              newAvailableColumns += 1;
            }
          }
        }
        availableColumns = newAvailableColumns;
      }
    }
    return widths;
  }

  /// The width of the area [slot] covers.
  double _spanWidth(_HtmlTableParentData slot, List<double> widths) {
    var width = 0.0;
    final end = min(slot.column + slot.columnSpan, widths.length);
    for (var x = slot.column; x < end; x++) {
      width += widths[x];
    }
    return width;
  }

  /// Row heights, from each child's height at its area's width.
  List<double> _rowHeights(
    List<double> widths,
    double Function(RenderBox child, double width) heightOf,
  ) {
    final heights = List<double>.filled(_rowCount, 0);
    final spanning = <(RenderBox, double)>[];
    var child = firstChild;
    while (child != null) {
      final slot = _slot(child);
      if (slot.row < _rowCount && slot.column < _columnCount) {
        final height = heightOf(child, _spanWidth(slot, widths));
        if (slot.rowSpan == 1) {
          heights[slot.row] = max(heights[slot.row], height);
        } else {
          spanning.add((child, height));
        }
      }
      child = childAfter(child);
    }
    spanning.sort((a, b) => _slot(a.$1).rowSpan.compareTo(_slot(b.$1).rowSpan));
    for (final (cell, height) in spanning) {
      final slot = _slot(cell);
      final end = min(slot.row + slot.rowSpan, _rowCount);
      var have = 0.0;
      for (var y = slot.row; y < end; y++) {
        have += heights[y];
      }
      if (height > have) {
        final extra = (height - have) / (end - slot.row);
        for (var y = slot.row; y < end; y++) {
          heights[y] += extra;
        }
      }
    }
    return heights;
  }

  bool get _isEmpty => _rowCount == 0 || _columnCount == 0;

  @override
  double computeMinIntrinsicWidth(double height) {
    if (_isEmpty) return 0;
    return _columnIntrinsics(double.infinity).mins.fold(0.0, (a, b) => a + b);
  }

  @override
  double computeMaxIntrinsicWidth(double height) {
    if (_isEmpty) return 0;
    return _columnIntrinsics(double.infinity).widths.fold(0.0, (a, b) => a + b);
  }

  @override
  double computeMinIntrinsicHeight(double width) {
    if (_isEmpty) return 0;
    final widths = _computeColumnWidths(
      BoxConstraints.tightForFinite(width: width),
    );
    return _rowHeights(
      widths,
      (child, width) => child.getMaxIntrinsicHeight(width),
    ).fold(0.0, (a, b) => a + b);
  }

  @override
  double computeMaxIntrinsicHeight(double width) =>
      computeMinIntrinsicHeight(width);

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) => null;

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) {
    if (_isEmpty) return constraints.constrain(Size.zero);
    final widths = _computeColumnWidths(constraints);
    final heights = _rowHeights(
      widths,
      (child, width) =>
          child.getDryLayout(BoxConstraints.tightFor(width: width)).height,
    );
    return constraints.constrain(
      Size(
        widths.fold(0.0, (a, b) => a + b),
        heights.fold(0.0, (a, b) => a + b),
      ),
    );
  }

  @override
  void performLayout() {
    if (_isEmpty) {
      _columnLefts = _columnWidths = _rowTops = const [];
      _owners = const [];
      var child = firstChild;
      while (child != null) {
        child.layout(BoxConstraints.tight(Size.zero));
        child = childAfter(child);
      }
      size = constraints.constrain(Size.zero);
      return;
    }
    final columns = _columnCount;
    final widths = _computeColumnWidths(constraints);
    final lefts = List<double>.filled(columns, 0);
    if (_textDirection == TextDirection.rtl) {
      for (var x = columns - 2; x >= 0; x--) {
        lefts[x] = lefts[x + 1] + widths[x + 1];
      }
    } else {
      for (var x = 1; x < columns; x++) {
        lefts[x] = lefts[x - 1] + widths[x - 1];
      }
    }
    final heights = _rowHeights(widths, (child, width) {
      child.layout(BoxConstraints.tightFor(width: width), parentUsesSize: true);
      return child.size.height;
    });
    final tops = List<double>.filled(_rowCount + 1, 0);
    for (var y = 0; y < _rowCount; y++) {
      tops[y + 1] = tops[y] + heights[y];
    }

    final owners = List.generate(_rowCount, (_) => List.filled(columns, -1));
    var index = 0;
    var child = firstChild;
    while (child != null) {
      final slot = _slot(child);
      if (slot.row < _rowCount && slot.column < columns) {
        final rowEnd = min(slot.row + slot.rowSpan, _rowCount);
        final columnEnd = min(slot.column + slot.columnSpan, columns);
        for (var y = slot.row; y < rowEnd; y++) {
          for (var x = slot.column; x < columnEnd; x++) {
            owners[y][x] = index;
          }
        }
        // The leftmost of its columns: the first in LTR, the last in RTL.
        final left = _textDirection == TextDirection.rtl
            ? lefts[columnEnd - 1]
            : lefts[slot.column];
        final area = tops[rowEnd] - tops[slot.row];
        slot.offset = Offset(
          left,
          tops[slot.row] + (area - child.size.height) / 2,
        );
      } else {
        child.layout(BoxConstraints.tight(Size.zero));
        slot.offset = Offset.zero;
      }
      index += 1;
      child = childAfter(child);
    }

    _columnLefts = lefts;
    _columnWidths = widths;
    _rowTops = tops;
    _owners = owners;
    size = constraints.constrain(
      Size(widths.fold(0.0, (a, b) => a + b), tops.last),
    );
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);

  @override
  void paint(PaintingContext context, Offset offset) {
    if (_isEmpty) return;
    final canvas = context.canvas;
    final width = size.width;

    // The fills below are rectangles while the outer border is a rounded
    // rectangle: without this clip a full-width header row squares off the
    // top corners, showing a tinted block outside the rounded outline. The
    // border itself is painted after the clip is lifted, so this never eats
    // into its stroke.
    final rounded = _borderRadius != BorderRadius.zero;
    if (rounded) {
      canvas.save();
      canvas.clipRRect(_borderRadius.toRRect(offset & size));
    }

    // Header rows, then stripes on every other data row, then header cells
    // that stand in data rows.
    final fill = Paint();
    var dataRow = 0;
    for (var y = 0; y < _rowCount; y++) {
      final header = y < _headerRows.length && _headerRows[y];
      final Color? color;
      if (header) {
        color = _headerBackground;
      } else {
        color = dataRow.isOdd ? _stripeColor : null;
        dataRow += 1;
      }
      if (color != null) {
        canvas.drawRect(
          Rect.fromLTWH(
            offset.dx,
            offset.dy + _rowTops[y],
            width,
            _rowTops[y + 1] - _rowTops[y],
          ),
          fill..color = color,
        );
      }
    }
    var child = firstChild;
    while (child != null) {
      final slot = _slot(child);
      final inHeaderRow =
          slot.row < _headerRows.length && _headerRows[slot.row];
      if (slot.header && (!inHeaderRow || slot.rowSpan > 1)) {
        canvas.drawRect(
          _area(slot).shift(offset),
          fill..color = _headerBackground,
        );
      }
      child = childAfter(child);
    }
    if (rounded) canvas.restore();

    defaultPaint(context, offset);

    // Grid lines between slots with different owners, so none crosses a
    // spanning cell; an empty slot is its own owner.
    final line = Paint()
      ..color = _borderColor
      ..strokeWidth = _borderWidth
      ..style = PaintingStyle.stroke;
    final path = Path();
    for (var y = 0; y < _rowCount; y++) {
      for (var x = 1; x < _columnCount; x++) {
        final a = _owners[y][x - 1];
        final b = _owners[y][x];
        if (a != b || a == -1) {
          final lineX =
              offset.dx +
              (_textDirection == TextDirection.rtl
                  ? _columnLefts[x - 1]
                  : _columnLefts[x]);
          path
            ..moveTo(lineX, offset.dy + _rowTops[y])
            ..lineTo(lineX, offset.dy + _rowTops[y + 1]);
        }
      }
    }
    for (var y = 1; y < _rowCount; y++) {
      for (var x = 0; x < _columnCount; x++) {
        final a = _owners[y - 1][x];
        final b = _owners[y][x];
        if (a != b || a == -1) {
          final lineY = offset.dy + _rowTops[y];
          final left = offset.dx + _columnLefts[x];
          path
            ..moveTo(left, lineY)
            ..lineTo(left + _columnWidths[x], lineY);
        }
      }
    }
    canvas.drawPath(path, line);
    TableBorder.all(
      color: _borderColor,
      width: _borderWidth,
      borderRadius: _borderRadius,
    ).paint(canvas, offset & size, rows: const [], columns: const []);
  }

  /// The area [slot] covers, in local coordinates.
  Rect _area(_HtmlTableParentData slot) {
    final rowEnd = min(slot.row + slot.rowSpan, _rowCount);
    final columnEnd = min(slot.column + slot.columnSpan, _columnCount);
    final left = _textDirection == TextDirection.rtl
        ? _columnLefts[columnEnd - 1]
        : _columnLefts[slot.column];
    var width = 0.0;
    for (var x = slot.column; x < columnEnd; x++) {
      width += _columnWidths[x];
    }
    return Rect.fromLTWH(
      left,
      _rowTops[slot.row],
      width,
      _rowTops[rowEnd] - _rowTops[slot.row],
    );
  }
}
