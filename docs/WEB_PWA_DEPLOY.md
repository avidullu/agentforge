# Web PWA deployment (tailnet)

**Status:** IN PROGRESS — device-verified on iOS; Android install path unverified.

AgentForge's release Web build can be installed to a phone home screen as a PWA
and served entirely inside the tailnet. This is the only mobile path that needs
no Apple Developer account, no macOS, and no code signing.

Throughout this document `forge.example.test` stands for your real Forgejo
origin. The real value is never committed — see [PII redaction](11-PII-Redaction.md).

## Why same-origin matters

The app is served as a **path on the Forgejo host**, not on a separate origin:

```
https://forge.example.test/            -> tailscale serve proxy -> Forgejo :3000
https://forge.example.test/agentforge/ -> tailscale serve path   -> static build
```

Because the page origin and the Forgejo API origin are identical, the browser
makes no cross-origin requests. **No Forgejo CORS configuration is required.**
Serving the app from a different host would require relaxing CORS on Forgejo,
which is a larger security decision — prefer the same-origin layout.

The PAT is also never sent to a third origin, and the whole surface stays
tailnet-only because `tailscale serve` publishes to the tailnet by default.

## Prerequisites

- `config/agentforge.config.json` exists locally with the real origin. It is
  gitignored. Copy `config/agentforge.config.example.json` and edit
  `forgejo.origin`.
- SSH access to the host running Forgejo (Tailscale SSH is fine).
- `tailscale serve` already fronting Forgejo on `/`.

## Deploy

```bash
bash tool/deploy_web.sh --host <user@your-forgejo-host>
```

That script regenerates the build config, builds
`flutter build web --release --base-href=/agentforge/`, streams the artifact over
SSH, swaps it into place, and registers the `tailscale serve` path. Use
`--build-only` to produce `build/web` without touching the remote host.

`rsync` is deliberately not used — it is absent on some targets (a ChromeOS
Crostini container, for example), so the script streams a tar over SSH instead.

## Install on a phone

Both platforms need Tailscale connected and the device on the same tailnet.

- **iOS (Safari):** open `https://forge.example.test/agentforge/` → Share →
  *Add to Home Screen*. Safari does not require a service worker to install.
- **Android (Chrome):** open the same URL → menu → *Install app* / *Add to
  Home screen*.

Then set the Forgejo URL and a personal access token in Settings. Issue a
**separate PAT per device** so a single lost phone can be revoked on its own.

Any number of devices can use one deployment. The build-time `trustedHost` pins
which *Forgejo server* the app may talk to; it does not restrict which client
devices may connect.

## Known limitations

- **No offline support.** Flutter 3.44 generates a self-unregistering service
  worker stub, so nothing is cached and every launch needs the tailnet
  reachable. On Android this may also mean Chrome offers only a plain home-screen
  shortcut rather than a full WebAPK install, since Chrome's install criteria
  have historically required a service worker with a `fetch` handler.
- **Credential durability.** On web, `flutter_secure_storage` falls back to
  browser storage. iOS can evict a PWA's script-writable storage after long
  disuse, which means re-entering the PAT.
- **No native deep links.** The Universal Link / custom-scheme work in
  [DEEP_LINKING.md](DEEP_LINKING.md) applies to the native apps only. A Forgejo
  link tapped in a mail client opens the browser, not the installed PWA.
- **One Forgejo instance per build.** `AppSettings.baseUrlValidationError`
  compares against a single `trustedHost`; multiple instances would require a
  host allowlist and per-origin credential scoping.

## Updating a deployment

Re-run `tool/deploy_web.sh`. The static files carry no `Cache-Control` header
(only `Last-Modified`), so reload the page — or close and reopen the installed
app — to pick up a new build.
