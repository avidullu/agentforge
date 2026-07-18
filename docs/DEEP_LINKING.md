# Deep linking setup: Gmail → AgentForge

**Milestone status:** code repaired; verified-link and physical-device gate open.

The acceptance journey is: tap a trusted avis-pbook Forgejo PR URL in Gmail and
land on that exact Forgejo instance/repository/PR in AgentForge.

## Supported URL shapes

| Source | Example |
|---|---|
| Trusted HTTPS (`pulls`) | `https://avis-pbook.tail651ec3.ts.net/owner/repo/pulls/42` |
| Trusted HTTPS (`pull`) | `https://avis-pbook.tail651ec3.ts.net/owner/repo/pull/42` |
| Custom scheme | `agentforge://pr/owner/repo/42` |
| Custom path | `agentforge://open/owner/repo/pulls/42` |

HTTPS URLs from any other authority are rejected. They must never be resolved
against the token/base URL of the configured private Forgejo instance.

## Ownership model

AgentForge uses `app_links` as the sole OS-link owner:

- Android sets `flutter_deeplinking_enabled=false`.
- iOS sets `FlutterDeepLinkingEnabled=false`.
- GoRouter sets `overridePlatformDefaultLocation=true`.
- One early `AppLinks` instance serves cold- and warm-start delivery.
- `app_links` 7.2.1+ is required for the Flutter 3.44/UIScene lifecycle used by
  this project.

This follows Flutter's third-party deep-link migration guidance:
[deep-link flag change](https://docs.flutter.dev/release/breaking-changes/deep-links-flag-change).

## Android App Links

The manifest registers only the avis-pbook host and explicitly disables
cleartext application traffic and Android backup.

Serve the completed Digital Asset Links file at:

```text
https://avis-pbook.tail651ec3.ts.net/.well-known/assetlinks.json
```

Template: [`docs/well-known/assetlinks.json`](well-known/assetlinks.json)

Before release:

1. Establish a stable release keystore; do not use the debug key for release.
2. Replace the placeholder SHA-256 certificate fingerprint.
3. Serve the file as JSON without redirects or authentication.
4. Verify the HTTPS response and then run:

   ```bash
   adb shell pm get-app-links com.avidullu.agentforge
   adb shell am start -W -a android.intent.action.VIEW \
     -d "https://avis-pbook.tail651ec3.ts.net/avidullu/agentforge/pulls/1"
   ```

Custom-scheme development test:

```bash
adb shell am start -W -a android.intent.action.VIEW \
  -d "agentforge://pr/avidullu/agentforge/1"
```

## iOS Universal Links

Template: [`docs/well-known/apple-app-site-association`](well-known/apple-app-site-association)

Serve it at:

```text
https://avis-pbook.tail651ec3.ts.net/.well-known/apple-app-site-association
```

It must contain the real Apple Team ID, have `Content-Type: application/json`,
and be available without a filename extension, redirect, or authentication.

iOS 14+ normally retrieves association metadata through Apple's public CDN.
Because avis-pbook is tailnet-only, development-signed builds use the associated
domain `applinks:avis-pbook.tail651ec3.ts.net?mode=developer`. This requires
developer mode on the device and is not a distribution strategy. A distributed
app needs a publicly reachable metadata host or an appropriate managed-domain
deployment decision. See [Apple Associated Domains](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.developer.associated-domains).

Simulator/custom-scheme test:

```text
agentforge://pr/avidullu/agentforge/1
```

## Current operational blockers

At the 2026-07-18 audit:

- Android 16 AVD install/launch and warm custom-scheme navigation to
  `avidullu/agentforge #1` passed.
- Both live `/.well-known` URLs returned HTTP 404.
- Both repository templates contained signing placeholders.
- Android release signing still used development configuration.
- No Gmail-to-app HTTPS CUJ had been recorded on Android or iOS.

Milestone 0 is complete only after the real Gmail HTTPS journey passes on both
target platforms with the correct authority and PR displayed.

## Required tests

- Pure parser: trusted host accepted; other hosts and malformed paths rejected.
- Android cold/warm App Link and custom scheme.
- iOS cold/warm Universal Link and custom scheme under UIScene.
- Cold-link navigation retains visible Home, Settings, and Forgejo fallback.
- Warm-link navigation protects unsent drafts.
- Link authority must match the configured Forgejo instance identity.

Package identity: `com.avidullu.agentforge`.
