import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

/// Every style class in the package follows the same contract. Rather than
/// repeat the same checks twelve times, each style declares how to build two
/// distinct instances and the shared tests run against all of them.
class StyleCase {
  const StyleCase({
    required this.name,
    required this.a,
    required this.b,
    required this.merge,
    required this.lerp,
    required this.resolve,
    required this.select,
    required this.put,
  });

  final String name;

  /// Two instances that set different fields, so a per-object merge would
  /// visibly lose one of them.
  final Object a;
  final Object b;

  final Object Function(Object self, Object? other) merge;
  final Object? Function(Object? a, Object? b, double t) lerp;
  final Object Function(Object self, ColorScheme scheme) resolve;
  final Object? Function(GptMarkdownStyleSheet sheet) select;
  final GptMarkdownStyleSheet Function(Object style) put;
}

/// Wraps the typed members of one style class as the untyped closures
/// [StyleCase] holds, so a single list can cover every style.
StyleCase styleCase<S extends Object>({
  required String name,
  required S a,
  required S b,
  required S Function(S self, S? other) merge,
  required S? Function(S? a, S? b, double t) lerp,
  required S Function(S self, ColorScheme scheme) resolve,
  required S? Function(GptMarkdownStyleSheet sheet) select,
  required GptMarkdownStyleSheet Function(S style) put,
}) {
  return StyleCase(
    name: name,
    a: a,
    b: b,
    merge: (self, other) => merge(self as S, other as S?),
    lerp: (x, y, t) => lerp(x as S?, y as S?, t),
    resolve: (self, scheme) => resolve(self as S, scheme),
    select: select,
    put: (style) => put(style as S),
  );
}

