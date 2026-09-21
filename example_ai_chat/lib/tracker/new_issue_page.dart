import 'package:flutter/material.dart';

import 'markdown_editor.dart';
import 'models.dart';
import 'tracker_api.dart';
import 'widgets.dart';

/// The new-issue form.
///
/// When it is opened from a reply, [markdown] holds the output that rendered
/// wrong and [requestId] the exchange that produced it, so the issue carries
/// its own reproduction rather than a description of one.
class NewIssuePage extends StatefulWidget {
  const NewIssuePage({
    super.key,
    required this.api,
    this.initialTitle = '',
    this.initialBody = '',
    this.markdown,
    this.requestId,
    this.initialLabels = const {},
  });

  final TrackerApi api;
  final String initialTitle;
  final String initialBody;
  final String? markdown;
  final int? requestId;
  final Set<String> initialLabels;

  @override
  State<NewIssuePage> createState() => _NewIssuePageState();
}

class _NewIssuePageState extends State<NewIssuePage> {
  late final _title = TextEditingController(text: widget.initialTitle);
  late final _body = TextEditingController(text: widget.initialBody);
  late Set<String> _labels = {...widget.initialLabels};

  List<IssueLabel> _available = const [];
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadLabels();
  }

  Future<void> _loadLabels() async {
    try {
      final labels = await widget.api.labels();
      if (mounted) setState(() => _available = labels);
    } catch (_) {
      // Submitting still works; only the label chips are missing.
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final title = _title.text.trim();
    if (title.isEmpty) {
      setState(() => _error = 'A title is required.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final issue = await widget.api.createIssue(
        title: title,
        body: _body.text,
        labels: _labels.toList(),
        requestId: widget.requestId,
        markdown: widget.markdown,
      );
      if (mounted) Navigator.of(context).pop(issue);
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error.toString();
          _submitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('New issue')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 860),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _title,
                  autofocus: true,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: 'Title',
                    hintText: 'Tables lose their column alignment',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                MarkdownEditor(
                  controller: _body,
                  hintText:
                      'What did you expect, and what did the renderer do?',
                ),
                if (widget.markdown != null) ...[
                  const SizedBox(height: 20),
                  _attachment(theme),
                ],
                const SizedBox(height: 20),
                Text('Labels', style: theme.textTheme.titleSmall),
                const SizedBox(height: 8),
                LabelPicker(
                  available: _available,
                  selected: _labels,
                  onChanged: (next) => setState(() => _labels = next),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  SelectableText(
                    _error!,
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ],
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed:
                          _submitting
                              ? null
                              : () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 12),
                    FilledButton.icon(
                      onPressed: _submitting ? null : _submit,
                      style: FilledButton.styleFrom(
                        backgroundColor: IssueColors.open,
                        foregroundColor: Colors.white,
                      ),
                      icon:
                          _submitting
                              ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                              : const Icon(Icons.check, size: 18),
                      label: const Text('Submit new issue'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// The captured output, shown as source — this is the reproduction, so it
  /// is deliberately not rendered here.
  Widget _attachment(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        border: Border.all(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.attachment, size: 16),
              const SizedBox(width: 8),
              Text(
                'Attached output'
                '${widget.requestId != null ? ' from request #${widget.requestId}' : ''}',
                style: theme.textTheme.titleSmall,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${widget.markdown!.length} characters of Markdown, stored with '
            'the issue so it can be re-rendered after a fix.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 180),
            child: SingleChildScrollView(
              child: SelectableText(
                widget.markdown!,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
