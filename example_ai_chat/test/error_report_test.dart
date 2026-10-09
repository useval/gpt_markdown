import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_markdown_ai_chat/chat_config.dart';
import 'package:gpt_markdown_ai_chat/error_report.dart';

const _config = ChatConfig(
  baseUrl: 'http://localhost:8787/v1',
  apiKey: 'secret-key-value',
  model: 'gpt-4o-mini',
  systemPrompt: '',
);

String _report({ChatConfig config = _config}) => buildErrorReport(
  message: 'HTTP 401: Incorrect API key provided',
  config: config,
  incremental: true,
  fadeReveal: false,
  platformOverride: TargetPlatform.macOS,
  isWebOverride: false,
);

void main() {
  group('buildErrorReport', () {
    test('carries the context needed to act on the failure', () {
      expect(_report(), '''
HTTP 401: Incorrect API key provided

endpoint: http://localhost:8787/v1/chat/completions
model:    gpt-4o-mini
auth:     bearer token set
platform: macOS
renderer: incremental=true fade=false''');
    });

    test('never includes the API key', () {
      expect(_report(), isNot(contains('secret-key-value')));
    });

    test('says so when no key or token is set', () {
      expect(
        _report(config: _config.copyWith(apiKey: '  ')),
        contains('auth:     none'),
      );
    });
  });

  group('ErrorReportView', () {
    testWidgets('shows the report as selectable text', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ErrorReportView(
              report: _report(),
              onRetry: () {},
              onSettings: () {},
            ),
          ),
        ),
      );

      expect(find.text('Request failed'), findsOneWidget);
      final selectable = tester.widget<SelectableText>(
        find.byType(SelectableText),
      );
      expect(selectable.data, contains('Incorrect API key provided'));
      expect(selectable.data, contains('endpoint: '));
    });

    testWidgets('copies the whole report to the clipboard', (tester) async {
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
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
            body: ErrorReportView(
              report: _report(),
              onRetry: () {},
              onSettings: () {},
            ),
          ),
        ),
      );

      await tester.tap(find.text('Copy error'));
      await tester.pumpAndSettle();

      expect(copied, _report());
      expect(find.text('Error copied to clipboard'), findsOneWidget);
    });

    testWidgets('retry and settings fire their callbacks', (tester) async {
      var retried = 0;
      var settings = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ErrorReportView(
              report: _report(),
              onRetry: () => retried++,
              onSettings: () => settings++,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Retry'));
      await tester.tap(find.text('Settings'));
      await tester.pump();

      expect(retried, 1);
      expect(settings, 1);
    });
  });
}
