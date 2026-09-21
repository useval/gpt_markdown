import 'package:flutter/material.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

/// A Markdown field with GitHub's Write / Preview pair.
///
/// The preview is a real `GptMarkdown`, which is the point: the tracker for
/// the renderer is itself rendered by the renderer.
class MarkdownEditor extends StatefulWidget {
  const MarkdownEditor({
    super.key,
    required this.controller,
    this.hintText = 'Leave a comment',
    this.minLines = 5,
    this.maxLines = 14,
  });

  final TextEditingController controller;
  final String hintText;
  final int minLines;
  final int maxLines;

  @override
  State<MarkdownEditor> createState() => _MarkdownEditorState();
}

class _MarkdownEditorState extends State<MarkdownEditor> {
  bool _preview = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            _tab('Write', !_preview, () => setState(() => _preview = false)),
            _tab('Preview', _preview, () => setState(() => _preview = true)),
          ],
        ),
        const SizedBox(height: 8),
        if (_preview)
          Container(
            width: double.infinity,
            constraints: BoxConstraints(minHeight: widget.minLines * 24.0),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: theme.dividerColor),
              borderRadius: BorderRadius.circular(8),
            ),
            child:
                widget.controller.text.trim().isEmpty
                    ? Text(
                      'Nothing to preview',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    )
                    : GptMarkdown(widget.controller.text),
          )
        else
          TextField(
            controller: widget.controller,
            minLines: widget.minLines,
            maxLines: widget.maxLines,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
            decoration: InputDecoration(
              hintText: widget.hintText,
              alignLabelWithHint: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
      ],
    );
  }

  Widget _tab(String label, bool selected, VoidCallback onTap) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          backgroundColor:
              selected
                  ? theme.colorScheme.surfaceContainerHighest
                  : Colors.transparent,
          foregroundColor:
              selected
                  ? theme.colorScheme.onSurface
                  : theme.colorScheme.onSurfaceVariant,
        ),
        child: Text(label),
      ),
    );
  }
}

/// Chips for picking labels, used by both the new-issue and detail pages.
class LabelPicker extends StatelessWidget {
  const LabelPicker({
    super.key,
    required this.available,
    required this.selected,
    required this.onChanged,
  });

  final List<dynamic> available;
  final Set<String> selected;
  final void Function(Set<String>) onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final label in available)
          FilterChip(
            label: Text(label.name as String),
            selected: selected.contains(label.name),
            avatar: CircleAvatar(
              backgroundColor: label.swatch as Color,
              radius: 7,
            ),
            onSelected: (on) {
              final next = Set<String>.from(selected);
              if (on) {
                next.add(label.name as String);
              } else {
                next.remove(label.name as String);
              }
              onChanged(next);
            },
          ),
      ],
    );
  }
}
