import 'package:flutter/material.dart';

import 'issue_detail_page.dart';
import 'models.dart';
import 'new_issue_page.dart';
import 'tracker_api.dart';
import 'widgets.dart';

/// The issue list, laid out the way GitHub's is: a search box, an Open/Closed
/// pair with counts that stay visible on both tabs, label and sort filters,
/// and one row per issue.
class IssuesPage extends StatefulWidget {
  const IssuesPage({super.key, required this.api});

  final TrackerApi api;

  @override
  State<IssuesPage> createState() => _IssuesPageState();
}

class _IssuesPageState extends State<IssuesPage> {
  final _search = TextEditingController();

  String _state = 'open';
  String _label = '';
  String _sort = 'newest';

  Future<IssuePage>? _future;
  List<IssueLabel> _labels = const [];

  @override
  void initState() {
    super.initState();
    _reload();
    _loadLabels();
  }

  /// The label filter is a convenience; if the tracker is unreachable the
  /// list below reports it, so failing quietly here is right.
  Future<void> _loadLabels() async {
    try {
      final labels = await widget.api.labels();
      if (mounted) setState(() => _labels = labels);
    } catch (_) {
      // Leave the filter empty.
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _reload() {
    setState(() {
      _future = widget.api.issues(
        state: _state,
        label: _label,
        query: _search.text.trim(),
        sort: _sort,
      );
    });
  }

  Future<void> _openNewIssue() async {
    final created = await Navigator.of(context).push<Issue>(
      MaterialPageRoute(builder: (_) => NewIssuePage(api: widget.api)),
    );
    if (created == null || !mounted) return;
    _reload();
    await _openIssue(created.number);
  }

  Future<void> _openIssue(int number) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => IssueDetailPage(api: widget.api, number: number),
      ),
    );
    if (mounted) _reload();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Issues'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _reload,
            icon: const Icon(Icons.refresh),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12, left: 4),
            child: FilledButton.icon(
              onPressed: _openNewIssue,
              style: FilledButton.styleFrom(
                backgroundColor: IssueColors.open,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('New issue'),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _filters(theme),
          const Divider(height: 1),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => _reload(),
              child: FutureBuilder<IssuePage>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return EmptyState(
                      icon: Icons.cloud_off,
                      title: 'Cannot reach the tracker',
                      body:
                          '${snapshot.error}\n\n'
                          'The issue tracker lives in the ai-testing proxy. '
                          'Start it with `npm start`.',
                      action: FilledButton(
                        onPressed: _reload,
                        child: const Text('Try again'),
                      ),
                    );
                  }
                  final page = snapshot.data!;
                  return Column(
                    children: [
                      _stateTabs(theme, page),
                      const Divider(height: 1),
                      Expanded(
                        child:
                            page.issues.isEmpty
                                ? EmptyState(
                                  icon: Icons.check_circle_outline,
                                  title: 'No $_state issues',
                                  body:
                                      _search.text.isEmpty && _label.isEmpty
                                          ? 'Report a rendering problem from the '
                                              'chat screen and it appears here.'
                                          : 'Nothing matches the current filters.',
                                )
                                : ListView.separated(
                                  itemCount: page.issues.length,
                                  separatorBuilder:
                                      (_, _) => const Divider(height: 1),
                                  itemBuilder:
                                      (context, index) => _IssueRow(
                                        issue: page.issues[index],
                                        onTap:
                                            () => _openIssue(
                                              page.issues[index].number,
                                            ),
                                        onLabelTap: (name) {
                                          setState(() => _label = name);
                                          _reload();
                                        },
                                      ),
                                ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _filters(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _search,
              onSubmitted: (_) => _reload(),
              decoration: InputDecoration(
                hintText: 'Search issues',
                prefixIcon: const Icon(Icons.search, size: 20),
                isDense: true,
                suffixIcon:
                    _search.text.isEmpty
                        ? null
                        : IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _search.clear();
                            _reload();
                          },
                        ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          DropdownButton<String>(
            value: _label.isEmpty ? null : _label,
            hint: const Text('Label'),
            underline: const SizedBox.shrink(),
            items: [
              const DropdownMenuItem(value: '', child: Text('All labels')),
              for (final label in _labels)
                DropdownMenuItem(value: label.name, child: Text(label.name)),
            ],
            onChanged: (value) {
              setState(() => _label = value ?? '');
              _reload();
            },
          ),
          const SizedBox(width: 12),
          DropdownButton<String>(
            value: _sort,
            underline: const SizedBox.shrink(),
            items: const [
              DropdownMenuItem(value: 'newest', child: Text('Newest')),
              DropdownMenuItem(value: 'oldest', child: Text('Oldest')),
              DropdownMenuItem(
                value: 'updated',
                child: Text('Recently updated'),
              ),
              DropdownMenuItem(
                value: 'comments',
                child: Text('Most commented'),
              ),
            ],
            onChanged: (value) {
              setState(() => _sort = value ?? 'newest');
              _reload();
            },
          ),
        ],
      ),
    );
  }

  /// Both counts stay visible whichever tab is selected, as on GitHub.
  Widget _stateTabs(ThemeData theme, IssuePage page) {
    Widget tab(String value, IconData icon, int count, String label) {
      final selected = _state == value;
      return TextButton.icon(
        onPressed: () {
          setState(() => _state = value);
          _reload();
        },
        icon: Icon(icon, size: 16),
        label: Text('$count $label'),
        style: TextButton.styleFrom(
          foregroundColor:
              selected
                  ? theme.colorScheme.onSurface
                  : theme.colorScheme.onSurfaceVariant,
          textStyle: TextStyle(
            fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
      child: Row(
        children: [
          tab('open', Icons.error_outline, page.open, 'Open'),
          tab('closed', Icons.check_circle_outline, page.closed, 'Closed'),
          const Spacer(),
          if (_label.isNotEmpty)
            TextButton.icon(
              onPressed: () {
                setState(() => _label = '');
                _reload();
              },
              icon: const Icon(Icons.clear, size: 16),
              label: Text('label: $_label'),
            ),
        ],
      ),
    );
  }
}

/// One row of the list: state icon, title with labels, and the "#3 opened …"
/// subtitle GitHub shows.
class _IssueRow extends StatelessWidget {
  const _IssueRow({
    required this.issue,
    required this.onTap,
    required this.onLabelTap,
  });

  final Issue issue;
  final VoidCallback onTap;
  final void Function(String label) onLabelTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(
                IssueColors.iconForState(issue.state),
                size: 18,
                color: IssueColors.forState(issue.state),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        issue.title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      for (final label in issue.labels)
                        LabelChip(
                          label: label,
                          onTap: () => onLabelTap(label.name),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '#${issue.number} '
                    '${issue.isOpen ? 'opened' : 'closed'} '
                    '${relativeTime(issue.isOpen ? issue.createdAt : (issue.closedAt ?? issue.updatedAt))} '
                    'by ${issue.author}'
                    '${issue.requestId != null ? ' · request #${issue.requestId}' : ''}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (issue.commentCount > 0)
              Padding(
                padding: const EdgeInsets.only(left: 12, top: 2),
                child: Row(
                  children: [
                    Icon(
                      Icons.mode_comment_outlined,
                      size: 15,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${issue.commentCount}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
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
}
