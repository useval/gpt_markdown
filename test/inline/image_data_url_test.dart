import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_markdown/custom_widgets/custom_error_image.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

/// Issue #32: an image whose URL is a `data:` URL —
/// `![](data:image/png;base64,...)` — went to `NetworkImage`, which cannot
/// load one outside a browser, so it showed the broken-image icon.

/// A 1×1 PNG.
const _png =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGA'
    'WjR9awAAAABJRU5ErkJggg==';
const _dataUrl = 'data:image/png;base64,$_png';

Future<void> _pump(
  WidgetTester tester,
  String markdown, {
  bool legacy = false,
  ImageBuilder? imageBuilder,
  void Function(String url)? onImageTap,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: GptMarkdown(
            markdown,
            inlineComponents: legacy
                ? MarkdownComponent.inlineComponents
                : null,
            imageBuilder: imageBuilder,
            onImageTap: onImageTap,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

/// Lets the engine actually decode, then settles the frame that shows it.
Future<void> _decode(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 200)),
  );
  await tester.pump();
}

ImageProvider _provider(WidgetTester tester) =>
    tester.widget<Image>(find.byType(Image)).image;

void main() {
  for (final legacy in [false, true]) {
    final pipeline = legacy ? 'legacy' : 'plusparse';

    group(pipeline, () {
      testWidgets('a base64 data URL is decoded and drawn', (tester) async {
        await _pump(tester, 'before ![]($_dataUrl) after', legacy: legacy);
        final provider = _provider(tester);
        expect(provider, isA<MemoryImage>());
        expect((provider as MemoryImage).bytes, base64Decode(_png));
        await _decode(tester);
        expect(find.byType(CustomImageError), findsNothing);
        expect(tester.widget<RawImage>(find.byType(RawImage)).image, isNotNull);
      });

      testWidgets('the size in the alt text still applies', (tester) async {
        await _pump(tester, '![32x20]($_dataUrl)', legacy: legacy);
        final box = tester.widget<SizedBox>(
          find
              .ancestor(of: find.byType(Image), matching: find.byType(SizedBox))
              .first,
        );
        expect(box.width, 32);
        expect(box.height, 20);
      });

      testWidgets('a network URL still loads from the network', (tester) async {
        await _pump(tester, '![](https://example.com/a.png)', legacy: legacy);
        expect(_provider(tester), isA<NetworkImage>());
      });

      testWidgets('bad data shows the broken-image icon, not an exception', (
        tester,
      ) async {
        for (final url in [
          'data:image/png;base64,not-base64!!',
          'data:text/plain;base64,aGVsbG8=',
        ]) {
          await _pump(tester, '![]($url)', legacy: legacy);
          await _decode(tester);
          expect(tester.takeException(), isNull);
          expect(find.byType(CustomImageError), findsOneWidget);
        }
      });

      testWidgets('imageBuilder and onImageTap get the URL as written', (
        tester,
      ) async {
        String? built;
        await _pump(
          tester,
          '![]($_dataUrl)',
          legacy: legacy,
          imageBuilder: (context, url, width, height) {
            built = url;
            return const SizedBox(width: 10, height: 10);
          },
        );
        expect(built, _dataUrl);

        String? tapped;
        await _pump(
          tester,
          '![10x10]($_dataUrl)',
          legacy: legacy,
          onImageTap: (url) => tapped = url,
        );
        await tester.tap(find.byType(Image));
        expect(tapped, _dataUrl);
      });
    });
  }

  testWidgets('the scheme is case-insensitive', (tester) async {
    await _pump(tester, '![](DATA:image/png;base64,$_png)');
    expect(_provider(tester), isA<MemoryImage>());
  });

  testWidgets('a percent-encoded data URL is decoded too', (tester) async {
    await _pump(tester, '![](data:image/png,%89PNG)');
    final bytes = (_provider(tester) as MemoryImage).bytes;
    expect(bytes, [0x89, 0x50, 0x4E, 0x47]);
  });

  testWidgets('rebuilds reuse the decoded bytes', (tester) async {
    // A MemoryImage is identified by its byte list: new bytes on every build
    // would be a new image every build, decoded again and flickering.
    await _pump(tester, 'one ![]($_dataUrl)');
    final first = (_provider(tester) as MemoryImage).bytes;
    await _pump(tester, 'one ![]($_dataUrl) two');
    final second = (_provider(tester) as MemoryImage).bytes;
    expect(identical(first, second), isTrue);
    expect(_provider(tester), MemoryImage(first));
  });
}
