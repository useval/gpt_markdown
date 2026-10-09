import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

import 'golden_comparator.dart';

/// The tolerance in [GoldenComparator] must absorb antialiasing jitter and
/// nothing else. These pin both halves of that.
void main() {
  const quote = '> A quoted line.\n\nText after the quote.';

  Future<Uint8List> render(WidgetTester tester, {double? barWidth}) async {
    tester.view.physicalSize = const Size(300, 120);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GptMarkdown(
            quote,
            styleSheet: GptMarkdownStyleSheet(
              blockQuote: BlockQuoteStyle(barWidth: barWidth),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final element = tester.element(find.byType(MaterialApp));
    return (await tester.runAsync(() async {
      final image = await captureImage(element);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      return png!.buffer.asUint8List();
    }))!;
  }

  Future<bool> within(WidgetTester tester, Uint8List a, Uint8List b) async =>
      (await tester.runAsync(() => GoldenComparator.withinTolerance(a, b)))!;

  testWidgets('a blockquote bar widened from 3 to 9 points still fails', (
    tester,
  ) async {
    final standard = await render(tester);
    final wide = await render(tester, barWidth: 9);

    expect(await within(tester, standard, standard), isTrue);
    expect(await within(tester, standard, wide), isFalse);
  });

  testWidgets('a few levels of jitter on every pixel passes, more fails', (
    tester,
  ) async {
    final standard = await render(tester);

    Future<Uint8List> shifted(int delta) async =>
        (await tester.runAsync(() => _shiftRgb(standard, delta)))!;

    final max = GoldenComparator.maxChannelDelta;
    expect(await within(tester, standard, await shifted(max)), isTrue);
    expect(await within(tester, standard, await shifted(max + 1)), isFalse);
  });
}

/// [png] with every pixel's red, green and blue moved [delta] levels towards
/// the middle, so nothing clamps.
Future<Uint8List> _shiftRgb(Uint8List png, int delta) async {
  final codec = await ui.instantiateImageCodec(png);
  final image = (await codec.getNextFrame()).image;
  codec.dispose();
  final rgba = (await image.toByteData(
    format: ui.ImageByteFormat.rawStraightRgba,
  ))!.buffer.asUint8List();
  final width = image.width;
  final height = image.height;
  image.dispose();

  for (var i = 0; i < rgba.length; i++) {
    if (i % 4 == 3) continue;
    rgba[i] = rgba[i] < 128 ? rgba[i] + delta : rgba[i] - delta;
  }

  final completer = Completer<ui.Image>();
  ui.decodeImageFromPixels(
    rgba,
    width,
    height,
    ui.PixelFormat.rgba8888,
    completer.complete,
  );
  final shifted = await completer.future;
  final out = await shifted.toByteData(format: ui.ImageByteFormat.png);
  shifted.dispose();
  return out!.buffer.asUint8List();
}
