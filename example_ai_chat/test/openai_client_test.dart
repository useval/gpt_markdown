@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_markdown_ai_chat/chat_config.dart';
import 'package:gpt_markdown_ai_chat/openai_client.dart';

/// Serves a canned SSE reply so the wire handling is testable without a
/// provider or a key.
Future<HttpServer> _sseServer(List<String> events, {int status = 200}) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((request) async {
    await request.drain<void>();
    request.response.statusCode = status;
    request.response.headers.contentType = ContentType('text', 'event-stream');
    for (final event in events) {
      request.response.write('$event\n\n');
      await request.response.flush();
    }
    await request.response.close();
  });
  return server;
}

ChatConfig _configFor(HttpServer server) => ChatConfig(
  baseUrl: 'http://${server.address.host}:${server.port}/v1',
  apiKey: '',
  model: 'test-model',
  systemPrompt: '',
);

String _chunk(String content) =>
    'data: ${jsonEncode({
      'choices': [
        {
          'delta': {'content': content},
        },
      ],
    })}';

void main() {
  test('yields content deltas and stops at [DONE]', () async {
    final server = await _sseServer([
      ': keep-alive',
      _chunk('# Hi'),
      _chunk('\n\nrest'),
      'data: [DONE]',
      _chunk('after done'),
    ]);
    addTearDown(() => server.close(force: true));

    final deltas =
        await OpenAiClient()
            .stream(
              config: _configFor(server),
              history: const [ChatMessage.user('hello')],
            )
            .toList();

    expect(deltas.join(), '# Hi\n\nrest');
  });

  test('skips a malformed chunk instead of failing the stream', () async {
    final server = await _sseServer([
      _chunk('a'),
      'data: {not json',
      'data: {"choices":[]}',
      _chunk('b'),
      'data: [DONE]',
    ]);
    addTearDown(() => server.close(force: true));

    final deltas =
        await OpenAiClient()
            .stream(
              config: _configFor(server),
              history: const [ChatMessage.user('hello')],
            )
            .toList();

    expect(deltas.join(), 'ab');
  });

  test('surfaces the provider error message on a non-2xx response', () async {
    final server = await _sseServer([
      jsonEncode({
        'error': {'message': 'Incorrect API key provided'},
      }),
    ], status: 401);
    addTearDown(() => server.close(force: true));

    await expectLater(
      OpenAiClient()
          .stream(
            config: _configFor(server),
            history: const [ChatMessage.user('hello')],
          )
          .toList(),
      throwsA(
        isA<ChatRequestException>().having(
          (e) => e.toString(),
          'message',
          contains('Incorrect API key provided'),
        ),
      ),
    );
  });
}
