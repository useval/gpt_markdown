import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

import 'markdown_editor.dart';
import 'models.dart';
import 'tracker_api.dart';
import 'widgets.dart';

/// One issue: the body, the captured output that caused it, the conversation,
/// and the controls to label, close and reopen it.
class IssueDetailPage extends StatefulWidget {
  const IssueDetailPage({super.key, required this.api, required this.number});

  final TrackerApi api;
  final int number;

  @override
  State<IssueDetailPage> createState() => _IssueDetailPageState();
}

class _IssueDetailPageState extends State<IssueDetailPage> {
  final _comment = TextEditingController();

  Issue? _issue;
  List<IssueLabel> _labels = const [];
  Object? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final issue = await widget.api.issue(widget.number);
      List<IssueLabel> labels = _labels;
      if (labels.isEmpty) {
        try {
          labels = await widget.api.labels();
        } catch (_) {
          labels = const [];
        }
      }
      if (!mounted) return;
      setState(() {
        _issue = issue;
        _labels = labels;
        _error = null;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  /// Runs a mutation, then reloads so the timeline shows what it produced.
  Future<void> _mutate(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
      await _load();
    } catch (error) {
      if (mounted) _snack('$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }

  Future<void> _submitComment({bool alsoToggleState = false}) async {
    final body = _comment.text.trim();
    final issue = _issue;
    if (issue == null) return;
    if (body.isEmpty && !alsoToggleState) return;

    await _mutate(() async {
      if (body.isNotEmpty) await widget.api.comment(issue.number, body);
      if (alsoToggleState) {
        await widget.api.updateIssue(
          issue.number,
          state: issue.isOpen ? 'closed' : 'open',
        );
      }
    });
    _comment.clear();
  }

  Future<void> _editLabels() async {
    final issue = _issue;
    if (issue == null) return;
    var selected = {for (final label in issue.labels) label.name};

    final result = await showDialog<Set<String>>(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setDialogState) => AlertDialog(
                  title: const Text('Labels'),
                  content: SizedBox(
                    width: 380,
                    child: SingleChildScrollView(
                      child: LabelPicker(
                        available: _labels,
                        selected: selected,
                        onChanged:
                            (next) => setDialogState(() => selected = next),
                      ),
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.of(context).pop(selected),
                      child: const Text('Apply'),
                    ),
                  ],
                ),
          ),
    );
    if (result == null) return;
    await _mutate(() => widget.api.setLabels(issue.number, result.toList()));
  }

  Future<void> _editIssue() async {
    final issue = _issue;
    if (issue == null) return;
    final title = TextEditingController(text: issue.title);
    final body = TextEditingController(text: issue.body);

    final saved = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Edit issue'),
            content: SizedBox(
              width: 560,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: title,
                      decoration: const InputDecoration(labelText: 'Title'),
                    ),
                    const SizedBox(height: 16),
                    MarkdownEditor(controller: body, minLines: 6),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Save'),
              ),
            ],
          ),
    );
    if (saved != true) return;
    await _mutate(
      () => widget.api.updateIssue(
        issue.number,
        title: title.text.trim(),
        body: body.text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final issue = _issue;

    return Scaffold(
      appBar: AppBar(
        title: Text('Issue #${widget.number}'),
        actions: [
          if (issue != null)
            IconButton(
              tooltip: 'Edit',
              onPressed: _busy ? null : _editIssue,
              icon: const Icon(Icons.edit_outlined),
            ),
          if (issue != null)
            IconButton(
              tooltip: 'Labels',
              onPressed: _busy ? null : _editLabels,
              icon: const Icon(Icons.label_outline),
            ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body:
          _error != null
              ? EmptyState(
                icon: Icons.cloud_off,
                title: 'Cannot load issue #${widget.number}',
                body: '$_error',
                action: FilledButton(
                  onPressed: _load,
                  child: const Text('Try again'),
                ),
              )
              : issue == null
              ? const Center(child: CircularProgressIndicator())
              : _content(theme, issue),
    );
  }

  Widget _content(ThemeData theme, Issue issue) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 860),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SelectableText(
                  issue.title,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '#${issue.number}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    StateBadge(state: issue.state),
                    Text(
                      '${issue.author} opened this ${relativeTime(issue.createdAt)} · '
                      '${issue.commentCount} comment${issue.commentCount == 1 ? '' : 's'}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                if (issue.labels.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final label in issue.labels) LabelChip(label: label),
                    ],
                  ),
                ],
                const SizedBox(height: 20),
                _bodyCard(theme, issue),
                if (issue.markdown != null) ...[
                  const SizedBox(height: 20),
                  _reproduction(theme, issue),
                ],
                const SizedBox(height: 20),
                for (final entry in issue.timeline) ...[
                  entry.isComment
                      ? _commentCard(theme, entry)
                      : _eventRow(theme, entry),
                  const SizedBox(height: 16),
                ],
                const Divider(height: 40),
                _composer(theme, issue),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _bodyCard(ThemeData theme, Issue issue) {
    return _card(
      theme,
      header: Row(
        children: [
          AuthorAvatar(author: issue.author),
          const SizedBox(width: 10),
          Text(
            '${issue.author} commented ${relativeTime(issue.createdAt)}',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
      child:
          issue.body.trim().isEmpty
              ? Text(
                'No description provided.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontStyle: FontStyle.italic,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              )
              : GptMarkdown(issue.body),
    );
  }

  /// The captured output, both rendered and as source.
  ///
  /// Rendering it here is the whole point of the tracker: after a parser
  /// change, reopen the issue and see whether the same input now looks right.
  Widget _reproduction(ThemeData theme, Issue issue) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: true,
          leading: const Icon(Icons.bug_report_outlined),
          title: const Text('Captured output'),
          subtitle: Text(
            '${issue.markdown!.length} characters'
            '${issue.requestId != null ? ' · request #${issue.requestId}' : ''}',
            style: theme.textTheme.bodySmall,
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _sectionLabel(theme, 'Rendered now'),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: GptMarkdown(issue.markdown!),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: _sectionLabel(theme, 'Source')),
                      IconButton(
                        tooltip: 'Copy source',
                        iconSize: 18,
                        onPressed: () {
                          Clipboard.setData(
                            ClipboardData(text: issue.markdown!),
                          );
                          _snack('Markdown copied');
                        },
                        icon: const Icon(Icons.copy_all_outlined),
                      ),
                    ],
                  ),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 260),
                    child: SingleChildScrollView(
                      child: SelectableText(
                        issue.markdown!,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(ThemeData theme, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      text.toUpperCase(),
      style: theme.textTheme.labelSmall?.copyWith(
        letterSpacing: 0.8,
        color: theme.colorScheme.onSurfaceVariant,
      ),
    ),
  );

  Widget _commentCard(ThemeData theme, TimelineEntry entry) {
    return _card(
      theme,
      header: Row(
        children: [
          AuthorAvatar(author: entry.author),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${entry.author} commented ${relativeTime(entry.createdAt)}',
              style: theme.textTheme.bodySmall,
            ),
          ),
          IconButton(
            tooltip: 'Delete comment',
            iconSize: 16,
            onPressed:
                _busy
                    ? null
                    : () => _mutate(() => widget.api.deleteComment(entry.id)),
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      child: GptMarkdown(entry.body),
    );
  }

  /// The non-comment half of the timeline, rendered as GitHub's inline row
  /// rather than a card.
  Widget _eventRow(ThemeData theme, TimelineEntry entry) {
    final (IconData icon, Color color, String text) = switch (entry.type) {
      'closed' => (Icons.check_circle, IssueColors.closed, 'closed this'),
      'reopened' => (Icons.error, IssueColors.open, 'reopened this'),
      'labeled' => (
        Icons.label,
        theme.colorScheme.onSurfaceVariant,
        'added the ${entry.detail} label',
      ),
      'unlabeled' => (
        Icons.label_off,
        theme.colorScheme.onSurfaceVariant,
        'removed the ${entry.detail} label',
      ),
      _ => (Icons.circle, theme.colorScheme.onSurfaceVariant, entry.type),
    };

    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '${entry.author} $text ${relativeTime(entry.createdAt)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _composer(ThemeData theme, Issue issue) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MarkdownEditor(controller: _comment, minLines: 4),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            OutlinedButton.icon(
              onPressed:
                  _busy ? null : () => _submitComment(alsoToggleState: true),
              icon: Icon(
                issue.isOpen ? Icons.check_circle_outline : Icons.error_outline,
                size: 18,
              ),
              label: Text(
                _comment.text.trim().isEmpty
                    ? (issue.isOpen ? 'Close issue' : 'Reopen issue')
                    : (issue.isOpen
                        ? 'Close with comment'
                        : 'Reopen with comment'),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor:
                    issue.isOpen ? IssueColors.closed : IssueColors.open,
              ),
            ),
            const SizedBox(width: 12),
            FilledButton(
              onPressed: _busy ? null : () => _submitComment(),
              style: FilledButton.styleFrom(
                backgroundColor: IssueColors.open,
                foregroundColor: Colors.white,
              ),
              child: const Text('Comment'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _card(
    ThemeData theme, {
    required Widget header,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.4,
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(7),
              ),
            ),
            child: header,
          ),
          const Divider(height: 1),
          Padding(padding: const EdgeInsets.all(16), child: child),
        ],
      ),
    );
  }
}
