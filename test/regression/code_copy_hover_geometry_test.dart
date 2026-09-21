/// Hovering the copy button must not move or resize it.
///
/// The button is drawn cheaply until a pointer reaches it — a plain icon in a
/// circle rather than a full material button — because a code block pays for
/// the real control on every frame otherwise. The two forms have to be the
/// same size to the pixel, or the swap is visible as the button jumping under
/// the cursor.
///
/// They did not used to be. Both asked for 32 by 32, and `IconButton`
/// disagreed: it folds `visualDensity` into the constraints and reserves its
/// own tap target, resolving to a 24-pixel circle inside a 40-pixel box. The
/// button shrank by 8 pixels and slid 4 the moment it was hovered.
library;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

void main() {
  testWidgets('the copy button keeps its geometry when hovered', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 600,
            child: GptMarkdown('```dart\nvoid main() {}\n```'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    Finder glyph() => find.byIcon(Icons.content_copy_rounded).first;

    /// The painted circle: the innermost box that sizes the button.
    Rect circle() => tester.getRect(
      find.ancestor(of: glyph(), matching: find.byType(ConstrainedBox)).first,
    );

    final restingCircle = circle();
    final restingGlyph = tester.getTopLeft(glyph());
    expect(
      restingCircle.size,
      const Size(32, 32),
      reason: 'the resting button is a 32-pixel circle',
    );

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(tester.getCenter(glyph()));
    await tester.pumpAndSettle();

    expect(
      circle().size,
      restingCircle.size,
      reason: 'hovering resized the button',
    );
    expect(
      circle().topLeft,
      restingCircle.topLeft,
      reason: 'hovering moved the button',
    );
    expect(
      tester.getTopLeft(glyph()),
      restingGlyph,
      reason: 'hovering moved the glyph inside the button',
    );
  });

  testWidgets('hovering promotes it to a real button that still copies', (
    tester,
  ) async {
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
    var copied = '';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 600,
            child: GptMarkdown(
              '```dart\nvoid main() {}\n```',
              onCodeCopy: (code) => copied = code,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(
      tester.getCenter(find.byIcon(Icons.content_copy_rounded).first),
    );
    await tester.pumpAndSettle();

    expect(
      find.byType(InkWell),
      findsWidgets,
      reason: 'a hovered button should have its ink response',
    );

    await tester.tap(find.byIcon(Icons.content_copy_rounded).first);
    await tester.pumpAndSettle();

    expect(copied, contains('void main()'));

    // The check mark resets on a timer; let it run or the binding complains.
    await tester.pump(const Duration(seconds: 3));
  });
}
