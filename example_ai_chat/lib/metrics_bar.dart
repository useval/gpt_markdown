import 'package:flutter/material.dart';

import 'render_metrics.dart';

/// The live readout under the Markdown surface.
///
/// Frame numbers are only meaningful in a profile or release build — a debug
/// build spends most of a frame in assertions and unoptimised code, so the
/// bar says so rather than letting a 40 ms debug frame read as a renderer
/// problem.
class MetricsBar extends StatelessWidget {
  const MetricsBar({
    super.key,
    required this.metrics,
    required this.isStreaming,
  });

  final RenderMetrics metrics;
  final bool isStreaming;

  static const bool _isDebug =
      !bool.fromEnvironment('dart.vm.product') &&
      !bool.fromEnvironment('dart.vm.profile');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final seconds = metrics.elapsed.inMilliseconds / 1000;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        border: Border(
          top: BorderSide(color: theme.dividerColor.withValues(alpha: 0.4)),
        ),
      ),
      child: Row(
        children: [
          _LiveDot(active: isStreaming),
          const SizedBox(width: 10),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _stat(
                    theme,
                    'ttft',
                    metrics.timeToFirstToken == null
                        ? '—'
                        : '${metrics.timeToFirstToken!.inMilliseconds} ms',
                  ),
                  _stat(theme, 'elapsed', '${seconds.toStringAsFixed(1)} s'),
                  _stat(theme, 'chars', '${metrics.characters}'),
                  _stat(
                    theme,
                    'chars/s',
                    metrics.charsPerSecond.toStringAsFixed(0),
                  ),
                  _stat(theme, 'chunks', '${metrics.chunks}'),
                  _stat(theme, 'frames', '${metrics.frames}'),
                  _stat(
                    theme,
                    'avg frame',
                    '${metrics.avgFrameMs.toStringAsFixed(1)} ms',
                  ),
                  _stat(
                    theme,
                    'p95 frame',
                    '${metrics.p95FrameMs.toStringAsFixed(1)} ms',
                    warn: metrics.p95FrameMs > 16.7,
                  ),
                  _stat(
                    theme,
                    'jank',
                    '${metrics.jankFrames} '
                        '(${(metrics.jankRatio * 100).toStringAsFixed(0)}%)',
                    warn: metrics.jankRatio > 0.1,
                  ),
                ],
              ),
            ),
          ),
          if (_isDebug)
            Tooltip(
              message:
                  'Debug build — frame times are not representative.\n'
                  'Measure with: flutter run --profile',
              child: Icon(Icons.info_outline, size: 16, color: muted),
            ),
        ],
      ),
    );
  }

  Widget _stat(
    ThemeData theme,
    String label,
    String value, {
    bool warn = false,
  }) {
    final color = warn ? theme.colorScheme.error : theme.colorScheme.onSurface;
    return Padding(
      padding: const EdgeInsets.only(right: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            value,
            style: theme.textTheme.labelMedium?.copyWith(
              color: color,
              fontFeatures: const [FontFeature.tabularFigures()],
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// A dot that pulses while a reply is streaming, so a stalled stream is
/// distinguishable from a finished one at a glance.
class _LiveDot extends StatelessWidget {
  const _LiveDot({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color:
            active
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
      ),
    );
  }
}
