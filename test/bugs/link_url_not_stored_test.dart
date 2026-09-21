/// A link's url must be reachable from the rendered tree, not just captured
/// inside a tap closure.
///
/// It was not. A link was a `LinkButton` widget whose `url` property
/// `buildLinkSpan` never set, so the url existed only inside the `onPressed`
/// closure and nothing could inspect it — which is why the serialised form in
/// `test/README.md` never matched what the serialiser actually wrote.
///
/// A link is a `LinkTextSpan` now and carries `url` as a field, so these pass.
library;

import 'package:flutter_test/flutter_test.dart';
import '../utils/test_helpers.dart';

void main() {
  group('Regression: link url is reachable from the rendered tree', () {
    testWidgets('link URL should be accessible in serialized output '
        '[fixed: the url now rides on LinkTextSpan]', (tester) async {
      await pumpMarkdown(tester, '[click here](https://example.com)');
      final output = getSerializedOutput(tester);

      expect(output, contains('LINK("click here", url="https://example.com")'));
    });

    testWidgets('link with path should include full URL '
        '[fixed: the url now rides on LinkTextSpan]', (tester) async {
      await pumpMarkdown(tester, '[docs](https://example.com/docs/page)');
      final output = getSerializedOutput(tester);

      expect(
        output,
        contains('LINK("docs", url="https://example.com/docs/page")'),
      );
    });
  });
}
