import 'dart:convert';

import 'package:http/http.dart' as http;

import '../chat_config.dart';
import 'models.dart';

/// Raised when the tracker API answers with a non-2xx status.
class TrackerException implements Exception {
  TrackerException(this.statusCode, this.message);

  final int statusCode;
  final String message;

  @override
  String toString() => 'HTTP $statusCode: $message';
}

/// Client for the proxy's issue tracker and request transcript.
///
/// The tracker lives on the same server as the model proxy, so it inherits
/// the base URL and the access token from [ChatConfig] — there is nothing
/// extra to configure.
class TrackerApi {
  TrackerApi(this.config, {http.Client? client})
    : _client = client ?? http.Client();

  final ChatConfig config;
  final http.Client _client;

  void close() => _client.close();

  /// `/api/...` sits next to the `/v1` the chat endpoint uses, so strip the
  /// version segment off the configured base URL.
  Uri _uri(String path, [Map<String, String>? query]) {
    final base = config.chatCompletionsUri.replace(
      path: '',
      query: '',
      fragment: '',
    );
    return base.replace(
      path: path,
      queryParameters: query?.isEmpty ?? true ? null : query,
    );
  }

  Map<String, String> get _headers => {
    'content-type': 'application/json',
    if (config.apiKey.trim().isNotEmpty)
      'authorization': 'Bearer ${config.apiKey.trim()}',
  };

  Future<dynamic> _send(
    String method,
    String path, {
    Map<String, String>? query,
    Map<String, Object?>? body,
  }) async {
    final request = http.Request(method, _uri(path, query))
      ..headers.addAll(_headers);
    if (body != null) request.body = jsonEncode(body);

    final response = await http.Response.fromStream(
      await _client.send(request),
    );
    final decoded = response.body.isEmpty ? null : jsonDecode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message =
          decoded is Map && decoded['error'] is Map
              ? (decoded['error'] as Map)['message'] as String? ?? response.body
              : response.body;
      throw TrackerException(response.statusCode, message);
    }
    return decoded;
  }

  Future<bool> ping() async {
    try {
      await _send('GET', '/health');
      return true;
    } catch (_) {
      return false;
    }
  }

  // ------------------------------------------------------------------ issues

  Future<IssuePage> issues({
    String state = 'open',
    String label = '',
    String query = '',
    String sort = 'newest',
  }) async {
    final json = await _send(
      'GET',
      '/api/issues',
      query: {
        'state': state,
        if (label.isNotEmpty) 'label': label,
        if (query.isNotEmpty) 'q': query,
        'sort': sort,
      },
    );
    return IssuePage.fromJson(json as Map<String, dynamic>);
  }

  Future<Issue> issue(int number) async => Issue.fromJson(
    await _send('GET', '/api/issues/$number') as Map<String, dynamic>,
  );

  Future<Issue> createIssue({
    required String title,
    String body = '',
    List<String> labels = const [],
    int? requestId,
    String? markdown,
  }) async => Issue.fromJson(
    await _send(
          'POST',
          '/api/issues',
          body: {
            'title': title,
            'body': body,
            'labels': labels,
            if (requestId != null) 'request_id': requestId,
            if (markdown != null) 'markdown': markdown,
          },
        )
        as Map<String, dynamic>,
  );

  Future<Issue> updateIssue(
    int number, {
    String? title,
    String? body,
    String? state,
  }) async => Issue.fromJson(
    await _send(
          'PATCH',
          '/api/issues/$number',
          body: {
            if (title != null) 'title': title,
            if (body != null) 'body': body,
            if (state != null) 'state': state,
          },
        )
        as Map<String, dynamic>,
  );

  Future<Issue> setLabels(int number, List<String> labels) async =>
      Issue.fromJson(
        await _send(
              'PUT',
              '/api/issues/$number/labels',
              body: {'labels': labels},
            )
            as Map<String, dynamic>,
      );

  Future<void> deleteIssue(int number) =>
      _send('DELETE', '/api/issues/$number');

  Future<void> comment(int number, String body) =>
      _send('POST', '/api/issues/$number/comments', body: {'body': body});

  Future<void> editComment(int id, String body) =>
      _send('PATCH', '/api/comments/$id', body: {'body': body});

  Future<void> deleteComment(int id) => _send('DELETE', '/api/comments/$id');

  Future<List<IssueLabel>> labels() async {
    final json = await _send('GET', '/api/labels') as Map<String, dynamic>;
    return [
      for (final label in json['labels'] as List)
        IssueLabel.fromJson(label as Map<String, dynamic>),
    ];
  }

  // ---------------------------------------------------------------- requests

  Future<List<RequestLog>> requests({String query = '', int limit = 50}) async {
    final json =
        await _send(
              'GET',
              '/api/requests',
              query: {if (query.isNotEmpty) 'q': query, 'limit': '$limit'},
            )
            as Map<String, dynamic>;
    return [
      for (final row in json['requests'] as List)
        RequestLog.fromJson(row as Map<String, dynamic>),
    ];
  }

  Future<RequestLog> request(int id) async => RequestLog.fromJson(
    await _send('GET', '/api/requests/$id') as Map<String, dynamic>,
  );
}
