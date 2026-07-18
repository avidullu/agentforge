import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'deep_link.dart';

/// One early app_links instance owns both cold- and warm-start delivery.
final agentForgeAppLinks = AppLinks();

/// Listens for warm-start deep links and navigates via [router].
///
/// Cold-start is handled by passing [initialLocation] into [GoRouter]
/// before the first frame (see [main.dart]).
class DeepLinkListener extends ConsumerStatefulWidget {
  const DeepLinkListener({
    super.key,
    required this.router,
    required this.child,
  });

  final GoRouter router;
  final Widget child;

  @override
  ConsumerState<DeepLinkListener> createState() => _DeepLinkListenerState();
}

class _DeepLinkListenerState extends ConsumerState<DeepLinkListener> {
  StreamSubscription<Uri>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = agentForgeAppLinks.uriLinkStream.listen(_onUri, onError: (_) {});
  }

  void _onUri(Uri uri) {
    final location = deepLinkToLocation(uri);
    if (location == null) return;
    // Avoid redundant navigations when already on the target.
    if (widget.router.state.uri.toString() == location) return;
    widget.router.go(location);
  }

  @override
  void dispose() {
    unawaited(_sub?.cancel() ?? Future<void>.value());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
