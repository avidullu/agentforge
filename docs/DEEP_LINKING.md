# Deep Linking Setup (Gmail → App)

**Goal of Milestone 0**: Click a Forgejo PR link inside Gmail and land directly inside AgentForge on the correct PR.

## Supported URL shapes

The Dart router + `deepLinkToLocation` accept:

| Source | Example |
|--------|---------|
| HTTPS Forgejo (`pulls`) | `https://avis-pbook.tail651ec3.ts.net/Khelsutra/badminton-highlight-indexer/pulls/611` |
| HTTPS Forgejo (`pull`) | `https://avis-pbook.tail651ec3.ts.net/owner/repo/pull/42` |
| Custom scheme (debug) | `agentforge://pr/owner/repo/42` |
| Custom scheme (path) | `agentforge://open/owner/repo/pulls/42` |

The host is ignored for routing; only the path (or custom-scheme segments) matters.

## What is wired in the repo

| Layer | Status |
|-------|--------|
| `go_router` PR routes | Yes — `/:owner/:repo/pulls/:number` and `.../pull/:number` |
| `app_links` cold start | Yes — `main.dart` sets `initialLocationProvider` |
| `app_links` warm start | Yes — `DeepLinkListener` |
| Android intent-filters | Yes — HTTPS App Links + `agentforge://` |
| iOS custom scheme | Yes — `CFBundleURLTypes` → `agentforge` |
| iOS Associated Domains | Yes — `Runner.entitlements` → `applinks:avis-pbook.tail651ec3.ts.net` |
| Domain verification files | Templates in `docs/well-known/` — **must be hosted** for verified App/Universal Links |

## Android

Intent filters live in `android/app/src/main/AndroidManifest.xml`:

- **App Links** (`autoVerify=true`) for `https://avis-pbook.tail651ec3.ts.net/.../pulls|pull/...`
- **Custom scheme** `agentforge://pr/...` and `agentforge://open/...` for adb testing without verification

### Host Digital Asset Links

Serve at:

```text
https://avis-pbook.tail651ec3.ts.net/.well-known/assetlinks.json
```

Template: [`docs/well-known/assetlinks.json`](./well-known/assetlinks.json)

1. Build a debug APK once, then get the cert fingerprint:

   ```bash
   keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
   ```

2. Put the SHA-256 fingerprint into `assetlinks.json` and host it on the Forgejo host (reverse proxy / static file — Forgejo itself may need a front-door route for `/.well-known/`).

3. Verify:

   ```bash
   adb shell pm get-app-links com.avidullu.agentforge
   ```

### Quick test without assetlinks (custom scheme)

```bash
adb shell am start -a android.intent.action.VIEW \
  -d "agentforge://pr/Khelsutra/badminton-highlight-indexer/611"
```

Or with a full HTTPS URL (works after App Links verification, or via disambiguation dialog):

```bash
adb shell am start -a android.intent.action.VIEW \
  -d "https://avis-pbook.tail651ec3.ts.net/Khelsutra/badminton-highlight-indexer/pulls/611"
```

## iOS

1. **Custom scheme** (works in Simulator immediately): open  
   `agentforge://pr/Khelsutra/badminton-highlight-indexer/611`
2. **Universal Links** need:
   - Associated Domains entitlement (already in `ios/Runner/Runner.entitlements`)
   - Apple Team ID in AASA (`docs/well-known/apple-app-site-association`)
   - File hosted at  
     `https://avis-pbook.tail651ec3.ts.net/.well-known/apple-app-site-association`  
     (no `.json` extension; `Content-Type: application/json`)
   - App signed with that Team ID

Replace `TEAMID` in the AASA template with your Apple Developer Team ID.

## Gmail CUJ (real device)

1. `flutter run` on a real phone (same Tailscale network as avis-pbook if you will later load PR APIs).
2. Email yourself a real PR link from avis-pbook.
3. Tap the link → AgentForge opens → PR Detail shows correct owner / repo / number.
4. If HTTPS does not open the app yet (verification pending), use the custom scheme or long-press → Open with AgentForge.

Once the HTTPS path works end-to-end from Gmail, Milestone 0 is complete.

## Package identity

- Application ID / bundle ID: `com.avidullu.agentforge`
- Display name: `AgentForge`
