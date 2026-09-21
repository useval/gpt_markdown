import 'package:flutter/foundation.dart';

/// Connection settings for an OpenAI-protocol endpoint.
///
/// The default points at the `ai-testing` proxy, which sits next to
/// `gpt_markdown/` and holds the provider key server-side so this app never
/// carries one:
///
/// ```
/// cd ../../ai-testing && OPENAI_API_KEY=sk-... npm start
/// flutter run -d macos
/// ```
///
/// Everything is overridable with `--dart-define`, so the app can also talk
/// to a provider directly:
///
/// ```
/// flutter run -d macos \
///   --dart-define=OPENAI_BASE_URL=https://api.openai.com/v1 \
///   --dart-define=OPENAI_API_KEY=sk-... \
///   --dart-define=OPENAI_MODEL=gpt-4o-mini
/// ```
///
/// Whatever is set here is held in memory only — this harness never writes a
/// key or a token to disk.
class ChatConfig {
  const ChatConfig({
    required this.baseUrl,
    required this.apiKey,
    required this.model,
    required this.systemPrompt,
  });

  /// The values baked in at build time, used for the first request.
  factory ChatConfig.fromEnvironment() => ChatConfig(
    baseUrl: String.fromEnvironment(
      'OPENAI_BASE_URL',
      defaultValue: defaultProxyBaseUrl,
    ),
    apiKey: String.fromEnvironment('OPENAI_API_KEY'),
    model: String.fromEnvironment('OPENAI_MODEL', defaultValue: 'gpt-4o-mini'),
    systemPrompt: defaultSystemPrompt,
  );

  /// Asks for the constructs that actually stress the renderer, so a run
  /// exercises more than paragraphs of prose.
  static const defaultSystemPrompt =
      'You are a helpful assistant. Answer in rich Markdown: use headings, '
      'nested lists, tables, fenced code blocks with a language tag, '
      'blockquotes, and LaTeX in \\( ... \\) and \\[ ... \\] where it helps.';

  /// The local `ai-testing` proxy. An Android emulator reaches the host
  /// machine at 10.0.2.2 rather than localhost, so that build gets the other
  /// address by default.
  static String get defaultProxyBaseUrl =>
      _isAndroid ? 'http://10.0.2.2:8787/v1' : 'http://localhost:8787/v1';

  static final bool _isAndroid =
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  final String baseUrl;

  /// The provider key when talking to a provider directly, or the proxy's
  /// `ACCESS_TOKEN` when talking to `ai-testing`. Both travel as
  /// `Authorization: Bearer`, and neither is needed by default — the proxy
  /// runs on localhost without a token.
  final String apiKey;
  final String model;
  final String systemPrompt;

  /// Whether a request can be attempted at all.
  ///
  /// The `ai-testing` proxy and local servers (Ollama, LM Studio, vLLM) need
  /// no key, so an empty key is only a problem for hosts that ask for one —
  /// which the endpoint itself reports as a 401.
  bool get isConfigured => baseUrl.trim().isNotEmpty && model.trim().isNotEmpty;

  /// `/chat/completions` resolved against [baseUrl], tolerating a trailing
  /// slash and a base that already ends in the path.
  Uri get chatCompletionsUri {
    var base = baseUrl.trim();
    while (base.endsWith('/')) {
      base = base.substring(0, base.length - 1);
    }
    if (base.endsWith('/chat/completions')) {
      return Uri.parse(base);
    }
    return Uri.parse('$base/chat/completions');
  }

  ChatConfig copyWith({
    String? baseUrl,
    String? apiKey,
    String? model,
    String? systemPrompt,
  }) => ChatConfig(
    baseUrl: baseUrl ?? this.baseUrl,
    apiKey: apiKey ?? this.apiKey,
    model: model ?? this.model,
    systemPrompt: systemPrompt ?? this.systemPrompt,
  );
}
