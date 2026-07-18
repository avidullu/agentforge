/// Pure helpers that map OS-level deep-link URIs into go_router locations.
///
/// Supported shapes:
/// - `https://{trustedHost}/{owner}/{repo}/pulls/{n}`
/// - `https://…/{owner}/{repo}/pull/{n}`
/// - `{urlScheme}://pr/{owner}/{repo}/{n}`  (custom scheme, easy adb/testing)
/// - `{urlScheme}://open/{owner}/{repo}/pulls/{n}`
/// - `{urlScheme}:///{owner}/{repo}/pulls/{n}`
library;

import '../config/app_config.dart';

/// Canonical Forgejo host used for App Links / Universal Links.
///
/// Const alias to [AppConfig.trustedHost] so private hosts never appear as
/// literals in `lib/` (AF-011 / docs/11 §5.4).
const kForgejoHost = AppConfig.trustedHost;

/// Custom URL scheme for debug / adb / manual tests (no domain verification).
const kAppScheme = AppConfig.urlScheme;

final _prPathRe = RegExp(r'^/([^/]+)/([^/]+)/pulls?/(\d+)/?$');

/// Returns true if [path] is a PR detail route path.
bool isPrPath(String path) => _prPathRe.hasMatch(path);

/// Converts an incoming OS deep-link [uri] into a go_router location
/// (e.g. `/owner/repo/pulls/611`), or `null` if the URI is not a recognized
/// AgentForge deep link.
String? deepLinkToLocation(Uri? uri) {
  if (uri == null) return null;

  final scheme = uri.scheme.toLowerCase();

  if (scheme == 'https') {
    // Never resolve a URL from another Forgejo authority against the token and
    // base URL of the configured private instance.
    if (uri.host.toLowerCase() != kForgejoHost || uri.port != 443) return null;
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
