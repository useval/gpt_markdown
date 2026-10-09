import 'package:example/selection_demo.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('selection demo renders and toggles', (tester) async {
    tester.view.physicalSize = const Size(1400, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const SelectionApp());
    await tester.pumpAndSettle();

    expect(find.byType(SelectionArea), findsOneWidget);
    expect(find.text('Drag across the Markdown to select some of it.'),
        findsOneWidget);

    // Turning the switch off removes the SelectionArea entirely.
    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();
    expect(find.byType(SelectionArea), findsNothing);
    expect(find.text('Selection is off. Turn the switch on above.'),
        findsOneWidget);
  });
}
