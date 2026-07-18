import 'package:flutter_test/flutter_test.dart';

import 'package:agentforge/core/deep_links/deep_link.dart';

void main() {
  // Host comes from AppConfig via kForgejoHost (synthetic in committed tree).
  const origin = 'https://$kForgejoHost';

  group('deepLinkToLocation', () {
    test('maps https Forgejo pulls URL', () {
      final uri = Uri.parse('$origin/owner/repo/pulls/611');
      expect(deepLinkToLocation(uri), '/owner/repo/pulls/611');
    });

    test('maps https Forgejo pull (singular) URL', () {
      final uri = Uri.parse('$origin/avidullu/agentforge/pull/3');
      expect(deepLinkToLocation(uri), '/avidullu/agentforge/pull/3');
    });

    test('strips trailing slash', () {
      final uri = Uri.parse('$origin/o/r/pulls/1/');
      expect(deepLinkToLocation(uri), '/o/r/pulls/1');
    });

    test('maps custom scheme agentforge://pr/owner/repo/n', () {
      final uri = Uri.parse('$kAppScheme://pr/owner/indexer/42');
      expect(deepLinkToLocation(uri), '/owner/indexer/pulls/42');
    });

    test('maps custom scheme agentforge://open/.../pulls/n', () {
      final uri = Uri.parse('$kAppScheme://open/o/r/pulls/7');
      expect(deepLinkToLocation(uri), '/o/r/pulls/7');
    });

    test('rejects non-PR https paths', () {
      final uri = Uri.parse('$origin/owner/repo');
      expect(deepLinkToLocation(uri), isNull);
    });

    test('rejects a PR path from another authority', () {
      final uri = Uri.parse('https://evil.example/o/r/pulls/1');
      expect(deepLinkToLocation(uri), isNull);
    });

    test('rejects HTTP and alternate-port Forgejo URLs', () {
      expect(
        deepLinkToLocation(Uri.parse('http://$kForgejoHost/o/r/pulls/1')),
        isNull,
      );
      expect(
        deepLinkToLocation(Uri.parse('https://$kForgejoHost:8443/o/r/pulls/1')),
        isNull,
      );
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
