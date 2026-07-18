# Bug: Personal / environment-specific info is hard-coded across the project

**Type:** Privacy / maintainability / security defect

**Status:** OPEN — revision 3 (addressing PR #3 second-pass review, request-changes)

**Filed:** 2026-07-18 · **Revised:** 2026-07-18 (rev 3)

**Owner:** `avidullu`

**PR:** [Forgejo #3](https://avis-pbook.tail651ec3.ts.net/avidullu/agentforge/pulls/3)
(evidence link uses the private host only inside this in-flight planning PR;
once merged, the public tracker cites SHA + GitHub-mirror evidence per §7.2.)

---

> **Revision 3 note.** Rev 2 was blocked by the second-pass review (id 246,
> commit-pinned at head `9334af0`) for eight architectural reasons. This
> revision is grounded in **four owner-locked decisions** (§1.1) that
> collapse several findings outright, then resolves every remaining
> finding. The biggest shifts from rev 2: the **application/bundle id is
> kept** (no sandbox/App-Link breakage), the **Tailscale FQDN is the
> primary redaction target**, and the workstream is re-derived as a
> **topological** graph (not "sequential"), with PR #3 given its own
> truthful planning row.

## 1. Summary

The repository hard-codes owner-specific and machine-specific identifiers
in tracked source, native config, tests, and docs. Impact:

1. **Leaks personal/infra info** to the public GitHub mirror — primarily
   the private Tailscale FQDN, plus owner username, real name, and a
   Windows local path.
2. **Makes the project non-portable** — a fork needs many edits to run.
3. **Contradicts the stated privacy goal** (`README.md`: "private tailnet
   operation").
4. **Credential-reuse hazard** — no binding between a persisted PAT and
   the Forgejo origin it belongs to (§3.2).

### 1.1 Owner-locked decisions (crux — do not re-litigate)

| # | Decision | Effect on the plan |
|---|---|---|
| D1 | **Keep** the application id / iOS bundle id = `com.<OWNER>.agentforge`. It is allow-listed provenance (like the canonical repo ref). | Collapses review-246 finding 6 entirely: no sandbox break, no App-Link re-verification, no token migration. |
| D2 | **Neutralize the Kotlin source path** to `android/app/src/main/kotlin/dev/agentforge/app/` and Gradle namespace `dev.agentforge.app`. The `applicationId` stays `com.<OWNER>.agentforge` (path ≠ id). | Removes `<OWNER>` from the source tree path without touching Android identity. |
| D3 | **The Tailscale FQDN MUST be redacted** from the tracked tree. It is the #1 redaction target. | Strictest option. Every `https://<HOST>/...` link in docs/tracker becomes SHA + GitHub-mirror evidence (§7.2). |
| D4 | **PR evidence** is `Forgejo #N @ <short-sha>` + a link to the equivalent commit on the public GitHub mirror `github.com/<OWNER>/agentforge`. | Immutable provenance; no private host in tracked links. |

## 2. Evidence (masked, reproducible — review finding 8)

### 2.1 Reproducible audit (NUL-safe, tracked files only)

The rev-2 audit used `git ls-files | xargs` with private placeholders and
could not be reproduced. This revision provides a **NUL-safe, copy-pasteable**
PowerShell command and a **real per-category count** on a pinned commit.

```powershell
# From a clean checkout of origin/main (commit 37732b4). NUL-safe via Select-String.
$patterns = 'avidullu|avis-pbook|tail651ec3|Avi Dullu|avis-msi|C:\\Users\\avidu'
$files = git ls-files | ForEach-Object {
  $f = $_
  if (Select-String -Path $f -Pattern $patterns -Quiet -ErrorAction SilentlyContinue) { $f }
}
"matching files: $($files.Count)"
```

**Verified result on `origin/main` @ `37732b4`:** **24 tracked files** match.
(At PR #3 head `9334af0`: 25, because the bug doc itself adds one.) The rev-2
claim of "27" was wrong; this matches the review's count exactly.

Per-category counts on `origin/main` @ `37732b4` (some files match several):

| Pattern | Files |
|---|---|
| `avidullu` | 14 |
| `avis-pbook` | 13 |
| `tail651ec3` | 11 |
| `Avi Dullu` | 1 |
| `avis-msi` | 2 |
| `C:\Users\avidu` | 2 |

> **Blocklist vs. public patterns.** The six patterns above are the
> owner-specific blocklist and are **not** committed to the public tree
> (§5.4). They are reproduced here only inside this in-flight planning PR
> to make the audit verifiable; after merge, the public tracker cites the
> masked counts and the pinned commit, not the patterns.

### 2.2 Categories (masked)

| Category | Masked token | Where (representative, tracked) |
|---|---|---|
| Private Tailscale FQDN | `<HOST>` | `lib/core/deep_links/deep_link.dart`, `lib/core/settings/app_settings.dart`, `test/deep_link_test.dart`, `test/forgejo_*_test.dart`, `android/.../AndroidManifest.xml`, `ios/Runner/Runner.entitlements`, `docs/well-known/*`, `tool/demo_avis_pbook.dart`, `docs/*.md`, `README.md`, UI strings |
| Local Windows path | `<USERPATH>` | `HANDOFF.md`, `SESSION_HANDOFF.md` |
| Owner identity | `<OWNER>` | `README.md`, `docs/08-*`, `docs/AGENT_MCP_CONTRACT.md`, `test/forgejo_models_test.dart`, `android/app/build.gradle.kts` (`applicationId` — **kept, D1**), `docs/well-known/*` |
| Kotlin source path | `<OWNER>` (path segment) | `android/app/src/main/kotlin/com/<OWNER>/agentforge/` (**redacted via D2**) |
| Display name | `<REALNAME>` | `test/forgejo_models_test.dart` |
| Machine hint | `<MACHINE>` | `lib/features/agents/agents_screen.dart` hint text |

## 3. Impact

### 3.1 Privacy / portability / maintainability

As §1. The public GitHub mirror currently discloses the private FQDN, the
owner username, a real name, and a Windows user path.

### 3.2 Credential reuse (review-246 finding 3, kept from rev 2)

`SettingsRepository` stores one global PAT under key `forgejo_token`
(`lib/core/settings/settings_repository.dart`); `ForgejoClient` sends it to
whatever `baseUrl` is configured (`lib/core/forgejo/forgejo_client.dart`).
Once builds accept a configurable origin, an upgraded install could silently
send an old PAT to a new host. **Note:** under D1 the application id is
unchanged, so the secure-storage sandbox is preserved across the upgrade —
which makes the origin-binding fix purely a *logic* change, not a data
migration. This is significantly simpler than rev 2's migration story and
is addressed in §5.5.

## 4. Goals / non-goals

**Goals**

- Remove `<HOST>`, `<USERPATH>`, `<REALNAME>`, `<MACHINE>`, and the
  `<OWNER>` source-path segment from the **tracked** tree.
- Keep `com.<OWNER>.agentforge` and the canonical `<OWNER>/agentforge`
  repository reference as narrow, allow-listed provenance (D1, D4).
- Provide **one versioned, validated** config schema that derives every
  consumer (Dart, Android manifest placeholders, Xcode settings/entitlements,
  well-known JSON) so they cannot drift.
- Bind persisted credentials to the exact normalized origin; on origin
  mismatch, surface a "credential entered for a different instance" state
  and require re-entry (no silent reuse).
- Prevent regression with a guard that is **fail-closed at the canonical
  pre-merge gate** and consumes an owner-specific blocklist kept outside
  the public tree (review-246 finding 4).
- **Scope wording (precise).** "Current-tree/default sanitization": the
  checked-in tree contains no redacted identifiers by default. Git
  **history** and **author/committer metadata** are explicitly out of
  scope; a destructive history rewrite is deferred.

**Non-goals**

- Changing the owner's actual username/Tailscale host.
- Editing `build/`, `build/web/`, or `unit_test_assets/` (gitignored,
  regenerated). Tracked `web/` source **is** in scope (§7.3).
- Re-licensing / distribution model (that is `AF-008`).
- Rewriting git history (destructive; deferred).
- Putting tokens or secrets into `--dart-define` (dart-defines are embedded
  configuration, not a secret store). Rev 3 **removes** the stray
  dart-define references that rev 2 left in §12/S1 (review-246 finding 5
  cleanup).
- Changing the application id / bundle id (D1).

## 5. Architecture (one schema, derived everywhere; build- vs release-validated)

### 5.1 One versioned schema: `config/agentforge.config.json`

```jsonc
// shape — the canonical file is config/agentforge.config.schema.json (JSON Schema)
{
  "schemaVersion": 1,
  "forgejo": {
    "origin": "https://<HOST>"             // normalized HTTPS, port 443 ONLY
  },
  "app": {
    "applicationId": "com.<OWNER>.agentforge",   // KEPT (D1); allow-listed
    "gradleNamespace": "dev.agentforge.app",     // D2, neutral source path
    "urlScheme": "agentforge"
  },
  "signing": {
    "androidSha256Fingerprints": [],   // required for release validation only
    "appleTeamId": ""                  // required for release validation only
  }
}
```

- The **trusted host is derived** from `forgejo.origin` by the generator
  (§5.3 normalization). There is no independent `trustedHost` field.
- Real values live in `config/agentforge.config.json` (gitignored). A
  checked-in `config/agentforge.config.example.json` uses synthetic values
  (`https://forge.example.test`, `com.example.agentforge`,
  `dev.agentforge.app`) so a fresh clone builds immediately.
- `canonicalOwnerRepo` from rev 2 is removed — owner/repo is not a runtime
  config value and stays as allow-listed provenance in docs.

### 5.2 Two validation modes (review-246 finding 5)

Rev 2 conflated build validation with release validation. Rev 3 splits them:

- **Build-safe validation** (runs on every analyze/test/build, including
  CI and clean clones): origin is HTTPS, port **exactly 443** (reject, not
  warn, any other port — review-246 finding 5), no userinfo/path/query;
  `applicationId`/`gradleNamespace`/`urlScheme` non-empty and well-formed;
  `schemaVersion` exactly the supported value. Missing/empty `signing`
  fields are **allowed** at build time.
- **Release/deployment validation** (runs only when rendering well-known
  files for deployment): **fails closed** on missing/malformed
  `androidSha256Fingerprints` and `appleTeamId`, and on any non-empty
  placeholder remaining in rendered output.

These are two entry points on the same generator:
`dart run tool/generate_config.dart` (build) vs.
`dart run tool/generate_config.dart --release` (deployment render).

### 5.3 Generator + bootstrap (review-246 findings 2, 3)

`tool/generate_config.dart` is the single entry point. It reads the schema,
runs the §5.2 build validation, and emits:

- `lib/core/config/generated/app_config.gen.dart` — **`const`** Dart config
  (see §5.4).
- `android/agentforge-config.properties` (at the **repo root**, not under
  `android/app/`), loaded in `build.gradle.kts` via
  `rootProject.file("agentforge-config.properties")` (review-246 finding 3c
  corrected: the rev-2 path resolved under the module).
- `ios/Runner/Generated.xcconfig`, consumed at the **project level** so it
  overrides target-level bundle ids; rev 3 also removes the per-target
  `PRODUCT_BUNDLE_IDENTIFIER` overrides in `project.pbxproj` and lets the
  xcconfig win (review-246 finding 3b).
- Native scheme output: the Android manifest and both iOS plists register
  the scheme via a generated placeholder, not a hard-coded literal
  (review-246 finding 3b).

**Bootstrap (review-246 finding 2 — clean clone + CI):**

- A **checked-in synthetic default** `app_config.gen.dart` is committed
  (generated from `config/agentforge.config.example.json`), so a clean
  clone builds with zero pre-steps. This file is tracked.
- The generator runs as a **`pubspec.yaml` pre-build hook via
  `hooks/pre_build.dart`** (Dart 3.5+ pub hooks) on every
  `flutter pub get`/build, regenerating `app_config.gen.dart` from the
  local `config/agentforge.config.json` if present, else from the example.
- **No silent release fallback:** the release Web/APK job in CI sets
  `AGENTFORGE_CONFIG` to the real (secret-protected) config file before
  build; if it is absent, the release job fails closed rather than shipping
  an example-config artifact (review-246 finding 2).
- Local equivalent documented in `docs/CONFIGURATION.md`:
  `cp config/agentforge.config.example.json config/agentforge.config.json`,
  edit, then `flutter pub get`.

### 5.4 Dart design — `const`, not getters (review-246 finding 3a)

Rev 2 described `AppSettings.defaultBaseUrl` / `trustedHost` as **getters**.
The current call sites require compile-time constants:
`settings_screen.dart:154-159`, `forgejo_models_test.dart:51-60`,
`forgejo_providers_test.dart:79-83`, `widget_test.dart:16-44`. Rev 3
corrects this:

- `app_config.gen.dart` emits `const class AppConfig { static const String defaultBaseUrl = ...; static const String trustedHost = ...; static const String appScheme = ...; }` — **`const`**, not getters, so every existing `const` call site compiles after aliasing.
- `AppSettings.defaultBaseUrl` / `trustedHost` become `static const` aliases that delegate to `AppConfig.*`, preserving the existing API surface so callers don't all change in the same PR.
- `deep_link.dart`'s `kForgejoHost` becomes `const kForgejoHost = AppConfig.trustedHost;`.
- **Non-secret guarantee:** the JSON Schema forbids property names
  `token`/`secret`/`password`, and a unit test asserts the generated file
  contains none of those identifiers. dart-defines are no longer referenced
  anywhere (rev-2 cruft removed).

### 5.5 Origin-bound credentials (review-246 finding 3; simplified by D1)

Under D1 the app sandbox is unchanged across the upgrade, so this is a
pure logic change:

- Storage keys become origin-scoped: `forgejo_token::<normalizedOrigin>`.
- `load(currentOrigin)` returns the PAT only if it was stored for that
  origin; otherwise returns empty and surfaces a typed
  `CredentialOriginMismatch` state the UI renders as "credential entered
  for a different instance."
- On origin change: **never** carry an old PAT to a new origin; prompt
  re-entry. `clearToken(origin)` is scoped.
- **Legacy key behavior (decided, not ambiguous as in rev 2):** the
  pre-redaction key is `forgejo_token` with no origin bound. On first load
  under the new code, the migration **deletes** the legacy key (it cannot
  be attributed to any specific origin, so binding it would be a guess).
  The user is prompted to re-enter the PAT for the current origin. This is
  the safe choice rev 2 left ambiguous.
- **Upgrade test:** seeds the legacy `forgejo_token` key, runs migration,
  configures a non-legacy origin, and asserts (a) the legacy key is gone,
  (b) no PAT is sent to the new origin, (c) the UI shows the mismatch
  prompt. This is the proof an old token can never reach a new host.

## 6. Native specifics (collapsed by D1/D2)

### 6.1 Android

- `applicationId` **stays** `com.<OWNER>.agentforge` (D1).
- `namespace` becomes `dev.agentforge.app`; the Kotlin source directory
  moves from `android/app/src/main/kotlin/com/<OWNER>/agentforge/` to
  `android/app/src/main/kotlin/dev/agentforge/app/`; `MainActivity.kt`
  gets `package dev.agentforge.app`. Namespace and source package match,
  so `AndroidManifest.xml`'s `.MainActivity` resolves.
- **No debug suffix, no flavor gymnastics** (rev 2's `applicationIdSuffix`
  is dropped — it was only needed for the identity-migration path that D1
  eliminates, and it would have broken App-Link verification per
  review-246 finding 6).
- The manifest host is a placeholder `${forgejoHost}` filled from
  `rootProject.file("agentforge-config.properties")` (§5.3).
- **Verified-link CUJ depends on AF-002** (review-246 finding 7):
  App-Link `autoVerify` needs a hosted `assetlinks.json` matching the
  kept application id + signing fingerprint, which is AF-002's release-
  signing work. Until AF-002 lands, the deep-link CUJ is **unverified
  intent routing only**, recorded as such in the tracker.
- **Verification bar:** `flutter build apk --debug` + install + launch on
  an AVD + custom-scheme deep-link route on the installed build (CI runs
  the build only; the AVD CUJ is a manual gate recorded in the row).

### 6.2 iOS

- `PRODUCT_BUNDLE_IDENTIFIER` stays `com.<OWNER>.agentforge` (D1); the
  per-target overrides in `project.pbxproj` are removed so the
  `Generated.xcconfig` value is the single source.
- The Associated Domains host in `Runner.entitlements` is generated from
  `forgejo.origin`.
- **Verification:** `xcodebuild -showBuildSettings` confirms the override
  resolves; rendered plists/AASA parse with no unresolved placeholders;
  iOS no-sign verification is **macOS-only** and explicitly skipped on
  non-mac CI with a recorded reason (review-246 finding 6: verified
  Universal Links also depend on AF-002's Apple Team ID).

## 7. Docs, handoffs, and tracked `web/` (review-246 findings 7, 8 + scope clarification)

### 7.1 Handoffs and user-facing docs

- `<USERPATH>` in `HANDOFF.md` / `SESSION_HANDOFF.md` → "shared project-
  memory store (path resolved by the `claude-sync` tooling per machine)."
- `<HOST>` in user-facing docs → `<your-forgejo-host>` + the override step
  in a new `docs/CONFIGURATION.md`.
- `<REALNAME>` and `<MACHINE>` removed from test fixtures / UI hints and
  replaced with synthetic equivalents.

### 7.2 Forgejo PR evidence (D4, scope clarification)

The review's scope clarification is accepted in full: keep public
owner/repo identity and immutable SHA provenance; the **private Tailscale
FQDN is a separate classification decision and D3 redacts it**. Therefore
all `https://<HOST>/.../pulls/N` links in `docs/08-*`, `README.md`, and
this bug doc become:

```md
[Forgejo #N @ <short-sha>](https://github.com/<OWNER>/agentforge/commit/<full-sha>)
```

i.e. PR number + short SHA + a link to the equivalent commit on the public
GitHub mirror. No private host appears in tracked links.

### 7.3 Tracked `web/` (review-246 finding 8)

`web/` is **tracked source** in this repo (generated output is
`build/web/`, gitignored). S7 sweeps `web/index.html`, `web/manifest.json`,
and `web/main.dart.js` for `<HOST>`/`<OWNER>` and either redacts or
regenerates them from the example config. **Release-Web build is added to
the workstream DoD** (§11) because the generated Dart config affects Web.

## 8. CI and guard (review-246 finding 4 — fail-closed canonical gate)

- **Canonical pre-merge gate (Forgejo Actions) runs in BLOCKLIST mode and
  FAILS CLOSED.** `$AGENTFORGE_PII_BLOCKLIST` is materialized from a
  Forgejo secret to a `600`-mode temp file on the runner, consumed by
  `tool/check_no_pii.dart`, and deleted in a `finally` step. The blocklist
  file is **never** echoed, logged, or uploaded as an artifact
  (review-246 finding: the blocklist itself is the PII).
- The guard checks **all tracked scopes** — `lib/`, `test/`, `tool/`,
  `android/`, `ios/`, `web/`, `docs/`, plus repo-root markdown — and
  covers content, paths, and filenames with case-insensitive and
  path-segment variants. Generic, not host-literal-only.
- **Public/fork secondary gate (`.github/workflows/ci.yml` on GitHub):**
  runs **structural mode only** (no secret), asserting the synthetic
  example is in use and no `https://` host literal appears in
  `lib/`/`test/`/`tool/`. This is a regression backstop, not the privacy
  claim — the privacy claim rests on the canonical blocklist gate.
- **Allow-list (narrow, structural selectors — review-246 finding on
  selector format):** each entry is a regex + scope pair, e.g.
  `^README\.md$:^\\| Canonical \\| .*github\\.com/<OWNER>/agentforge`.
  The allow-list lives in the same non-public blocklist file. Entries are
  regex-based (not line numbers — line numbers are fragile), evaluated
  against the matching line so a change to an allow-listed line's content
  re-triggers review.

## 9. Implementation strategy — topological, one row per PR (review-246 finding 7)

**Rule:** each branch starts from a **fresh `origin/main` after all its
dependencies have merged** (not "sequential off the previous branch").
PR #3 (this planning PR) gets its **own** ledger row — the workstream is
**8 shippable PRs**, not 7.

| Step | Ledger | Scope | Depends on | CI gate (per PR) |
|---|---|---|---|---|
| S0 | AF-016 | **This planning PR.** Lands the approved bug doc + tracker rows + stale-PR-description fix. No code. | — | docs-only; format/analyze/test unchanged |
| S1 | AF-009 | Schema + generator (build + release validation) + pub-hook bootstrap + checked-in synthetic `app_config.gen.dart` + structural `check_no_pii` scaffold + CI wiring (blocklist gate fail-closed). **Report-only guard against synthetic fixtures — no source/test cleanup yet** (review-246 finding 1). | AF-016 | analyze clean; generator produces synthetic output; structural guard green on a synthetic fixture; release job fails closed on missing signing |
| S2 | AF-010 | Origin-bound credential store + legacy-key deletion migration + upgrade test (D1 ⇒ no sandbox issue) | AF-009 | new tests green; legacy-key-deletion test passes; coverage ≥ 29% |
| S3 | AF-011 | Wire Dart source to `AppConfig` (`deep_link.dart`, `app_settings.dart`, UI strings, providers) via **const aliases**; remove `<HOST>` literals from `lib/` | AF-010 (review-246 finding 7: origin changes cannot land before origin-bound credentials) | deep-link + provider tests green with synthetic config; blocklist guard green on `lib/` |
| S4 | AF-012 | Tests/tool swap to synthetic fixtures; rename `tool/demo_avis_pbook.dart` → `tool/demo_forgejo.dart`; remove `<REALNAME>`/`<MACHINE>` | AF-011 | `flutter test --coverage` ≥ 29%; blocklist guard green on `test/`+`tool/` |
| S5 | AF-013 | Android: neutral namespace + source-path move (D2); kept `applicationId` (D1); manifest host placeholder; AVD custom-scheme CUJ (verified links → AF-002) | AF-011 (review-246 finding 7: Dart rejects new host otherwise) | `flutter build apk --debug`; AVD install+launch+custom-scheme route (manual, recorded) |
| S6 | AF-014 | iOS: remove per-target bundle-id overrides; entitlement host from config; `-showBuildSettings`; rendered plist/AASA validation; macOS no-sign | AF-011 | settings resolve; plists/AASA valid, no unresolved placeholders |
| S7 | AF-015 | Docs/handoff redaction + Forgejo-PR-link rewrite (D4) + `docs/CONFIGURATION.md` + well-known templates/render + tracked-`web/` sweep | AF-010, AF-012, AF-013, AF-014 (review-246 finding 7: not AF-003) | blocklist gate green on `main`; release-Web build green; docs render |

> **Verified-link gates** (App-Link `autoVerify`, Universal Links) remain
> under **AF-002** (release signing), not in this workstream
> (review-246 finding 7). The custom-scheme CUJ in S5 is unverified intent
> routing until AF-002.

## 10. Tracker updates (added in this revision)

- Adds ledger rows **AF-016 (this PR), AF-009…AF-015** (8 total) to
  `docs/08-Implementation-Plan-and-Milestones.md` with the dependencies
  from §9.
- Rewrites prior Forgejo PR evidence links in `docs/08-*` to the D4
  format (PR-number + short-SHA + GitHub-mirror link), since the act of
  editing the tracker in this PR already touches those lines.
- Changelog entry updated to rev 3.

## 11. Acceptance criteria (Definition of Done for the AF-009 workstream)

- [ ] Canonical Forgejo Actions gate runs `tool/check_no_pii.dart` in
      **blocklist mode, fail-closed**, on every PR and on `main`; the
      blocklist secret is materialized to a `600` temp file and never
      logged/uploaded.
- [ ] No **tracked** file under `lib/`, `test/`, `tool/`, `android/`,
      `ios/`, `web/`, `docs/`, or repo-root markdown contains `<HOST>`,
      `<USERPATH>`, `<REALNAME>`, `<MACHINE>`, or the `<OWNER>` source-path
      segment — except the narrow, regex-scoped provenance allow-list
      (`com.<OWNER>.agentforge` application id; canonical repo reference).
- [ ] A clean clone builds and runs against the checked-in synthetic
      `app_config.gen.dart` with **zero** pre-steps; release jobs fail
      closed on missing real config.
- [ ] One schema → all consumers (Dart const, Android properties, Xcode
      xcconfig, native scheme, well-known JSON); generator cross-checks
      and rejects drift; build vs release validation split enforced.
- [ ] Credentials are origin-bound; legacy `forgejo_token` is deleted on
      migration; upgrade test proves no PAT reaches a different origin.
- [ ] `flutter analyze --fatal-infos`, `flutter test --coverage` (≥ 29%),
      `dart format --set-exit-if-changed`, `flutter build apk --debug`,
      **and `flutter build web --release`** all pass (release-Web added
      per review-246 finding 8).
- [ ] Rendered well-known JSON/plists parse with no unresolved
      placeholders; iOS settings verified via `-showBuildSettings` (macOS
      no-sign on mac only).
- [ ] `docs/CONFIGURATION.md` documents the schema, generator, pub hook,
      overrides, and the no-secrets rule.
- [ ] Ledger rows AF-016 + AF-009…AF-015 present with accurate status,
      dependencies, and PR links; changelog updated; stale Forgejo-PR
      evidence rewritten to D4 format.

## 12. Finding-by-finding response (second-pass review, id 246)

| # | Finding | Resolution in rev 3 |
|---|---|---|
| 1 | S1 guard can't pass staged sequence | S1 runs a **report-only** guard against **synthetic fixtures**; source/test cleanup is deferred to S3/S4. Every intermediate PR stays green. (§9 S1) |
| 2 | No clean-clone/CI bootstrap for gitignored inputs | Checked-in synthetic `app_config.gen.dart` + pub-hook pre-build regeneration; release jobs fail closed on missing real config. (§5.3) |
| 3 | Generator graph misses consumers + API/path errors | (a) `AppConfig.*` are **`const`**, not getters — existing const call sites compile; (b) native scheme via generated placeholder, per-target iOS bundle-id overrides removed; (c) `rootProject.file("agentforge-config.properties")` at repo root. (§5.3, §5.4, §6.1) |
| 4 | Canonical CI fail-open for privacy claim | Canonical gate = **blocklist mode, fail-closed**, secret materialized to `600` temp file, never logged; checks all tracked scopes + content/path/filename. (§8) |
| 5 | Origin & association validation inconsistent | **Build-safe vs release-validation split**; port ≠ 443 **rejected** (not warned); empty signing fields allowed at build, fail-closed at release. (§5.2) |
| 6 | Release/debug identity + credential migration incomplete | **D1 keeps the application id** ⇒ no sandbox break, no App-Link re-verification, no token migration. Debug-suffix idea dropped. (§1.1 D1, §6.1) |
| 7 | Ledger/dependency graph wrong | PR #3 gets its own row (**AF-016**); 8 PRs total; **topological** deps (branch from fresh `origin/main` after deps merge); AF-011→AF-010, AF-013/014→AF-011, AF-015→AF-010/012/013/014; AF-003 dependency removed; verified-link gates stay under AF-002. (§9) |
| 8 | Audit not reproducible | NUL-safe PowerShell + pinned commit `37732b4` + **real count 24** + per-category table; release-Web build added to DoD. (§2.1, §11) |

**Scope clarification accepted:** keep public owner/repo + immutable SHA
provenance; private Tailscale FQDN redacted (D3); PR evidence = SHA +
GitHub-mirror link (D4). (§1.1, §7.2)

**Clerical:** PR description rewritten to rev-3 design; broken refs
(`AF-010-history`, `§3 finding C`, `§"ground-truth grep"`) removed; file
count corrected to 24/25.

## 13. Requested third-pass review

Re-requesting review on PR #3 after this revision. The four owner-locked
decisions (§1.1) are not re-opened. Open questions for the reviewer:

- Confirm the **8-PR topological graph** (§9) and the AF-016 planning row
  for this PR match your expectation.
- Confirm the **legacy-key deletion** choice in §5.5 (delete + re-prompt,
  never auto-bind) is acceptable.
- Confirm the **canonical-blocklist fail-closed gate** in §8 satisfies the
  privacy-claim bar.

On LGTM: merge PR #3 → fast-forward GitHub mirror → branch the first
implementation slice (AF-009) from fresh `origin/main` → full verify →
ready-for-review Forgejo follow-up PR.
