import 'package:material_ui/material_ui.dart';

import 'chat_page.dart';

/// A streaming AI chat harness for `gpt_markdown`.
///
/// The whole screen above the prompt box is one `GptMarkdown` widget fed by an
/// OpenAI-protocol endpoint, so the renderer is measured against real model
/// output rather than a canned string.
///
/// ```
/// flutter run -d macos \
///   --dart-define=OPENAI_API_KEY=sk-... \
///   --dart-define=OPENAI_MODEL=gpt-4o-mini
/// ```
void main() => runApp(const AiChatApp());

class AiChatApp extends StatelessWidget {
  const AiChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'gpt_markdown · streaming harness',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
      home: const ChatPage(),
    );
  }

  ThemeData _theme(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF7C5CFF),
      brightness: brightness,
    );
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      scaffoldBackgroundColor: scheme.surface,
    );
  }
}
