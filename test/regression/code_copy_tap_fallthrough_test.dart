/// The copy button must never let a tap through to whatever is behind it.
///
/// `IgnorePointer` made the button transparent to hit-testing for the whole
/// two-second check-mark window, so a second tap on the *same spot* fell
/// through to the host's gesture detector. Chat UIs commonly wrap a code block
/// in a tap-to-collapse region, so the visible effect was: copy, tap again,
/// and the block you just copied from disappears.
///
/// The duplicate-clipboard guard the `IgnorePointer` was there for already
/// exists inside `_copyCode` (`if (_copying || _copied) return;`), so blocking
/// the pointer is only about not leaking it.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

void main() {
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  testWidgets('a second tap during the copied window does not reach the host', (
    tester,
  ) async {
    var hostTaps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GestureDetector(
            onTap: () => hostTaps += 1,
            child: SizedBox(
              width: 600,
              child: GptMarkdown('```dart\nvar a = 1;\n```'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final copy = find.byIcon(Icons.content_copy_rounded);
    expect(copy, findsOneWidget);

    await tester.tap(copy);
    await tester.pump();
    expect(hostTaps, 0, reason: 'the first tap must not reach the host');

    // Still inside the check-mark window: the button is "disabled", but the
    // pointer must be absorbed, not passed through.
    await tester.tapAt(tester.getCenter(find.byIcon(Icons.check_rounded)));
    await tester.pump();

    expect(
      hostTaps,
      0,
      reason: 'the copy button leaked a tap to the surrounding gesture',
    );

    // Drain the check-mark reset timer so teardown does not trip
    // "a Timer is still pending".
    await tester.pumpAndSettle(const Duration(seconds: 3));
  });

  testWidgets('copying twice in the window writes the clipboard once', (
    tester,
  ) async {
    final copied = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 600,
            child: GptMarkdown(
              '```dart\nvar a = 1;\n```',
              onCodeCopy: copied.add,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The control is a plain icon until first use, so tap the glyph rather
    // than the IconButton it becomes.
    await tester.tap(find.byIcon(Icons.content_copy_rounded));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.check_rounded));
    await tester.pump();

    expect(copied.length, 1);

    await tester.pumpAndSettle(const Duration(seconds: 3));
  });
}
