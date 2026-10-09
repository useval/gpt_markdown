import 'package:example/inline_code_demo.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('inline code demo renders and switches presets', (tester) async {
    tester.view.physicalSize = const Size(1400, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const InlineCodeApp());
    await tester.pumpAndSettle();

    expect(find.text('Default'), findsOneWidget);
    expect(find.text('Slack'), findsOneWidget);

    await tester.tap(find.text('Slack'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