final _cases = <StyleCase>[
  styleCase(
    name: 'BlockQuoteStyle',
    a: const BlockQuoteStyle(barWidth: 1),
    b: const BlockQuoteStyle(barColor: Color(0xFF123456)),
    merge: (self, other) => self.merge(other),
    lerp: BlockQuoteStyle.lerp,
    resolve: (self, scheme) => self.resolve(scheme),
    select: (sheet) => sheet.blockQuote,
    put: (style) => GptMarkdownStyleSheet(blockQuote: style),
  ),
  styleCase(
    name: 'HeadingStyle',
    a: const HeadingStyle(dividerThickness: 1),
    b: const HeadingStyle(dividerColor: Color(0xFF123456)),
    merge: (self, other) => self.merge(other),
    lerp: HeadingStyle.lerp,
    resolve: (self, scheme) => self.resolve(scheme),
    select: (sheet) => sheet.heading,
    put: (style) => GptMarkdownStyleSheet(heading: style),
  ),
  styleCase(
    name: 'LinkStyle',
    a: const LinkStyle(decorationThickness: 1),
    b: const LinkStyle(color: Color(0xFF123456)),
    merge: (self, other) => self.merge(other),
    lerp: LinkStyle.lerp,
    resolve: (self, scheme) => self.resolve(scheme),
    select: (sheet) => sheet.link,
    put: (style) => GptMarkdownStyleSheet(link: style),
  ),
  styleCase(
    name: 'ListStyle',
    a: const ListStyle(bulletSize: 1),
    b: const ListStyle(bulletColor: Color(0xFF123456)),
    merge: (self, other) => self.merge(other),
    lerp: ListStyle.lerp,
    resolve: (self, scheme) => self.resolve(scheme),
    select: (sheet) => sheet.list,
    put: (style) => GptMarkdownStyleSheet(list: style),
  ),
  styleCase(
    name: 'CheckboxStyle',
    a: const CheckboxStyle(size: 1),
    b: const CheckboxStyle(checkedColor: Color(0xFF123456)),
    merge: (self, other) => self.merge(other),
    lerp: CheckboxStyle.lerp,
    resolve: (self, scheme) => self.resolve(scheme),
    select: (sheet) => sheet.checkbox,
    put: (style) => GptMarkdownStyleSheet(checkbox: style),
  ),
  styleCase(
    name: 'CodeBlockStyle',
    a: const CodeBlockStyle(fontSize: 1),
    b: const CodeBlockStyle(backgroundColor: Color(0xFF123456)),
    merge: (self, other) => self.merge(other),
    lerp: CodeBlockStyle.lerp,
    resolve: (self, scheme) => self.resolve(scheme),
    select: (sheet) => sheet.codeBlock,
    put: (style) => GptMarkdownStyleSheet(codeBlock: style),
  ),
  styleCase(
    name: 'TableStyle',
    a: const TableStyle(borderWidth: 1),
    b: const TableStyle(borderColor: Color(0xFF123456)),
    merge: (self, other) => self.merge(other),
    lerp: TableStyle.lerp,
    resolve: (self, scheme) => self.resolve(scheme),
    select: (sheet) => sheet.table,
    put: (style) => GptMarkdownStyleSheet(table: style),
  ),
  styleCase(
    name: 'ImageStyle',
    a: const ImageStyle(maxWidth: 1),
    b: const ImageStyle(borderRadius: Radius.circular(3)),
    merge: (self, other) => self.merge(other),
    lerp: ImageStyle.lerp,
    resolve: (self, scheme) => self.resolve(scheme),
    select: (sheet) => sheet.image,
    put: (style) => GptMarkdownStyleSheet(image: style),
  ),
  styleCase(
    name: 'HrStyle',
    a: const HrStyle(thickness: 1),
    b: const HrStyle(color: Color(0xFF123456)),
    merge: (self, other) => self.merge(other),
    lerp: HrStyle.lerp,
    resolve: (self, scheme) => self.resolve(scheme),
    select: (sheet) => sheet.hr,
    put: (style) => GptMarkdownStyleSheet(hr: style),
  ),
  styleCase(
    name: 'SourceTagStyle',
    a: const SourceTagStyle(size: 1),
    b: const SourceTagStyle(backgroundColor: Color(0xFF123456)),
    merge: (self, other) => self.merge(other),
    lerp: SourceTagStyle.lerp,
    resolve: (self, scheme) => self.resolve(scheme),
    select: (sheet) => sheet.sourceTag,
    put: (style) => GptMarkdownStyleSheet(sourceTag: style),
  ),
  styleCase(
    name: 'LatexStyle',
    a: const LatexStyle(backgroundColor: Color(0xFF123456)),
    b: const LatexStyle(borderRadius: Radius.circular(3)),
    merge: (self, other) => self.merge(other),
    lerp: LatexStyle.lerp,
    resolve: (self, scheme) => self.resolve(scheme),
    select: (sheet) => sheet.latex,
    put: (style) => GptMarkdownStyleSheet(latex: style),
  ),
  styleCase(
    name: 'InlineCodeStyle',
    a: const InlineCodeStyle(borderWidth: 1),
    b: const InlineCodeStyle(color: Color(0xFF123456)),
    merge: (self, other) => self.merge(other),
    lerp: InlineCodeStyle.lerp,
    resolve: (self, scheme) => self.resolve(scheme),
    select: (sheet) => sheet.inlineCode,
    put: (style) => GptMarkdownStyleSheet(inlineCode: style),
  ),
];

