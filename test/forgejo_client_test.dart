import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agentforge/core/forgejo/forgejo_client.dart';
import 'package:agentforge/core/forgejo/models.dart';
import 'package:agentforge/core/settings/app_settings.dart';

class _Adapter implements HttpClientAdapter {
  _Adapter(this.handler);

  final ResponseBody Function(RequestOptions) handler;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    expect(options.followRedirects, isFalse);
    return handler(options);
  }
}

void main() {
  const settings = AppSettings(
    baseUrl: 'https://avis-pbook.tail651ec3.ts.net',
    token: 'test-token',
  );

  test('whoAmI returns login', () async {
    final dio = Dio(BaseOptions(baseUrl: settings.baseUrl));
    dio.httpClientAdapter = _Adapter((options) {
      expect(options.path, '/api/v1/user');
      expect(options.headers['Authorization'], 'token test-token');
      return ResponseBody.fromString(
        '{"login":"avidullu"}',
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    });

    final client = ForgejoClient(settings: settings, dio: dio);
    expect(await client.whoAmI(), 'avidullu');
  });

  test('listOpenPullRequests maps issue search results', () async {
    final dio = Dio(BaseOptions(baseUrl: settings.baseUrl));
    dio.httpClientAdapter = _Adapter((options) {
      expect(options.path, '/api/v1/repos/issues/search');
      expect(options.queryParameters['type'], 'pulls');
      expect(options.queryParameters['state'], 'open');
      return ResponseBody.fromString(
        '''
        [{
          "number": 1,
          "title": "Hello",
          "state": "open",
          "html_url": "https://example/o/r/pulls/1",
          "updated_at": "2026-07-18T00:00:00Z",
          "user": {"login": "avi"},
          "repository": {"owner": "o", "name": "r"},
          "pull_request": {"draft": true}
        }]
        ''',
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    });

    final client = ForgejoClient(settings: settings, dio: dio);
    final list = await client.listOpenPullRequests();
    expect(list, hasLength(1));
    expect(list.first.draft, isTrue);
    expect(list.first.routePath, '/o/r/pulls/1');
  });

  test('getPullRequest maps detail payload', () async {
    final dio = Dio(BaseOptions(baseUrl: settings.baseUrl));
    dio.httpClientAdapter = _Adapter((options) {
      expect(options.path, '/api/v1/repos/o/r/pulls/9');
      return ResponseBody.fromString(
        '''
        {
          "number": 9,
          "title": "Detail",
          "state": "open",
          "body": "Hello body",
          "html_url": "https://example/o/r/pulls/9",
          "draft": false,
          "head": {"sha": "0123456789abcdef", "ref": "feature/safe-review"},
          "base": {"ref": "main"},
          "updated_at": "2026-07-18T00:00:00Z",
          "user": {"login": "avi"}
        }
        ''',
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    });

    final client = ForgejoClient(settings: settings, dio: dio);
    final detail = await client.getPullRequest(
      owner: 'o',
      repo: 'r',
      number: 9,
    );
    expect(detail.summary.title, 'Detail');
    expect(detail.body, 'Hello body');
    expect(detail.summary.routePath, '/o/r/pulls/9');
    expect(detail.headSha, '0123456789abcdef');
    expect(detail.headRef, 'feature/safe-review');
    expect(detail.baseRef, 'main');
  });

  test('createIssueComment posts body', () async {
    final dio = Dio(BaseOptions(baseUrl: settings.baseUrl));
    dio.httpClientAdapter = _Adapter((options) {
      expect(options.method, 'POST');
      expect(options.path, '/api/v1/repos/o/r/issues/3/comments');
      return ResponseBody.fromString(
        '{"id":10,"body":"hi","user":{"login":"avi"},"created_at":"2026-07-18T00:00:00Z"}',
        201,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    });
    final client = ForgejoClient(settings: settings, dio: dio);
    final c = await client.createIssueComment(
      owner: 'o',
      repo: 'r',
      number: 3,
      body: 'hi',
    );
    expect(c.id, 10);
    expect(c.body, 'hi');
  });

  test('createPullReview posts event', () async {
    final dio = Dio(BaseOptions(baseUrl: settings.baseUrl));
    dio.httpClientAdapter = _Adapter((options) {
      expect(options.method, 'POST');
      expect(options.path, '/api/v1/repos/o/r/pulls/3/reviews');
      expect(options.data, {
        'body': 'LGTM',
        'event': 'APPROVED',
        'commit_id': '0123456789abcdef',
      });
      return ResponseBody.fromString(
        '{"id":11,"state":"APPROVED","body":"LGTM","user":{"login":"avi"}}',
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    });
    final client = ForgejoClient(settings: settings, dio: dio);
    final r = await client.createPullReview(
      owner: 'o',
      repo: 'r',
      number: 3,
      event: ReviewEvent.approve,
      body: 'LGTM',
      commitId: '0123456789abcdef',
    );
    expect(r.state, 'APPROVED');
  });
}
