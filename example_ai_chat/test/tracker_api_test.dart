@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_markdown_ai_chat/chat_config.dart';
import 'package:gpt_markdown_ai_chat/tracker/tracker_api.dart';

/// Drives the Dart client against the real Node server, so the two sides of
/// the API are checked against each other rather than against a mock.
void main() {
  // These drive the Dart client against the real Node server so that both
  // sides of the API are checked against each other. That server lives in
  // `ai-testing`, a sibling repository which is not part of this package and
  // is not checked out by CI, so the suite is skipped when it is absent
  // rather than failing. Absent means "not exercised here", not "broken".
  final proxyDir = Directory('../../ai-testing');
  final missingServer =
      proxyDir.existsSync()
          ? null
          : 'ai-testing is not checked out at ${proxyDir.absolute.path}';

  group('tracker api', () {
    late Process server;
    late TrackerApi api;
    late Directory temp;

    setUpAll(() async {
      // A free port, released before the server claims it.
      final probe = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final port = probe.port;
      await probe.close();

      temp = await Directory.systemTemp.createTemp('tracker-test');
      server = await Process.start(
        'node',
        ['src/index.mjs'],
        workingDirectory: proxyDir.path,
        environment: {
          'PORT': '$port',
          'HOST': '127.0.0.1',
          'DB_PATH': '${temp.path}/test.db',
          'LOG_REQUESTS': 'false',
        },
      );

      api = TrackerApi(
        ChatConfig(
          baseUrl: 'http://127.0.0.1:$port/v1',
          apiKey: '',
          model: 'test',
          systemPrompt: '',
        ),
      );

      final deadline = DateTime.now().add(const Duration(seconds: 15));
      while (DateTime.now().isBefore(deadline)) {
        if (await api.ping()) return;
        await Future<void>.delayed(const Duration(milliseconds: 150));
      }
      throw StateError('the ai-testing server did not start');
    });

    tearDownAll(() async {
      api.close();
      server.kill();
      await server.exitCode;
      if (temp.existsSync()) temp.deleteSync(recursive: true);
    });

    test('the seeded labels are available', () async {
      final labels = await api.labels();
      expect(labels.map((l) => l.name), contains('bug'));
      // The colour survives the round trip as a real Color.
      final bug = labels.firstWhere((l) => l.name == 'bug');
      expect(bug.swatch.a, 1.0);
    });

    test('an issue can be opened, discussed, closed and reopened', () async {
      final created = await api.createIssue(
        title: 'Nested task lists lose their checkbox',
        body: 'At the third level the `- [ ]` renders as a bullet.',
        labels: ['bug', 'list'],
        markdown: '- [ ] one\n  - [ ] two\n    - [ ] three',
      );
      expect(created.number, greaterThan(0));
      expect(created.isOpen, isTrue);
      expect(created.labels.map((l) => l.name), ['bug', 'list']);
      expect(created.markdown, contains('three'));

      await api.comment(created.number, 'Only when streaming.');
      final commented = await api.issue(created.number);
      expect(commented.commentCount, 1);
      expect(commented.timeline.single.isComment, isTrue);
      expect(commented.timeline.single.body, 'Only when streaming.');

      final closed = await api.updateIssue(created.number, state: 'closed');
      expect(closed.isOpen, isFalse);
      expect(closed.closedAt, isNotNull);

      final reopened = await api.updateIssue(created.number, state: 'open');
      expect(reopened.isOpen, isTrue);

      final full = await api.issue(created.number);
      expect(full.timeline.map((e) => e.isComment ? 'comment' : e.type), [
        'comment',
        'closed',
        'reopened',
      ]);
    });

    test('labels are replaced with a diff on the timeline', () async {
      final issue = await api.createIssue(
        title: 'LaTeX sits below the baseline',
        labels: ['bug'],
      );
      await api.setLabels(issue.number, ['latex']);

      final updated = await api.issue(issue.number);
      expect(updated.labels.map((l) => l.name), ['latex']);
      expect(
        updated.timeline.map((e) => '${e.type}:${e.detail}'),
        containsAll(['labeled:latex', 'unlabeled:bug']),
      );
    });

    test('the list filters by state, label and text', () async {
      final issue = await api.createIssue(
        title: 'Fenced code drops its language header',
        labels: ['code-block'],
      );
      await api.updateIssue(issue.number, state: 'closed');

      final open = await api.issues();
      expect(open.issues.every((i) => i.isOpen), isTrue);
      expect(open.closed, greaterThanOrEqualTo(1));

      final byLabel = await api.issues(state: 'all', label: 'code-block');
      expect(byLabel.issues.single.number, issue.number);

      final byText = await api.issues(state: 'all', query: 'language header');
      expect(byText.issues.single.number, issue.number);

      final none = await api.issues(
        state: 'all',
        query: 'nothing matches this',
      );
      expect(none.issues, isEmpty);
    });

    test('a comment can be edited and deleted', () async {
      final issue = await api.createIssue(title: 'Editable');
      await api.comment(issue.number, 'first');
      final comment = (await api.issue(issue.number)).timeline.single;

      await api.editComment(comment.id, 'second');
      expect((await api.issue(issue.number)).timeline.single.body, 'second');

      await api.deleteComment(comment.id);
      expect((await api.issue(issue.number)).timeline, isEmpty);
    });

    test('an issue can be deleted', () async {
      final issue = await api.createIssue(title: 'Temporary');
      await api.deleteIssue(issue.number);
      expect(
        () => api.issue(issue.number),
        throwsA(
          isA<TrackerException>().having((e) => e.statusCode, 'status', 404),
        ),
      );
    });

    test('a bad request surfaces the server message', () async {
      expect(
        () => api.createIssue(title: '   '),
        throwsA(
          isA<TrackerException>()
              .having((e) => e.statusCode, 'status', 400)
              .having((e) => e.message, 'message', contains('title')),
        ),
      );
    });
  }, skip: missingServer);
}
