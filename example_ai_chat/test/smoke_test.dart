import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_markdown_ai_chat/chat_config.dart';
import 'package:gpt_markdown_ai_chat/main.dart';

void main() {
  testWidgets('starts on the empty surface with a prompt box', (tester) async {
    await tester.pumpWidget(const AiChatApp());

    expect(find.text('gpt_markdown'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Ask something'), findsOneWidget);
  });

  test('chat completions URL is resolved from the base URL', () {
    const base = ChatConfig(
      baseUrl: 'https://api.openai.com/v1',
      apiKey: '',
      model: 'gpt-4o-mini',
      systemPrompt: '',
    );
    expect(
      base.chatCompletionsUri.toString(),
      'https://api.openai.com/v1/chat/completions',
    );
    // A trailing slash, and a base that already carries the path, both work.
    expect(
      base
          .copyWith(baseUrl: 'http://localhost:11434/v1/')
          .chatCompletionsUri
          .toString(),
      'http://localhost:11434/v1/chat/completions',
    );
    expect(
      base
          .copyWith(baseUrl: 'https://gw.example.com/chat/completions')
          .chatCompletionsUri
          .toString(),
      'https://gw.example.com/chat/completions',
    );
  });
}
