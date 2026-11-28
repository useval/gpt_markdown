import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_markdown/custom_widgets/bidi_rich_text.dart';

/// `placeholderFeedOrder` must give the right layout on both kinds of engine
/// (flutter/flutter#54400): one that fills placeholder slots in logical order,
/// and one that already fills them in visual order. Only one of the two runs
/// on any given Flutter, so the widget tests cannot cover both.
void main() {
  test('an engine that fills slots in logical order gets the full swap', () {
    // RTL line with two formulas: visually, placeholder 1 sits left of 0.
    expect(placeholderFeedOrder(visualOrder: [1, 0], slotOrder: [0, 1]), [
      1,
      0,
    ]);
    expect(
      placeholderFeedOrder(visualOrder: [3, 2, 1, 0], slotOrder: [0, 1, 2, 3]),
      [3, 2, 1, 0],
    );
  });

  test('an engine that already orders slots visually is left alone', () {
    expect(placeholderFeedOrder(visualOrder: [1, 0], slotOrder: [1, 0]), [
      0,
      1,
    ]);
    expect(
      placeholderFeedOrder(visualOrder: [3, 2, 1, 0], slotOrder: [3, 2, 1, 0]),
      [0, 1, 2, 3],
    );
  });

  test('mixed-direction line', () {
    // Visual order 2, 0, 1 (an LTR pair inside an RTL line).
    expect(placeholderFeedOrder(visualOrder: [2, 0, 1], slotOrder: [0, 1, 2]), [
      2,
      0,
      1,
    ]);
    expect(placeholderFeedOrder(visualOrder: [2, 0, 1], slotOrder: [2, 0, 1]), [
      0,
      1,
      2,
    ]);
  });

  test('indices on a later line are offset by start', () {
    expect(
      placeholderFeedOrder(visualOrder: [5, 4], slotOrder: [4, 5], start: 4),
      [5, 4],
    );
    expect(
      placeholderFeedOrder(visualOrder: [5, 4], slotOrder: [5, 4], start: 4),
      [4, 5],
    );
  });
}