void main() {
  const scheme = ColorScheme.light();

  for (final testCase in _cases) {
    group(testCase.name, () {
      test('merge(null) is identity', () {
        expect(testCase.merge(testCase.a, null), testCase.a);
      });

      test('merge keeps both sides, field by field', () {
        // `a` and `b` set different fields, so a per-object override would
        // lose one of them.
        final merged = testCase.merge(testCase.a, testCase.b);
        expect(merged, isNot(testCase.a));
        expect(merged, isNot(testCase.b));
        expect(testCase.merge(merged, testCase.a), merged);
        expect(testCase.merge(merged, testCase.b), merged);
      });

      test('lerp between identical ends is a no-op', () {
        // Between two different styles the ends are not returned verbatim:
        // `Color.lerp(null, c, 0)` is transparent, not null, which is how
        // Flutter's own lerps behave. Identical ends must still be stable.
        for (final t in [0.0, 0.5, 1.0]) {
          expect(testCase.lerp(testCase.a, testCase.a, t), testCase.a);
        }
      });

      test('lerp moves away from both ends at the midpoint', () {
        final mid = testCase.lerp(testCase.a, testCase.b, 0.5);
        expect(mid, isNotNull);
        expect(mid, isNot(testCase.a));
        expect(mid, isNot(testCase.b));
      });

      test('lerp of two nulls is null', () {
        expect(testCase.lerp(null, null, 0.5), isNull);
      });

      test('resolve is idempotent', () {
        final once = testCase.resolve(testCase.a, scheme);
        expect(testCase.resolve(once, scheme), once);
      });

      test('resolve keeps values that are already set', () {
        expect(testCase.resolve(testCase.a, scheme), isNot(testCase.b));
      });

      test('round-trips through a style sheet', () {
        final sheet = testCase.put(testCase.a);
        expect(testCase.select(sheet), testCase.a);
      });

      test('the sheet merges per component', () {
        final sheet = testCase.put(testCase.a).merge(testCase.put(testCase.b));
        expect(testCase.select(sheet), testCase.merge(testCase.a, testCase.b));
      });

      test('equality and hashCode agree', () {
        expect(testCase.a == testCase.a, isTrue);
        expect(testCase.a == testCase.b, isFalse);
        expect(testCase.a.hashCode, testCase.a.hashCode);
      });
    });
  }

  test('the style sheet lerps every component', () {
    final a = GptMarkdownStyleSheet(
      blockQuote: const BlockQuoteStyle(barWidth: 0),
      heading: const HeadingStyle(dividerThickness: 0),
      link: const LinkStyle(decorationThickness: 0),
      inlineCode: const InlineCodeStyle(borderWidth: 0),
      list: const ListStyle(bulletSize: 0),
      checkbox: const CheckboxStyle(size: 0),
      codeBlock: const CodeBlockStyle(fontSize: 0),
      table: const TableStyle(borderWidth: 0),
      image: const ImageStyle(maxWidth: 0),
      hr: const HrStyle(thickness: 0),
      sourceTag: const SourceTagStyle(size: 0),
      latex: const LatexStyle(borderRadius: Radius.circular(0)),
    );
    final b = GptMarkdownStyleSheet(
      blockQuote: const BlockQuoteStyle(barWidth: 10),
      heading: const HeadingStyle(dividerThickness: 10),
      link: const LinkStyle(decorationThickness: 10),
      inlineCode: const InlineCodeStyle(borderWidth: 10),
      list: const ListStyle(bulletSize: 10),
      checkbox: const CheckboxStyle(size: 10),
      codeBlock: const CodeBlockStyle(fontSize: 10),
      table: const TableStyle(borderWidth: 10),
      image: const ImageStyle(maxWidth: 10),
      hr: const HrStyle(thickness: 10),
      sourceTag: const SourceTagStyle(size: 10),
      latex: const LatexStyle(borderRadius: Radius.circular(10)),
    );

    final mid = GptMarkdownStyleSheet.lerp(a, b, 0.5);
    expect(mid, isNotNull);
    if (mid == null) {
      return;
    }
    expect(mid.blockQuote?.barWidth, 5);
    expect(mid.heading?.dividerThickness, 5);
    expect(mid.link?.decorationThickness, 5);
    expect(mid.inlineCode?.borderWidth, 5);
    expect(mid.list?.bulletSize, 5);
    expect(mid.checkbox?.size, 5);
    expect(mid.codeBlock?.fontSize, 5);
    expect(mid.table?.borderWidth, 5);
    expect(mid.image?.maxWidth, 5);
    expect(mid.hr?.thickness, 5);
    expect(mid.sourceTag?.size, 5);
    expect(mid.latex?.borderRadius, const Radius.circular(5));
  });
}
