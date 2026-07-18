import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agentforge/core/forgejo/forgejo_client.dart';
import 'package:agentforge/core/forgejo/models.dart';

void main() {
  group('ForgejoUser', () {
    test('fromJson parses login and full_name', () {
      final user = ForgejoUser.fromJson({
        'login': 'devuser',
        'full_name': 'Dev User',
      });
      expect(user.login, 'devuser');
      expect(user.fullName, 'Dev User');
    });

    test('fromJson handles null gracefully', () {
      final user = ForgejoUser.fromJson(null);
      expect(user.login, isEmpty);
      expect(user.fullName, isEmpty);
    });

    test('fromJson falls back to username when login absent', () {
      final user = ForgejoUser.fromJson({'username': 'fallback'});
      expect(user.login, 'fallback');
    });

    test('const constructor works with defaults', () {
      const user = ForgejoUser(login: 'test');
      expect(user.fullName, isEmpty);
    });
  });

  group('PullReview', () {
    test('fromJson parses full payload', () {
      final review = PullReview.fromJson({
        'id': 42,
        'state': 'APPROVED',
        'body': 'LGTM',
        'user': {'login': 'reviewer'},
        'submitted_at': '2026-07-18T12:00:00Z',
      });
      expect(review.id, 42);
      expect(review.state, 'APPROVED');
      expect(review.body, 'LGTM');
      expect(review.user.login, 'reviewer');
      expect(review.submittedAt, DateTime.utc(2026, 7, 18, 12));
    });

    test('fromJson falls back to created_at', () {
      final review = PullReview.fromJson({
        'id': 1,
        'state': 'COMMENT',
        'body': '',
        'user': {'login': 'x'},
        'created_at': '2026-01-01T00:00:00Z',
      });
      expect(review.submittedAt, DateTime.utc(2026));
    });

    test('fromJson handles missing fields', () {
      final review = PullReview.fromJson({
        'user': {'login': 'minimal'},
      });
      expect(review.id, 0);
      expect(review.state, '');
      expect(review.submittedAt, isNull);
    });
  });

  group('ReviewEvent', () {
    test('apiValue maps correctly', () {
      expect(ReviewEvent.comment.apiValue, 'COMMENT');
      expect(ReviewEvent.approve.apiValue, 'APPROVED');
      expect(ReviewEvent.requestChanges.apiValue, 'REQUEST_CHANGES');
    });
  });

  group('IssueComment', () {
    test('fromJson parses comment payload', () {
      final comment = IssueComment.fromJson({
        'id': 10,
        'body': 'Nice work!',
        'user': {'login': 'commenter'},
        'created_at': '2026-07-18T00:00:00Z',
        'html_url': 'https://example.com/o/r/issues/1#issuecomment-10',
      });
      expect(comment.id, 10);
      expect(comment.body, 'Nice work!');
      expect(comment.user.login, 'commenter');
      expect(comment.createdAt, DateTime.utc(2026, 7, 18));
      expect(comment.htmlUrl, contains('issuecomment-10'));
    });

    test('fromJson handles missing fields', () {
      final comment = IssueComment.fromJson({});
      expect(comment.id, 0);
      expect(comment.body, isEmpty);
      expect(comment.createdAt, isNull);
      expect(comment.htmlUrl, isEmpty);
    });
  });

  group('PullRequestDetail', () {
    test('fromPullJson parses head and base refs', () {
      final detail = PullRequestDetail.fromPullJson(
        {
          'number': 5,
          'title': 'Test PR',
          'state': 'open',
          'body': 'Description',
          'html_url': 'https://example/o/r/pulls/5',
          'updated_at': '2026-07-18T00:00:00Z',
          'user': {'login': 'author'},
          'head': {'sha': 'abc123def456', 'ref': 'feature/x'},
          'base': {'ref': 'main'},
        },
        owner: 'o',
        repo: 'r',
      );
      expect(detail.headSha, 'abc123def456');
      expect(detail.headRef, 'feature/x');
      expect(detail.baseRef, 'main');
      expect(detail.body, 'Description');
      expect(detail.summary.number, 5);
    });

    test('fromPullJson handles missing head/base', () {
      final detail = PullRequestDetail.fromPullJson(
        {
          'number': 1,
          'title': 'Minimal',
          'state': 'open',
          'html_url': 'https://example/o/r/pulls/1',
          'updated_at': '2026-07-18T00:00:00Z',
          'user': {'login': 'x'},
        },
        owner: 'o',
        repo: 'r',
      );
      expect(detail.headSha, isEmpty);
      expect(detail.headRef, isEmpty);
      expect(detail.baseRef, isEmpty);
    });
  });

  group('PullRequestSummary', () {
    test('fromPullJson constructs routePath', () {
      final pr = PullRequestSummary.fromPullJson(
        {
          'number': 42,
          'title': 'Fix',
          'state': 'open',
          'html_url': 'https://example/o/r/pulls/42',
          'updated_at': '2026-07-18T00:00:00Z',
          'user': {'login': 'dev'},
          'draft': true,
        },
        owner: 'owner',
        repo: 'repo',
      );
      expect(pr.routePath, '/owner/repo/pulls/42');
      expect(pr.fullName, 'owner/repo');
      expect(pr.draft, isTrue);
    });
  });

  group('forgejoErrorMessage', () {
    test('returns ForgejoException message as-is', () {
      final msg = forgejoErrorMessage(
        ForgejoException('bad input', statusCode: 400),
      );
      expect(msg, 'bad input (HTTP 400)');
    });

    test('maps 401/403 to authentication message', () {
      final dioError = DioException(
        requestOptions: RequestOptions(path: '/test'),
        response: Response(
          requestOptions: RequestOptions(path: '/test'),
          statusCode: 401,
        ),
      );
      expect(forgejoErrorMessage(dioError), contains('Authentication failed'));
      expect(forgejoErrorMessage(dioError), contains('401'));
    });

    test('maps connection errors to Tailscale hint', () {
      final dioError = DioException(
        type: DioExceptionType.connectionError,
        requestOptions: RequestOptions(path: '/test'),
        message: 'Connection refused',
      );
      expect(forgejoErrorMessage(dioError), contains('Cannot reach Forgejo'));
      expect(forgejoErrorMessage(dioError), contains('Tailscale'));
    });

    test('maps connection timeout to Tailscale hint', () {
      final dioError = DioException(
        type: DioExceptionType.connectionTimeout,
        requestOptions: RequestOptions(path: '/test'),
      );
      expect(forgejoErrorMessage(dioError), contains('Tailscale'));
    });

    test('extracts server error message from response body', () {
      final dioError = DioException(
        requestOptions: RequestOptions(path: '/test'),
        response: Response(
          requestOptions: RequestOptions(path: '/test'),
          statusCode: 422,
          data: {'message': 'Validation failed'},
        ),
      );
      expect(forgejoErrorMessage(dioError), contains('Validation failed'));
      expect(forgejoErrorMessage(dioError), contains('422'));
    });

    test('handles plain DioException without response', () {
      final dioError = DioException(
        requestOptions: RequestOptions(path: '/test'),
        message: 'oops',
      );
      expect(forgejoErrorMessage(dioError), 'Forgejo request failed.');
    });

    test('handles unknown error types', () {
      expect(forgejoErrorMessage('raw string'), 'raw string');
      expect(forgejoErrorMessage(Exception('generic')), contains('Exception'));
    });
  });
}
