import 'package:flutter_test/flutter_test.dart';

import 'package:agentforge/core/deep_links/deep_link.dart';

void main() {
  group('deepLinkToLocation', () {
    test('maps https Forgejo pulls URL', () {
      final uri = Uri.parse(
        'https://avis-pbook.tail651ec3.ts.net/Khelsutra/badminton-highlight-indexer/pulls/611',
      );
      expect(
        deepLinkToLocation(uri),
        '/Khelsutra/badminton-highlight-indexer/pulls/611',
      );
    });

    test('maps https Forgejo pull (singular) URL', () {
      final uri = Uri.parse(
        'https://avis-pbook.tail651ec3.ts.net/avidullu/agentforge/pull/3',
      );
      expect(deepLinkToLocation(uri), '/avidullu/agentforge/pull/3');
    });

    test('strips trailing slash', () {
      final uri = Uri.parse(
        'https://avis-pbook.tail651ec3.ts.net/o/r/pulls/1/',
      );
      expect(deepLinkToLocation(uri), '/o/r/pulls/1');
    });

    test('maps custom scheme agentforge://pr/owner/repo/n', () {
      final uri = Uri.parse('agentforge://pr/Khelsutra/indexer/42');
      expect(deepLinkToLocation(uri), '/Khelsutra/indexer/pulls/42');
    });

    test('maps custom scheme agentforge://open/.../pulls/n', () {
      final uri = Uri.parse('agentforge://open/o/r/pulls/7');
      expect(deepLinkToLocation(uri), '/o/r/pulls/7');
    });

    test('rejects non-PR https paths', () {
      final uri = Uri.parse(
        'https://avis-pbook.tail651ec3.ts.net/Khelsutra/badminton-highlight-indexer',
      );
      expect(deepLinkToLocation(uri), isNull);
    });

    test('rejects null', () {
      expect(deepLinkToLocation(null), isNull);
    });

    test('isPrPath accepts both pull and pulls', () {
      expect(isPrPath('/a/b/pulls/1'), isTrue);
      expect(isPrPath('/a/b/pull/2'), isTrue);
      expect(isPrPath('/a/b/issues/3'), isFalse);
    });
  });
}
