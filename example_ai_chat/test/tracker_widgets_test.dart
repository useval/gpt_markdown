import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:gpt_markdown_ai_chat/tracker/markdown_editor.dart';
import 'package:gpt_markdown_ai_chat/tracker/models.dart';
import 'package:gpt_markdown_ai_chat/tracker/widgets.dart';

Widget _wrap(Widget child) =>
    MaterialApp(home: Scaffold(body: Center(child: child)));

void main() {
  group('IssueLabel', () {
    test('parses the stored hex colour', () {
      const label = IssueLabel(id: 1, name: 'bug', color: '#d73a4a');
      expect(label.swatch, const Color(0xFFD73A4A));
    });

    test('falls back to grey on a malformed colour', () {
      const label = IssueLabel(id: 1, name: 'x', color: 'not-a-colour');
      expect(label.swatch, const Color(0xFFEDEDED));
    });
  });

  group('Issue', () {
    test('reads the shape the API returns', () {
      final issue = Issue.fromJson({
        'id': 7,
        'number': 7,
        'title': 'Tables lose alignment',
        'body': 'body',
        'state': 'closed',
        'author': 'you',
        'created_at': '2026-08-30T10:00:00.000Z',
        'updated_at': '2026-08-30T11:00:00.000Z',
        'closed_at': '2026-08-30T11:00:00.000Z',
        'request_id': 42,
        'markdown': '| a |',
        'comment_count': 2,
        'labels': [
          {'id': 1, 'name': 'bug', 'color': '#d73a4a'},
        ],
        'timeline': [
          {
            'kind': 'event',
            'id': 3,
            'type': 'closed',
            'actor': 'you',
            'created_at': '2026-08-30T11:00:00.000Z',
          },
        ],
      });

      expect(issue.number, 7);
      expect(issue.isOpen, isFalse);
      expect(issue.requestId, 42);
      expect(issue.labels.single.name, 'bug');
      expect(issue.timeline.single.isComment, isFalse);
      expect(issue.timeline.single.type, 'closed');
    });
  });

  group('relativeTime', () {
    test('describes the distance from now', () {
      final now = DateTime.now();
      expect(relativeTime(now), 'just now');
      expect(
        relativeTime(now.subtract(const Duration(minutes: 1))),
        '1 minute ago',
      );
      expect(
        relativeTime(now.subtract(const Duration(hours: 5))),
        '5 hours ago',
      );
      expect(relativeTime(now.subtract(const Duration(days: 2))), '2 days ago');
      expect(
        relativeTime(now.subtract(const Duration(days: 400))),
        '1 year ago',
      );
    });
  });

  group('StateBadge', () {
    testWidgets('is green and says Open', (tester) async {
      await tester.pumpWidget(_wrap(const StateBadge(state: 'open')));
      expect(find.text('Open'), findsOneWidget);
      final container = tester.widget<Container>(find.byType(Container).first);
      final decoration = container.decoration! as BoxDecoration;
      expect(decoration.color, IssueColors.open);
    });

    testWidgets('is purple and says Closed', (tester) async {
      await tester.pumpWidget(_wrap(const StateBadge(state: 'closed')));
      expect(find.text('Closed'), findsOneWidget);
      final container = tester.widget<Container>(find.byType(Container).first);
      final decoration = container.decoration! as BoxDecoration;
      expect(decoration.color, IssueColors.closed);
    });
  });

  group('LabelChip', () {
    testWidgets('picks readable text for a pale label', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const LabelChip(
            label: IssueLabel(id: 1, name: 'wontfix', color: '#ffffff'),
          ),
        ),
      );
      final text = tester.widget<Text>(find.text('wontfix'));
      expect(text.style?.color, Colors.black87);
    });

    testWidgets('picks readable text for a dark label', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const LabelChip(
            label: IssueLabel(id: 1, name: 'latex', color: '#5319e7'),
          ),
        ),
      );
      final text = tester.widget<Text>(find.text('latex'));
      expect(text.style?.color, Colors.white);
    });
  });

  group('MarkdownEditor', () {
    testWidgets('switches between writing and rendering', (tester) async {
      final controller = TextEditingController(text: '# Heading');
      addTearDown(controller.dispose);

      await tester.pumpWidget(_wrap(MarkdownEditor(controller: controller)));

      expect(find.byType(TextField), findsOneWidget);
      expect(find.byType(GptMarkdown), findsNothing);

      await tester.tap(find.text('Preview'));
      await tester.pumpAndSettle();

      // The tracker's own preview goes through the renderer under test.
      expect(find.byType(TextField), findsNothing);
      expect(find.byType(GptMarkdown), findsOneWidget);
      expect(
        tester.widget<GptMarkdown>(find.byType(GptMarkdown)).data,
        '# Heading',
      );
    });

    testWidgets('says so when there is nothing to preview', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(_wrap(MarkdownEditor(controller: controller)));
      await tester.tap(find.text('Preview'));
      await tester.pumpAndSettle();

      expect(find.text('Nothing to preview'), findsOneWidget);
    });
  });
}
