import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

/// Issue #107. `GptMarkdown` under `IntrinsicWidth` or `IntrinsicHeight` — the
/// usual way to shrink-wrap a chat bubble — threw:
///
///  * a rule: `RenderDivider` had no `computeDryBaseline`, so the dry layout
///    of the paragraph holding it asserted (legacy pipeline), and its intrinsic
///    height was zero, so `IntrinsicHeight` overflowed by the rule (plusparse);
///  * a table: `CustomTableColumnWidth` lays cells out to size columns, which
///    is illegal while an intrinsic is being computed. In release the cell was
///    left unsized and paint failed with `'hasSize'`.
///
/// Still open on the legacy pipeline (`inlineComponents` / `components`) in
/// debug builds. It places each block in a baseline-aligned `WidgetSpan`, so a
/// dry layout asks every block for a dry baseline, and Flutter's own
/// `RenderProxyBoxMixin` and `_RenderSingleChildViewport` assert when a block
/// has none. The heading rule is the exception: its placeholder is
/// bottom-aligned.

const _cases = {
  'rule': 'above\n\n---\n\nbelow',
  'h1 rule': '# Title\n\nbody',
  'table': '| name | value |\n|---|---|\n| alpha | 1 |\n| beta | 22 |',
  // Rendered maths must not lay out through a `LayoutBuilder`, which has no
  // intrinsic sizes.
  'block math': r'\[x = \frac{-b \pm \sqrt{b^2-4ac}}{2a}\]',
  'inline math': r'where \(x^2\) is positive',
  'mixed':
      '# Title\n\ntext **bold**\n\n---\n\n| a | b |\n|---|---|\n| 1 | 2 |'
      '\n\n- item\n\n> quote',
};

Widget _markdown(String data, {required bool legacy}) {
  return legacy
      ? GptMarkdown(data, inlineComponents: MarkdownComponent.inlineComponents)
      : GptMarkdown(data);
}

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  double textScale = 1,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: Scaffold(body: Center(child: child)),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Whether a case is still open on the legacy pipeline; see above.
bool _openOnLegacy(String name) => name != 'h1 rule';

void main() {
  for (final legacy in [false, true]) {
    final pipeline = legacy ? 'legacy' : 'plusparse';
    for (final entry in _cases.entries) {
      final skip = legacy && _openOnLegacy(entry.key);
      for (final textScale in [1.0, 2.0]) {
        testWidgets(
          '$pipeline ${entry.key} in IntrinsicWidth '
          'at ${textScale}x',
          skip: skip,
          (tester) async {
            await _pump(
              tester,
              IntrinsicWidth(child: _markdown(entry.value, legacy: legacy)),
              textScale: textScale,
            );
            expect(tester.takeException(), isNull);
          },
        );

        testWidgets(
          '$pipeline ${entry.key} in IntrinsicHeight '
          'at ${textScale}x',
          skip: skip,
          (tester) async {
            await _pump(
              tester,
              IntrinsicHeight(child: _markdown(entry.value, legacy: legacy)),
              textScale: textScale,
            );
            expect(tester.takeException(), isNull);
          },
        );
      }
    }

    testWidgets('$pipeline table in IntrinsicWidth on desktop', skip: legacy, (
      tester,
    ) async {
      // Desktop wraps the table in a Scrollbar and a padded strip.
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      try {
        await _pump(
          tester,
          IntrinsicWidth(child: _markdown(_cases['table']!, legacy: legacy)),
        );
        expect(tester.takeException(), isNull);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets(
      '$pipeline table in IntrinsicWidth sizes to its content',
      skip: legacy,
      (tester) async {
        // The intrinsic answer comes from the cells' intrinsic widths, the
        // layout from laying them out. For text they agree, so the bubble is
        // exactly as wide as the table and nothing is clipped or scrolled.
        await _pump(
          tester,
          IntrinsicWidth(child: _markdown(_cases['table']!, legacy: legacy)),
        );
        final table = tester.getSize(find.byType(Table));
        final bubble = tester.getSize(find.byType(IntrinsicWidth));
        expect(table.width, greaterThan(100));
        expect(bubble.width, moreOrLessEquals(table.width, epsilon: 0.5));
      },
    );

    testWidgets(
      '$pipeline rule height matches in IntrinsicHeight',
      skip: legacy,
      (tester) async {
        await _pump(tester, _markdown(_cases['rule']!, legacy: legacy));
        final plain = tester.getSize(find.byType(GptMarkdown)).height;
        await _pump(
          tester,
          IntrinsicHeight(child: _markdown(_cases['rule']!, legacy: legacy)),
        );
        expect(tester.takeException(), isNull);
        expect(
          tester.getSize(find.byType(GptMarkdown)).height,
          moreOrLessEquals(plain, epsilon: 0.5),
        );
      },
    );
  }
}
