import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_markdown/custom_widgets/code_field.dart';
import 'package:gpt_markdown/custom_widgets/custom_divider.dart';
import 'package:gpt_markdown/custom_widgets/custom_rb_cb.dart';
import 'package:gpt_markdown/custom_widgets/indent_widget.dart';
import 'package:gpt_markdown/custom_widgets/selectable_adapter.dart';
import 'package:gpt_markdown/custom_widgets/unordered_ordered_list.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

import 'serializer.dart';

/// Pumps a [GptMarkdown] widget with the given [markdown] input.
///
/// Wraps the widget in a [MaterialApp] and [Scaffold] to provide
/// the required context for theming and layout.
///
/// Returns the [WidgetTester] for further assertions.
Future<void> pumpMarkdown(
  WidgetTester tester,
  String markdown, {
  TextStyle? style,
  TextDirection textDirection = TextDirection.ltr,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: GptMarkdown(
            markdown,
            style: style,
            textDirection: textDirection,
          ),
        ),
      ),
    ),
  );
  // Allow any animations or async operations to complete
  await tester.pumpAndSettle();
}

/// Extracts and serializes the output from the rendered [GptMarkdown] widget.
///
/// Returns the serialized string representation of the markdown output.
/// This iterates through ALL RichText widgets to capture nested content
/// (from MdWidget instances inside list items, checkboxes, etc.)
String getSerializedOutput(WidgetTester tester) {
  // Walk the element tree in document order rather than collecting every
  // `RichText` first.
  //
  // Block constructs used to be `WidgetSpan`s inside a paragraph, so finding
  // the paragraphs found everything. They are plain siblings in a column now —
  // a table, a fence or a block equation has no `RichText` above it — and a
  // finder for paragraphs walks straight past them.
  //
  // Three kinds of node stop or shape the walk:
  //  * a paragraph, serialized from its spans;
  //  * an *opaque* block, which the serializer renders whole from its own
  //    fields and whose insides are noise (a fence's raw text, the glyphs an
  //    equation is built from);
  //  * a *wrapper* block, which contributes a marker and still has to be
  //    descended into, because its content is a paragraph further down.
  final parts = <String>[];
  final builtChildren = <Widget, List<Widget>>{};
  void collect(Element element) {
    final children = <Widget>[];
    element.visitChildren((child) {
      children.add(child.widget);
      collect(child);
    });
    if (element.widget is Builder) builtChildren[element.widget] = children;
  }

  tester.binding.rootElement?.visitChildren(collect);

  void walk(Element element, List<String> out) {
    final widget = element.widget;
    if (widget is RichText) {
      final rendered = serializeMarkdown(
        widget.text,
        builtChildren: builtChildren,
      );
      if (rendered.isNotEmpty) {
        out.add(rendered);
      }
      return;
    }
    if (_isOpaqueBlock(widget)) {
      final rendered = serializeBlockWidget(widget);
      if (rendered.isNotEmpty) {
        out.add(rendered);
      }
      return;
    }
    final wrap = _wrapperMarker(widget);
    if (wrap != null) {
      final inner = <String>[];
      element.visitChildren((child) => walk(child, inner));
      out.add(wrap(inner.join(' ')));
      return;
    }
    element.visitChildren((child) => walk(child, out));
  }

  tester.binding.rootElement?.visitChildren((e) => walk(e, parts));
  return parts.join('\n');
}

/// A block the serializer renders whole, whose subtree must not be walked.
bool _isOpaqueBlock(Widget widget) =>
    // Rendered maths, matched by type name because `flutter_math_fork`'s type
    // is not importable here — the same heuristic the serializer itself uses.
    // Descending would report each glyph of an equation as its own run.
    widget.runtimeType.toString().contains('Math') ||
    widget is SelectableAdapter ||
    widget is CodeField ||
    widget is Table ||
    widget is CustomDivider;

/// How a block wraps its serialized content, while still being walked into.
String Function(String inner)? _wrapperMarker(Widget widget) {
  if (widget is UnorderedListView) {
    return (inner) => 'UL_ITEM($inner)';
  }
  if (widget is OrderedListView) {
    final no = widget.no.replaceAll('.', '');
    return (inner) => 'OL_ITEM($no, $inner)';
  }
  if (widget is BlockQuoteWidget) {
    return (inner) => 'BLOCKQUOTE($inner)';
  }
  if (widget is CustomCb) {
    return (inner) => 'CHECKBOX(checked=${widget.value}, $inner)';
  }
  if (widget is CustomRb) {
    return (inner) => 'RADIO(checked=${widget.value}, $inner)';
  }
  return null;
}

/// Combined helper that pumps markdown and asserts on the serialized output.
///
/// This is the primary helper for most test cases.
///
/// Example:
/// ```dart
/// testWidgets('bold text', (tester) async {
///   await expectMarkdown(
///     tester,
///     '**bold**',
///     'TEXT("bold")[bold]',
///   );
/// });
/// ```
Future<void> expectMarkdown(
  WidgetTester tester,
  String markdown,
  String expectedOutput, {
  TextStyle? style,
  TextDirection textDirection = TextDirection.ltr,
}) async {
  await pumpMarkdown(
    tester,
    markdown,
    style: style,
    textDirection: textDirection,
  );

  final actualOutput = getSerializedOutput(tester);
  expect(actualOutput, expectedOutput);
}

/// Asserts that the serialized output contains a specific pattern.
///
/// Useful for partial matching when exact output is complex or
/// when testing for presence of specific elements.
Future<void> expectMarkdownContains(
  WidgetTester tester,
  String markdown,
  String pattern, {
  TextStyle? style,
  TextDirection textDirection = TextDirection.ltr,
}) async {
  await pumpMarkdown(
    tester,
    markdown,
    style: style,
    textDirection: textDirection,
  );

  final actualOutput = getSerializedOutput(tester);
  expect(actualOutput, contains(pattern));
}

/// Asserts that the serialized output matches a regular expression.
///
/// Useful for flexible matching when exact content varies but
/// structure should be consistent.
Future<void> expectMarkdownMatches(
  WidgetTester tester,
  String markdown,
  Pattern pattern, {
  TextStyle? style,
  TextDirection textDirection = TextDirection.ltr,
}) async {
  await pumpMarkdown(
    tester,
    markdown,
    style: style,
    textDirection: textDirection,
  );

  final actualOutput = getSerializedOutput(tester);
  expect(actualOutput, matches(pattern));
}

/// Debug helper that prints the serialized output for a given markdown input.
///
/// Useful when developing new tests to see what output format to expect.
///
/// Example:
/// ```dart
/// testWidgets('debug output', (tester) async {
///   await debugMarkdownOutput(tester, '**bold** and *italic*');
///   // Prints: TEXT("bold")[bold] TEXT(" and ") TEXT("italic")[italic]
/// });
/// ```
Future<void> debugMarkdownOutput(
  WidgetTester tester,
  String markdown, {
  TextStyle? style,
  TextDirection textDirection = TextDirection.ltr,
}) async {
  await pumpMarkdown(
    tester,
    markdown,
    style: style,
    textDirection: textDirection,
  );

  final actualOutput = getSerializedOutput(tester);
  // ignore: avoid_print
  print('Markdown input: $markdown');
  // ignore: avoid_print
  print('Serialized output: $actualOutput');
}
