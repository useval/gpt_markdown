import 'package:flutter/material.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

import 'models.dart';
import 'new_issue_page.dart';
import 'tracker_api.dart';
import 'widgets.dart';

/// The transcript: every request the proxy has handled, newest first.
///
/// Its job is to get from "that reply looked wrong" to an issue carrying the
/// exact Markdown, without having to reproduce anything.
class RequestsPage extends StatefulWidget {
  const RequestsPage({super.key, required this.api});

  final TrackerApi api;

  @override
  State<RequestsPage> createState() => _RequestsPageState();
}

class _RequestsPageState extends State<RequestsPage> {
  final _search = TextEditingController();
  Future<List<RequestLog>>? _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _reload() {
    setState(() {
      _future = widget.api.requests(query: _search.text.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('History'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _reload,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _search,
              onSubmitted: (_) => _reload(),
              decoration: InputDecoration(
                hintText: 'Search prompts and replies',
                prefixIcon: const Icon(Icons.search, size: 20),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: FutureBuilder<List<RequestLog>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return EmptyState(
                    icon: Icons.cloud_off,
                    title: 'Cannot reach the tracker',
                    body: '${snapshot.error}',
                    action: FilledButton(
                      onPressed: _reload,
                      child: const Text('Try again'),
                    ),
                  );
                }
                final requests = snapshot.data!;
                if (requests.isEmpty) {
                  return const EmptyState(
                    icon: Icons.history,
                    title: 'Nothing recorded yet',
                    body: 'Every request through the proxy is stored here.',
                  );
                }
                return ListView.separated(
                  itemCount: requests.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final request = requests[index];
                    return ListTile(
                      leading: Icon(
                        request.failed
                            ? Icons.error_outline
                            : Icons.check_circle_outline,
                        color:
                            request.failed
                                ? theme.colorScheme.error
                                : IssueColors.open,
                      ),
                      title: Text(
                        request.prompt.isEmpty ? '(no prompt)' : request.prompt,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '#${request.id} · ${request.model} · '
                        '${relativeTime(request.createdAt)}'
                        '${request.ttftMs != null ? ' · ttft ${request.ttftMs}ms' : ''}'
                        '${request.failed ? ' · ${request.error}' : ' · ${request.responseChars} chars'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap:
                          () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder:
                                  (_) => RequestDetailPage(
                                    api: widget.api,
                                    id: request.id,
                                  ),
                            ),
                          ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// One recorded exchange, with the reply rendered and a shortcut to file an
/// issue against it.
class RequestDetailPage extends StatefulWidget {
  const RequestDetailPage({super.key, required this.api, required this.id});

  final TrackerApi api;
  final int id;

  @override
  State<RequestDetailPage> createState() => _RequestDetailPageState();
}

class _RequestDetailPageState extends State<RequestDetailPage> {
  Future<RequestLog>? _future;

  @override
  void initState() {
    super.initState();
    _future = widget.api.request(widget.id);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text('Request #${widget.id}')),
      body: FutureBuilder<RequestLog>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return EmptyState(
              icon: Icons.cloud_off,
              title: 'Cannot load request #${widget.id}',
              body: '${snapshot.error}',
            );
          }
          final request = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 860),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Prompt', style: theme.textTheme.titleSmall),
                      const SizedBox(height: 8),
                      SelectableText(request.prompt),
                      const SizedBox(height: 8),
                      Text(
                        '${request.model} · ${relativeTime(request.createdAt)} · '
                        'status ${request.status ?? '—'} · '
                        '${request.chunkCount} chunks · '
                        'ttft ${request.ttftMs ?? '—'}ms · '
                        '${request.durationMs ?? '—'}ms total',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (request.error != null) ...[
                        const SizedBox(height: 16),
                        SelectableText(
                          request.error!,
                          style: TextStyle(color: theme.colorScheme.error),
                        ),
                      ],
                      const Divider(height: 40),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Reply',
                              style: theme.textTheme.titleSmall,
                            ),
                          ),
                          if ((request.response ?? '').isNotEmpty)
                            FilledButton.icon(
                              onPressed:
                                  () => Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder:
                                          (_) => NewIssuePage(
                                            api: widget.api,
                                            initialTitle: '',
                                            markdown: request.response,
                                            requestId: request.id,
                                            initialLabels: const {'bug'},
                                          ),
                                    ),
                                  ),
                              style: FilledButton.styleFrom(
                                backgroundColor: IssueColors.open,
                                foregroundColor: Colors.white,
                              ),
                              icon: const Icon(Icons.bug_report, size: 18),
                              label: const Text('Report issue'),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if ((request.response ?? '').isEmpty)
                        Text(
                          'No reply was recorded.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontStyle: FontStyle.italic,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        )
                      else
                        GptMarkdown(request.response!),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
