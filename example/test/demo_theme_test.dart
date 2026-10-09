import 'package:example/autolink_demo.dart';
import 'package:example/inline_code_demo.dart';
import 'package:example/inline_patterns_demo.dart';
import 'package:example/main.dart';
import 'package:example/selection_demo.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

/// Every demo starts light and flips to dark from its app bar.
void main() {
  final apps = <String, Widget>{
    'main': const App(),
    'selection': const SelectionApp(),
    'autolink': const AutolinkApp(),
    'inline code': const InlineCodeApp(),
    'inline patterns': const InlinePatternsApp(),
  };

  for (final entry in apps.entries) {
    testWidgets('${entry.key} toggles light and dark', (tester) async {
      tester.view.physicalSize = const Size(1400, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(entry.value);
      await tester.pumpAndSettle();

      Brightness brightness() => Theme.of(
            tester.element(find.byType(Scaffold).first),
          ).brightness;

      expect(brightness(), Brightness.light);

      await tester.tap(find.byIcon(Icons.dark_mode_rounded));
      await tester.pumpAndSettle();
      expect(brightness(), Brightness.dark);

      await tester.tap(find.byIcon(Icons.light_mode_rounded));
      await tester.pumpAndSettle();
      expect(brightness(), Brightness.light);
    });
  }
}
