import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_markdown_widgetbook/main.dart';

void main() {
  testWidgets('the widgetbook app builds and lists its use cases', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const GptMarkdownWidgetbook());
    await tester.pumpAndSettle();

    // The generated directory tree is wired in and the folders are listed.
    expect(find.text('Text'), findsWidgets);
    expect(find.text('Blocks'), findsWidgets);
    expect(find.text('Pages'), findsWidgets);
  });
}
