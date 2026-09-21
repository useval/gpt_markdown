import 'package:flutter/material.dart';

import 'models.dart';

/// GitHub's issue colours, which carry meaning the text repeats: green is
/// open, purple is closed.
class IssueColors {
  static const open = Color(0xFF1A7F37);
  static const closed = Color(0xFF8250DF);

  static Color forState(String state) => state == 'open' ? open : closed;
  static IconData iconForState(String state) =>
      state == 'open' ? Icons.error_outline : Icons.check_circle_outline;
}

/// The Open/Closed pill shown at the top of an issue.
class StateBadge extends StatelessWidget {
  const StateBadge({super.key, required this.state, this.compact = false});

  final String state;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = IssueColors.forState(state);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 12,
        vertical: compact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            IssueColors.iconForState(state),
            size: compact ? 12 : 16,
            color: Colors.white,
          ),
          const SizedBox(width: 6),
          Text(
            state == 'open' ? 'Open' : 'Closed',
            style: TextStyle(
              color: Colors.white,
              fontSize: compact ? 11 : 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// A label chip in the label's own colour, with text picked for contrast.
class LabelChip extends StatelessWidget {
  const LabelChip({
    super.key,
    required this.label,
    this.onTap,
    this.selected = false,
  });

  final IssueLabel label;
  final VoidCallback? onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final swatch = label.swatch;
    // Relative luminance decides black or white text, so a pale label like
    // `wontfix` stays readable.
    final onSwatch =
        swatch.computeLuminance() > 0.5 ? Colors.black87 : Colors.white;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: swatch,
          borderRadius: BorderRadius.circular(999),
          border:
              selected
                  ? Border.all(
                    color: Theme.of(context).colorScheme.onSurface,
                    width: 2,
                  )
                  : Border.all(color: swatch.withValues(alpha: 0.6)),
        ),
        child: Text(
          label.name,
          style: TextStyle(
            color: onSwatch,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

/// "3 minutes ago" — the relative stamp GitHub uses everywhere.
String relativeTime(DateTime time) {
  final delta = DateTime.now().difference(time.toLocal());
  if (delta.inSeconds < 60) return 'just now';
  if (delta.inMinutes < 60) {
    return '${delta.inMinutes} minute${delta.inMinutes == 1 ? '' : 's'} ago';
  }
  if (delta.inHours < 24) {
    return '${delta.inHours} hour${delta.inHours == 1 ? '' : 's'} ago';
  }
  if (delta.inDays < 30) {
    return '${delta.inDays} day${delta.inDays == 1 ? '' : 's'} ago';
  }
  final months = delta.inDays ~/ 30;
  if (months < 12) return '$months month${months == 1 ? '' : 's'} ago';
  final years = delta.inDays ~/ 365;
  return '$years year${years == 1 ? '' : 's'} ago';
}

/// The circular initial GitHub shows in place of an avatar.
class AuthorAvatar extends StatelessWidget {
  const AuthorAvatar({super.key, required this.author, this.size = 28});

  final String author;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        shape: BoxShape.circle,
      ),
      child: Text(
        author.isEmpty ? '?' : author.characters.first.toUpperCase(),
        style: TextStyle(
          color: scheme.onPrimaryContainer,
          fontSize: size * 0.45,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// The empty state used across the tracker pages.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.action,
  });

  final IconData icon;
  final String title;
  final String body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              body,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (action != null) ...[const SizedBox(height: 20), action!],
          ],
        ),
      ),
    );
  }
}
