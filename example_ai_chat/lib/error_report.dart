import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import 'chat_config.dart';

/// Builds the text shown — and copied — when a request fails.
///
/// The message alone is rarely enough to act on ("HTTP 404" says nothing), so
/// the endpoint, model and renderer settings travel with it. The API key
/// never does: an error report gets pasted into chats and issue trackers.
String buildErrorReport({
  required String message,
  required ChatConfig config,
  required bool incremental,
  required bool fadeReveal,
  TargetPlatform? platformOverride,
  bool? isWebOverride,
}) {
  final isWeb = isWebOverride ?? kIsWeb;
  final platform = platformOverride ?? defaultTargetPlatform;
  final hasAuth = config.apiKey.trim().isNotEmpty;
  return (StringBuffer()
        ..writeln(message.trim())
        ..writeln()
        ..writeln('endpoint: ${config.chatCompletionsUri}')
        ..writeln('model:    ${config.model}')
        ..writeln('auth:     ${hasAuth ? 'bearer token set' : 'none'}')
        ..writeln('platform: ${isWeb ? 'web' : platform.name}')
        ..write('renderer: incremental=$incremental fade=$fadeReveal'))
      .toString();
}

/// The failure state of the chat surface.
///
/// The report is selectable *and* has a copy button — selecting text on a
/// touch screen is fiddly, and this is the one screen a reader most wants to
/// send to someone else.
class ErrorReportView extends StatelessWidget {
  const ErrorReportView({
    super.key,
    required this.report,
    required this.onRetry,
    required this.onSettings,
  });

  final String report;
  final VoidCallback onRetry;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline,
                size: 40,
                color: theme.colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text('Request failed', style: theme.textTheme.titleMedium),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer.withValues(
                    alpha: 0.25,
                  ),
                  border: Border.all(
                    color: theme.colorScheme.error.withValues(alpha: 0.4),
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SelectableText(
                  report,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: report));
                      if (!context.mounted) return;
                      ScaffoldMessenger.maybeOf(context)
                        ?..hideCurrentSnackBar()
                        ..showSnackBar(
                          const SnackBar(
                            content: Text('Error copied to clipboard'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                    },
                    icon: const Icon(Icons.copy_all_outlined, size: 18),
                    label: const Text('Copy error'),
                  ),
                  OutlinedButton.icon(
                    onPressed: onSettings,
                    icon: const Icon(Icons.settings_outlined, size: 18),
                    label: const Text('Settings'),
                  ),
                  FilledButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
