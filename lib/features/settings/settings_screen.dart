import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/forgejo/forgejo_client.dart';
import '../../core/settings/app_settings.dart';
import '../../core/settings/settings_providers.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _urlController;
  late final TextEditingController _tokenController;
  var _obscureToken = true;
  var _saving = false;
  var _testing = false;
  String? _statusMessage;
  bool _statusIsError = false;

  /// Explicit flag — not derived from English status substrings (review 271).
  bool _showCredentialReentryBanner = false;

  /// Origin the form fields are currently bound to (for carry-over prevention).
  String? _boundOrigin;
  int _urlChangeSeq = 0;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: AppSettings.defaultBaseUrl);
    _tokenController = TextEditingController();
    _urlController.addListener(_onUrlChanged);
    // Prefill from storage once loaded (origin-bound PAT; never cross-host).
    ref.read(settingsProvider.future).then((s) {
      if (!mounted) return;
      _applyLoadedSettings(s);
    });
  }

  @override
  void dispose() {
    _urlController.removeListener(_onUrlChanged);
    _urlController.dispose();
    _tokenController.dispose();
    super.dispose();
  }

  void _applyLoadedSettings(AppSettings s) {
    final origin = AppSettings.normalizeOrigin(s.baseUrl);
    // Set bound origin before mutating the URL controller so the listener
    // does not treat the programmatic fill as a user origin change.
    _boundOrigin = origin;
    _urlController.text = s.baseUrl;
    _tokenController.text = s.token;
    if (s.needsCredentialReentry) {
      setState(() {
        _showCredentialReentryBanner = true;
        _statusMessage = _reentryMessage(s.credentialState);
        _statusIsError = false;
      });
    }
  }

  String _reentryMessage(CredentialLoadState state) {
    if (state == CredentialLoadState.legacyClearedRequiresReentry) {
      return 'Saved credential was for a previous app version and was '
          'cleared. Enter a personal access token for this Forgejo '
          'instance.';
    }
    return 'Credential was entered for a different Forgejo instance. '
        'Enter a token for the current origin.';
  }

  /// On Instance URL change: never carry a PAT typed/saved for another origin
  /// (docs/11 §5.5). Resolves credentials via [SettingsRepository.loadForOrigin]
  /// so production can surface `originMismatch` / a bound PAT for the new host.
  void _onUrlChanged() {
    final next = AppSettings.normalizeOrigin(_urlController.text);
    final previous = _boundOrigin;
    if (previous == null || next.isEmpty || next == previous) return;

    _boundOrigin = next;
    final hadTokenInForm = _tokenController.text.isNotEmpty;
    if (hadTokenInForm) {
      _tokenController.clear();
    }

    final seq = ++_urlChangeSeq;
    final repo = ref.read(settingsRepositoryProvider);
    repo.loadForOrigin(next).then((s) {
      if (!mounted || seq != _urlChangeSeq) return;
      if (AppSettings.normalizeOrigin(_urlController.text) != next) return;

      setState(() {
        if (s.credentialState == CredentialLoadState.bound) {
          _tokenController.text = s.token;
          _showCredentialReentryBanner = false;
          if (_statusMessage != null && !_statusIsError) {
            _statusMessage = null;
          }
        } else if (hadTokenInForm || s.needsCredentialReentry) {
          _tokenController.clear();
          _showCredentialReentryBanner = true;
          _statusMessage = _reentryMessage(
            s.needsCredentialReentry
                ? s.credentialState
                : CredentialLoadState.originMismatch,
          );
          _statusIsError = false;
        }
      });
    });
  }

  AppSettings _fromForm() {
    return AppSettings(
      baseUrl: AppSettings.normalizeBaseUrl(_urlController.text),
      token: _tokenController.text.trim(),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final formOrigin = AppSettings.normalizeOrigin(_urlController.text);

    // Defense in depth: if the form origin drifted from _boundOrigin while a
    // token is still present, force re-entry rather than cross-binding (271#1).
    if (_boundOrigin != null &&
        formOrigin != _boundOrigin &&
        _tokenController.text.trim().isNotEmpty) {
      setState(() {
        _tokenController.clear();
        _boundOrigin = formOrigin;
        _showCredentialReentryBanner = true;
        _statusMessage = _reentryMessage(CredentialLoadState.originMismatch);
        _statusIsError = false;
      });
      return;
    }

    setState(() {
      _saving = true;
      _statusMessage = null;
      _showCredentialReentryBanner = false;
    });
    try {
      await ref.read(settingsControllerProvider).save(_fromForm());
      if (!mounted) return;
      _boundOrigin = formOrigin;
      setState(() {
        _statusMessage = 'Saved.';
        _statusIsError = false;
        _showCredentialReentryBanner = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statusMessage = 'Save failed: $e';
        _statusIsError = true;
      });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _testConnection() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _testing = true;
      _statusMessage = null;
    });
    try {
      final client = ForgejoClient(settings: _fromForm());
      final login = await client.whoAmI();
      if (!mounted) return;
      setState(() {
        _statusMessage = 'Connected as $login';
        _statusIsError = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statusMessage = forgejoErrorMessage(e);
        _statusIsError = true;
      });
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  Future<void> _disconnect() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Disconnect Forgejo?'),
        content: const Text(
          'This removes the saved personal access token from this app.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await ref.read(settingsControllerProvider).disconnect();
    if (!mounted) return;
    _tokenController.clear();
    setState(() {
      _statusMessage = 'Disconnected and removed the saved token.';
      _statusIsError = false;
      _showCredentialReentryBanner = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text('Forgejo Connection', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Reachable over Tailscale. Create a personal access token on '
              'your instance with the repository permissions required for '
              'the review actions you enable.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            if (_showCredentialReentryBanner && _statusMessage != null) ...[
              const SizedBox(height: 16),
              Material(
                color: theme.colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    _statusMessage!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSecondaryContainer,
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
            TextFormField(
              controller: _urlController,
              decoration: const InputDecoration(
                labelText: 'Instance URL',
                hintText: AppSettings.defaultBaseUrl,
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.url,
              autocorrect: false,
              validator: (v) {
                final t = v?.trim() ?? '';
                if (t.isEmpty) return 'Required';
                return AppSettings.baseUrlValidationError(t);
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _tokenController,
              decoration: InputDecoration(
                labelText: 'Personal access token',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureToken ? Icons.visibility : Icons.visibility_off,
                  ),
                  tooltip: _obscureToken ? 'Show token' : 'Hide token',
                  onPressed: () =>
                      setState(() => _obscureToken = !_obscureToken),
                ),
              ),
              obscureText: _obscureToken,
              autocorrect: false,
              enableSuggestions: false,
              validator: (v) {
                if ((v ?? '').trim().isEmpty) return 'Required';
                return null;
              },
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save'),
                ),
                OutlinedButton(
                  onPressed: _testing ? null : _testConnection,
                  child: _testing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Test connection'),
                ),
                TextButton.icon(
                  onPressed: _saving || _testing ? null : _disconnect,
                  icon: const Icon(Icons.link_off),
                  label: const Text('Disconnect'),
                ),
              ],
            ),
            if (_statusMessage != null && !_showCredentialReentryBanner) ...[
              const SizedBox(height: 16),
              Text(
                _statusMessage!,
                style: TextStyle(
                  color: _statusIsError
                      ? theme.colorScheme.error
                      : theme.colorScheme.primary,
                ),
              ),
            ],
            const SizedBox(height: 40),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Agent endpoints'),
              subtitle: const Text('Register trusted hosts and side-car URLs'),
              leading: Icon(
                Icons.smart_toy_outlined,
                color: theme.colorScheme.primary,
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/agents'),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Coordination'),
              subtitle: const Text('Active work grouped by repository'),
              leading: Icon(
                Icons.hub_outlined,
                color: theme.colorScheme.primary,
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/coordination'),
            ),
          ],
        ),
      ),
    );
  }
}
