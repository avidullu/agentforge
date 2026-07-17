/// Pure helpers that map OS-level deep-link URIs into go_router locations.
///
/// Supported shapes (host ignored for path routing — only path matters):
/// - `https://avis-pbook.tail651ec3.ts.net/{owner}/{repo}/pulls/{n}`
/// - `https://…/{owner}/{repo}/pull/{n}`
/// - `agentforge://pr/{owner}/{repo}/{n}`  (custom scheme, easy adb/testing)
/// - `agentforge://open/{owner}/{repo}/pulls/{n}`
/// - `agentforge:///{owner}/{repo}/pulls/{n}`
library;

/// Canonical Forgejo host used for App Links / Universal Links.
const kForgejoHost = 'avis-pbook.tail651ec3.ts.net';

/// Custom URL scheme for debug / adb / manual tests (no domain verification).
const kAppScheme = 'agentforge';

final _prPathRe = RegExp(r'^/([^/]+)/([^/]+)/pulls?/(\d+)/?$');

/// Returns true if [path] is a PR detail route path.
bool isPrPath(String path) => _prPathRe.hasMatch(path);

/// Converts an incoming OS deep-link [uri] into a go_router location
/// (e.g. `/Khelsutra/badminton-highlight-indexer/pulls/611`), or `null`
/// if the URI is not a recognized AgentForge deep link.
String? deepLinkToLocation(Uri? uri) {
  if (uri == null) return null;

  final scheme = uri.scheme.toLowerCase();

  if (scheme == 'http' || scheme == 'https') {
    // Accept any host so Gmail redirectors / alternate names still work
    // as long as the path is a PR path.
    final path = _normalizePath(uri.path);
    if (isPrPath(path)) return path;
    return null;
  }

  if (scheme == kAppScheme) {
    // agentforge://pr/owner/repo/42
    if (uri.host == 'pr') {
      final segs = uri.pathSegments.where((s) => s.isNotEmpty).toList();
      if (segs.length >= 3 && int.tryParse(segs[2]) != null) {
        return '/${segs[0]}/${segs[1]}/pulls/${segs[2]}';
      }
      return null;
    }

    // agentforge://open/owner/repo/pulls/42
    if (uri.host == 'open') {
      final path = _normalizePath('/${uri.pathSegments.join('/')}');
      if (isPrPath(path)) return path;
      return null;
    }

    // agentforge:///owner/repo/pulls/42  (empty host)
    final path = _normalizePath(uri.path);
    if (isPrPath(path)) return path;
    return null;
  }

  return null;
}

String _normalizePath(String path) {
  if (path.isEmpty) return '/';
  var p = path.startsWith('/') ? path : '/$path';
  if (p.length > 1 && p.endsWith('/')) {
    p = p.substring(0, p.length - 1);
  }
  return p;
}
