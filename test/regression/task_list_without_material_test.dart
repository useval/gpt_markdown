import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

/// Issue #154. A task list or radio item threw "No Material widget found"
/// when no `Material` sat above `GptMarkdown`: a bare `WidgetsApp`, a
/// Cupertino app, or a widget built straight into an overlay.

Widget _bare(String data) => Directionality(
  textDirection: TextDirection.ltr,
  child: MediaQuery(
    data: const MediaQueryData(),
    child: Center(child: GptMarkdown(data)),
  ),
);

void main() {
  testWidgets('a task list renders with no Material ancestor', (tester) async {
    await tester.pumpWidget(_bare('- [ ] todo\n- [x] done'));
    expect(tester.takeException(), isNull);
    expect(find.textContaining('todo', findRichText: true), findsOneWidget);
  });

  testWidgets('a radio item renders with no Material ancestor', (tester) async {
    await tester.pumpWidget(_bare('( ) no\n(x) yes'));
    expect(tester.takeException(), isNull);
  });
}
