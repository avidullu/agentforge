import 'package:flutter_test/flutter_test.dart';

import 'package:agentforge/core/forgejo/models.dart';
import 'package:agentforge/core/settings/app_settings.dart';

void main() {
  group('PullRequestSummary.fromIssueSearchJson', () {
    test('parses Forgejo issues/search pull payload', () {
      final pr = PullRequestSummary.fromIssueSearchJson({
        'number': 623,
        'title': 'docs: eval report',
        'state': 'open',
        'html_url':
            'https://avis-pbook.tail651ec3.ts.net/Khelsutra/badminton-highlight-indexer/pulls/623',
        'updated_at': '2026-07-18T01:00:00+05:30',
        'user': {'login': 'avidullu', 'full_name': 'Avi Dullu'},
        'repository': {
          'owner': 'Khelsutra',
          'name': 'badminton-highlight-indexer',
          'full_name': 'Khelsutra/badminton-highlight-indexer',
        },
        'pull_request': {
          'draft': false,
          'html_url':
              'https://avis-pbook.tail651ec3.ts.net/Khelsutra/badminton-highlight-indexer/pulls/623',
        },
      });

      expect(pr.owner, 'Khelsutra');
      expect(pr.repo, 'badminton-highlight-indexer');
      expect(pr.number, 623);
      expect(pr.title, 'docs: eval report');
      expect(pr.user.login, 'avidullu');
      expect(pr.draft, isFalse);
      expect(pr.routePath, '/Khelsutra/badminton-highlight-indexer/pulls/623');
      expect(pr.updatedAt, isNotNull);
    });
  });

  group('AppSettings', () {
    test('normalizeBaseUrl strips trailing slashes', () {
      expect(
        AppSettings.normalizeBaseUrl('https://avis-pbook.tail651ec3.ts.net/'),
        'https://avis-pbook.tail651ec3.ts.net',
      );
    });

    test('isConfigured requires both fields', () {
      expect(const AppSettings(baseUrl: '', token: 'x').isConfigured, isFalse);
      expect(
        const AppSettings(
          baseUrl: AppSettings.defaultBaseUrl,
          token: '',
        ).isConfigured,
        isFalse,
      );
      expect(
        const AppSettings(
          baseUrl: AppSettings.defaultBaseUrl,
          token: 'tok',
        ).isConfigured,
        isTrue,
      );
    });

    test('validates the trusted HTTPS Forgejo origin', () {
      expect(
        AppSettings.baseUrlValidationError(AppSettings.defaultBaseUrl),
        isNull,
      );
      expect(
        AppSettings.baseUrlValidationError('http://${AppSettings.trustedHost}'),
        contains('HTTPS'),
      );
      expect(
        AppSettings.baseUrlValidationError('https://evil.example'),
        contains('trusts only'),
      );
      expect(
        AppSettings.baseUrlValidationError(
          'https://${AppSettings.trustedHost}:8443',
        ),
        contains(AppSettings.defaultBaseUrl),
      );
      expect(
        AppSettings.baseUrlValidationError(
          'https://${AppSettings.trustedHost}/unexpected/path',
        ),
        contains('without credentials or a path'),
      );
    });
  });
}
