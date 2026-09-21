/// The copy button must work on the first interaction, by any input.
///
/// It used to be drawn as a plain icon and swapped for a real button only once
/// a pointer reached it, to save ~340 us per code block. Three things broke,
/// and none of them were visible in a test that only ever tapped with a
/// finger:
///
///  * a keyboard user could never reach it — the cheap form had no `Focus`, so
///    it was not in the tab order, and neither promotion path (a pointer
///    entering, or a tap) can be triggered by a key;
///  * the first stylus contact was swallowed — a pen is tracked as a mouse, so
///    touching down promoted the button, unmounting the recogniser mid-gesture
///    and rejecting the gesture, so the first tap copied nothing;
///  * a screen reader got no name and no button role once promoted, because
///    `InkWell` contributes neither and a `Tooltip` supplies only a tooltip.
library;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

const _code = '```dart\nvoid main() {}\n```';

/// Returns a sink that receives the copied code when the button fires.
Future<List<String>> _pump(WidgetTester tester) async {
  final copied = <String>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async => null,
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    ),
  );
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 600,
          child: GptMarkdown(_code, onCodeCopy: copied.add),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return copied;
}

/// Lets the check-mark reset timer run, so the binding does not complain.
Future<void> _drain(WidgetTester tester) =>
    tester.pump(const Duration(seconds: 3));

void main() {
  testWidgets('a stylus copies on its first contact', (tester) async {
    final copied = await _pump(tester);

    // A stylus is tracked as a mouse, so it used to promote the button on
    // contact and lose the very gesture that promoted it.
    final pen = await tester.createGesture(kind: PointerDeviceKind.stylus);
    final centre = tester.getCenter(
      find.byIcon(Icons.content_copy_rounded).first,
    );
    await pen.down(centre);
    await tester.pump();
    await pen.up();
    await tester.pumpAndSettle();

    expect(
      copied.join(),
      contains('void main()'),
      reason: 'the first stylus tap must copy, not just wake the button up',
    );
    await _drain(tester);
  });

  testWidgets('a keyboard can tab to it and press it', (tester) async {
    final copied = await _pump(tester);

    // Tab until the copy button takes focus. A handful of stops is generous:
    // the document is one code block. The point of the loop is that it must
    // arrive at all — the old cheap form was never in the traversal order, so
    // this ran out of stops without the button ever being reached.
    var reached = false;
    for (var stop = 0; stop < 8 && !reached; stop++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      final focused = FocusManager.instance.primaryFocus?.context;
      reached =
          focused != null &&
          find
              .descendant(
                of: find.byType(GptMarkdown),
                matching: find.byWidget(focused.widget),
              )
              .evaluate()
              .isNotEmpty;
    }

    expect(reached, isTrue, reason: 'tabbing never landed on the copy button');

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(
      copied.join(),
      contains('void main()'),
      reason: 'Enter on the focused copy button must copy',
    );
    await _drain(tester);
  });

  testWidgets('it announces a name and a button role', (tester) async {
    final semantics = tester.ensureSemantics();
    await _pump(tester);

    final node = tester.getSemantics(
      find.byIcon(Icons.content_copy_rounded).first,
    );
    expect(
      node.label,
      contains('Copy code'),
      reason: 'an unlabelled tappable node is all a screen reader would get',
    );
    expect(node.flagsCollection.isButton, isTrue);
    semantics.dispose();
    await _drain(tester);
  });
}
