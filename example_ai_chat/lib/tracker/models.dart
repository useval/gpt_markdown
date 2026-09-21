import 'package:flutter/material.dart';

/// A label, with the colour the server stores for it.
class IssueLabel {
  const IssueLabel({
    required this.id,
    required this.name,
    required this.color,
    this.description = '',
  });

  factory IssueLabel.fromJson(Map<String, dynamic> json) => IssueLabel(
    id: json['id'] as int,
    name: json['name'] as String,
    color: json['color'] as String? ?? '#ededed',
    description: json['description'] as String? ?? '',
  );

  final int id;
  final String name;
  final String color;
  final String description;

  /// The stored `#rrggbb`, falling back to grey if it is not parseable.
  Color get swatch {
    final hex = color.replaceFirst('#', '');
    final value = int.tryParse(hex, radix: 16);
    if (value == null || hex.length != 6) return const Color(0xFFEDEDED);
    return Color(0xFF000000 | value);
  }
}

/// An issue. `number` is what the UI shows; it is the row id.
class Issue {
  const Issue({
    required this.number,
    required this.title,
    required this.body,
    required this.state,
    required this.author,
    required this.createdAt,
    required this.updatedAt,
    required this.labels,
    required this.commentCount,
    this.closedAt,
    this.requestId,
    this.markdown,
    this.timeline = const [],
  });

  factory Issue.fromJson(Map<String, dynamic> json) => Issue(
    number: (json['number'] ?? json['id']) as int,
    title: json['title'] as String,
    body: json['body'] as String? ?? '',
    state: json['state'] as String? ?? 'open',
    author: json['author'] as String? ?? 'you',
    createdAt: DateTime.parse(json['created_at'] as String),
    updatedAt: DateTime.parse(json['updated_at'] as String),
    closedAt:
        json['closed_at'] == null
            ? null
            : DateTime.parse(json['closed_at'] as String),
    requestId: json['request_id'] as int?,
    markdown: json['markdown'] as String?,
    labels: [
      for (final label in (json['labels'] as List? ?? const []))
        IssueLabel.fromJson(label as Map<String, dynamic>),
    ],
    commentCount: json['comment_count'] as int? ?? 0,
    timeline: [
      for (final entry in (json['timeline'] as List? ?? const []))
        TimelineEntry.fromJson(entry as Map<String, dynamic>),
    ],
  );

  final int number;
  final String title;
  final String body;
  final String state;
  final String author;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? closedAt;
  final int? requestId;

  /// The output that rendered wrong, captured when the issue was opened.
  final String? markdown;
  final List<IssueLabel> labels;
  final int commentCount;
  final List<TimelineEntry> timeline;

  bool get isOpen => state == 'open';
}

/// One entry in the issue thread: a comment, or something that happened.
class TimelineEntry {
  const TimelineEntry({
    required this.id,
    required this.kind,
    required this.author,
    required this.createdAt,
    this.body = '',
    this.type = '',
    this.detail,
  });

  factory TimelineEntry.fromJson(Map<String, dynamic> json) => TimelineEntry(
    id: json['id'] as int,
    kind: json['kind'] as String,
    author: (json['author'] ?? json['actor'] ?? 'you') as String,
    createdAt: DateTime.parse(json['created_at'] as String),
    body: json['body'] as String? ?? '',
    type: json['type'] as String? ?? '',
    detail: json['detail'] as String?,
  );

  final int id;

  /// `comment` or `event`.
  final String kind;
  final String author;
  final DateTime createdAt;
  final String body;

  /// For events: `closed`, `reopened`, `labeled`, `unlabeled`.
  final String type;
  final String? detail;

  bool get isComment => kind == 'comment';
}

/// One recorded exchange with the model.
class RequestLog {
  const RequestLog({
    required this.id,
    required this.createdAt,
    required this.model,
    required this.prompt,
    this.status,
    this.error,
    this.preview = '',
    this.response,
    this.ttftMs,
    this.durationMs,
    this.chunkCount = 0,
    this.responseChars = 0,
  });

  factory RequestLog.fromJson(Map<String, dynamic> json) => RequestLog(
    id: json['id'] as int,
    createdAt: DateTime.parse(json['created_at'] as String),
    model: json['model'] as String? ?? '',
    prompt: json['prompt'] as String? ?? '',
    status: json['status'] as int?,
    error: json['error'] as String?,
    preview: json['preview'] as String? ?? '',
    response: json['response'] as String?,
    ttftMs: json['ttft_ms'] as int?,
    durationMs: json['duration_ms'] as int?,
    chunkCount: json['chunk_count'] as int? ?? 0,
    responseChars: json['response_chars'] as int? ?? 0,
  );

  final int id;
  final DateTime createdAt;
  final String model;
  final String prompt;
  final int? status;
  final String? error;

  /// The first few hundred characters, for the list.
  final String preview;

  /// The whole reply — only present when a single request was fetched.
  final String? response;
  final int? ttftMs;
  final int? durationMs;
  final int chunkCount;
  final int responseChars;

  bool get failed => error != null;
}

/// The list response, which also carries the open/closed counts the tab bar
/// shows — GitHub shows both counts regardless of which tab is selected.
class IssuePage {
  const IssuePage({
    required this.issues,
    required this.open,
    required this.closed,
  });

  factory IssuePage.fromJson(Map<String, dynamic> json) => IssuePage(
    issues: [
      for (final issue in (json['issues'] as List? ?? const []))
        Issue.fromJson(issue as Map<String, dynamic>),
    ],
    open: json['open'] as int? ?? 0,
    closed: json['closed'] as int? ?? 0,
  );

  final List<Issue> issues;
  final int open;
  final int closed;
}
