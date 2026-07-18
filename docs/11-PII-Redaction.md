# Bug: Personal / environment-specific info is hard-coded across the project

**Type:** Privacy / maintainability / security defect

**Status:** OPEN — revision 5 (addresses review 250 + third-pass leftovers)

**Filed:** 2026-07-18 · **Revised:** 2026-07-18 (rev 5)

**Owner:** repository owner (username omitted from this tracked doc)

**Evidence (D4 — no private host):** Forgejo #3 @ tip of `af-009-pii-redaction-bug`
(use PR head SHA + GitHub-mirror commit link when the branch is pushed; after
merge, pin the merge commit). Planning row: **AF-016**.

---

> **Revision 5 note.** Review 250 (commit-pinned at `c49c668`, still applicable
> after rev 4) blocks on: S1 enabling a fail-closed full-tree gate too early;
> gen-file hygiene (real values must not overwrite tracked synthetic source);
> iOS xcconfig include chain and RunnerTests identity; honest audit command
> claims; tracker “D4 rewrite already done” falsehood. Rev 5 corrects those.
> D1–D4 unchanged. Prior rev-4 P0/P1 public-tree hygiene is retained.

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
| D3 | **The Tailscale FQDN MUST be redacted** from the tracked tree. It is the #1 redaction target. | Strictest option. Every private-host PR link becomes SHA + GitHub-mirror evidence (§7.2). |
| D4 | **PR evidence** is `Forgejo #N @ <short-sha>` + a link to the equivalent commit on the public GitHub mirror `github.com/<OWNER>/agentforge`. | Immutable provenance; no private host in tracked links. |

## 2. Evidence (masked, reproducible — third-pass P0)

### 2.1 Reproducible audit (no live blocklist in the public tree)

**Rule:** this tracked document must never contain the owner-specific
blocklist strings themselves. The blocklist lives only in the non-public
secret file `$AGENTFORGE_PII_BLOCKLIST` (CI) / the operator runbook outside
git.

**Authoritative re-run path (AF-009 ships the tool):**

```bash
# Private patterns file is never committed.
export AGENTFORGE_PII_BLOCKLIST=/path/to/blocklist.txt
dart run tool/check_no_pii.dart --mode=report --scope=tracked
# Uses: git ls-files -z + literal path open (NUL-delimited). Not Select-String.
```

Until that tool lands in S1, operators may use any **literal-path**,
NUL-aware scan of `git ls-files -z` output against the private file. Do
**not** claim newline-delimited `git ls-files | Select-String -Path` is
NUL-safe (review 250 finding 4).

**Verified result on `origin/main` @ `37732b4`:** **24 tracked files** match
the private blocklist (counts reproduced independently by review 250).
Public docs record **counts only**.

Per-category **counts** on `origin/main` @ `37732b4` (opaque categories;
patterns are not listed here):

| Category (masked) | Files |
|---|---|
| Owner login token | 14 |
| Private host product name token | 13 |
| Private host DNS fragment token | 11 |
| Display name token | 1 |
| Machine hint token | 2 |
| Local Windows user path token | 2 |

Some files match more than one category. The private blocklist file is the
authoritative pattern set for CI (§8).

### 2.2 Categories (masked)

| Category | Masked token | Where (representative, tracked) |
|---|---|---|
| Private Tailscale FQDN | `<HOST>` | `lib/core/deep_links/deep_link.dart`, `lib/core/settings/app_settings.dart`, `test/deep_link_test.dart`, `test/forgejo_*_test.dart`, `android/.../AndroidManifest.xml`, `ios/Runner/Runner.entitlements`, `docs/well-known/*`, `tool/demo_*.dart`, `docs/*.md`, `README.md`, UI strings |
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
migration. Addressed in §5.5.

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
  the public tree.
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
- Putting tokens or secrets into `--dart-define`.
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
- Owner/repo is not a runtime config value; it stays as allow-listed
  provenance in docs under D4.

### 5.2 Two validation modes (review-246 finding 5)

- **Build-safe validation** (every analyze/test/build, including CI and
  clean clones): origin is HTTPS, port **exactly 443** (reject any other
  port), no userinfo/path/query; `applicationId`/`gradleNamespace`/
  `urlScheme` non-empty and well-formed; `schemaVersion` exactly the
  supported value. Missing/empty `signing` fields are **allowed** at
  build time.
- **Release/deployment validation** (only when rendering well-known files
  for deployment): **fails closed** on missing/malformed
  `androidSha256Fingerprints` and `appleTeamId`, and on any non-empty
  placeholder remaining in rendered output.

Entry points on the same generator:

- `dart run tool/generate_config.dart` — build-safe
- `dart run tool/generate_config.dart --release` — deployment render
  (fails closed on signing / unresolved placeholders)

### 5.3 Generator + bootstrap (review 250 — supported lifecycle, no tracked private gen)

`tool/generate_config.dart` is the single entry point. It reads the schema,
runs the §5.2 build validation, and emits:

| Output | Tracked? | Notes |
|---|---|---|
| `lib/core/config/generated/app_config.defaults.dart` | **Yes** | Synthetic const from `config/agentforge.config.example.json`. Clean clone builds with zero pre-steps. |
| `lib/core/config/generated/app_config.gen.dart` | **No** (gitignored) | Real-value const overlay when `AGENTFORGE_CONFIG` / local `config/agentforge.config.json` is present. **Never commit.** |
| `agentforge-config.properties` (repo root) | **No** when real; optional tracked example | Loaded via `rootProject.file("agentforge-config.properties")`. |
| `ios/Flutter/AgentForge.xcconfig` | **No** when real; example committed | See §6.2 include chain. **Never** overwrite Flutter-owned `ios/Flutter/Generated.xcconfig`. |
| Native scheme placeholders in manifests/plists | templates tracked | Filled from properties/xcconfig at build time. |

**Import rule (Dart):** `app_config.dart` exports defaults, then conditionally
parts/exports the gitignored gen overlay if present (or uses a tiny
generated barrel). Analyze/test on a clean clone uses **defaults only**.

**Commands (all explicit — no pub hooks):**

```bash
# clean clone / everyday dev against synthetic defaults:
flutter pub get && flutter analyze && flutter test

# local real config (writes gitignored outputs only):
cp config/agentforge.config.example.json config/agentforge.config.json  # edit
dart run tool/generate_config.dart
flutter run

# CI with secret config (fail closed if missing for release jobs):
export AGENTFORGE_CONFIG=/secrets/agentforge.config.json
dart run tool/generate_config.dart
flutter build apk --debug
# association file render only:
dart run tool/generate_config.dart --release
```

**Forbidden:** Dart “pub hooks” / `hooks/pre_build.dart` as a correctness
path; overwriting a tracked synthetic file with private FQDN values (that
dirties the worktree and invites accidental commit — review 250 finding 2).
Optional `tool/bootstrap.sh` may wrap the copy + generate steps for DX only.

### 5.4 Dart design — `const`, not getters (review-246 finding 3a)

- `app_config.gen.dart` emits
  `const class AppConfig { static const String defaultBaseUrl = ...; ... }`
  so existing `const` call sites compile after aliasing.
- `AppSettings.defaultBaseUrl` / `trustedHost` become `static const` aliases
  to `AppConfig.*`.
- `deep_link.dart`'s `kForgejoHost` becomes
  `const kForgejoHost = AppConfig.trustedHost;`.
- **Non-secret guarantee:** schema forbids property names
  `token`/`secret`/`password`; a unit test asserts the generated file
  contains none of those identifiers.

### 5.5 Origin-bound credentials (review-246 finding 3; simplified by D1)

- Storage keys become origin-scoped: `forgejo_token::<normalizedOrigin>`.
- `load(currentOrigin)` returns the PAT only if stored for that origin;
  otherwise empty + typed `CredentialOriginMismatch` UI state.
- On origin change: **never** carry an old PAT; prompt re-entry.
- **Legacy key behavior:** pre-redaction key `forgejo_token` (no origin).
  On first load under the new code, migration **deletes** the legacy key
  (cannot attribute it to an origin). User re-enters PAT for the current
  origin. Never auto-bind.
- **Upgrade test:** seed legacy key → migrate → configure non-legacy origin
  → assert (a) legacy key gone, (b) no PAT sent to new origin, (c) UI shows
  mismatch prompt.

## 6. Native specifics (collapsed by D1/D2)

### 6.1 Android

- `applicationId` **stays** `com.<OWNER>.agentforge` (D1).
- `namespace` becomes `dev.agentforge.app`; Kotlin sources move to
  `android/app/src/main/kotlin/dev/agentforge/app/`; package declaration
  matches so `.MainActivity` resolves.
- No debug `applicationIdSuffix` gymnastics (would break App-Link
  verification under D1).
- Manifest host is placeholder filled from
  `rootProject.file("agentforge-config.properties")` (§5.3).
- **Verified-link CUJ depends on AF-002.** Until AF-002, deep-link CUJ is
  **unverified intent routing only**.
- **Verification bar:** `flutter build apk --debug` + install + launch on
  an AVD + custom-scheme route (CI runs the build; AVD CUJ is a manual
  gate recorded in the row).

### 6.2 iOS (review 250 — real Xcode include chain)

This repo today:

- Target base configs are `ios/Flutter/Debug.xcconfig` and
  `ios/Flutter/Release.xcconfig`, each `#include "Generated.xcconfig"`
  (Flutter-owned, regenerated by the Flutter tool).
- Runner sets `PRODUCT_BUNDLE_IDENTIFIER = com.<OWNER>.agentforge` at
  **target** level; RunnerTests uses
  `com.<OWNER>.agentforge.RunnerTests` (must stay unique).

**Plan (do not invent a parallel “project-level overrides target” myth —
target settings outrank project settings):**

1. Generator emits **`ios/Flutter/AgentForge.xcconfig`** (gitignored when
   real; tracked **example** may ship as `AgentForge.xcconfig.example`).
2. Patch `ios/Flutter/Debug.xcconfig` and `Release.xcconfig` to:

   ```xcconfig
   #include "Generated.xcconfig"
   #include "AgentForge.xcconfig"   // after Flutter; may set bundle + host
   ```

3. In `AgentForge.xcconfig` (from config):
   - `PRODUCT_BUNDLE_IDENTIFIER=com.<OWNER>.agentforge` for the **Runner**
     target only via an include used by Runner’s base config, **or** keep
     Runner target setting as today and only put host/entitlement-related
     keys in AgentForge.xcconfig.
4. **RunnerTests identity (required):** keep an explicit target-level
   `PRODUCT_BUNDLE_IDENTIFIER = com.<OWNER>.agentforge.RunnerTests` (or
   `$(PRODUCT_BUNDLE_IDENTIFIER).RunnerTests` only if the parent is
   guaranteed to be the app id). Never remove both targets’ bundle IDs
   such that tests inherit the app id.
5. Associated Domains host still comes from generated entitlement input
   derived from `forgejo.origin`.
6. **Do not** write into `ios/Flutter/Generated.xcconfig` (Flutter-owned).

**Verification:** for **both** Runner and RunnerTests,
`xcodebuild -showBuildSettings -target <name>` shows the expected
identifiers; rendered plists/AASA parse with no unresolved placeholders;
macOS-only no-sign checks skipped on non-mac CI with a recorded reason.

## 7. Docs, handoffs, and tracked `web/`

### 7.1 Handoffs and user-facing docs

- `<USERPATH>` → "shared project-memory store (path resolved by sync tooling
  per machine)."
- `<HOST>` → `<your-forgejo-host>` + override steps in `docs/CONFIGURATION.md`.
- `<REALNAME>` / `<MACHINE>` → synthetic fixtures / UI hints.

### 7.2 Forgejo PR evidence (D4)

All private-host PR URLs in tracker/docs become:

```md
[Forgejo #N @ <short-sha>](https://github.com/<OWNER>/agentforge/commit/<full-sha>)
```

No private host appears in tracked links.

### 7.3 Tracked `web/` (third-pass P2)

Tracked `web/` on current `main` is only:

- `web/index.html`
- `web/manifest.json`
- `web/favicon.png`
- `web/icons/*`

**Not in scope:** `web/main.dart.js` or anything under `build/web/`
(gitignored build output). S7 sweeps only the tracked paths above for
`<HOST>`/`<OWNER>` and regenerates from example config as needed.
**Release-Web build** remains in workstream DoD (§11) because generated
Dart config affects Web.

## 8. CI and guard (fail-closed canonical gate + concrete D1 allow-list)

### 8.0 When the strict gate turns on (review 250 finding 1 — critical)

| Phase | What runs | Against what |
|---|---|---|
| **S1 (AF-009)** | Ship `tool/check_no_pii.dart` + **unit tests on synthetic fixtures** only. CI job is **report-only / non-blocking** on the real tree (or limited to paths that are already clean). | Fixtures + optional soft report |
| **S3–S6** | Optional soft report on cleaned scopes as they land | Partial tree |
| **S7 (AF-015) after cleanup** | Canonical job becomes **required + fail-closed blocklist mode** on the full tracked tree | Entire tree + §8.2 allow-list |

Enabling fail-closed full-tree scanning in S1 while known host/owner
literals remain is **forbidden** — intermediate PRs must stay green.

### 8.1 Final gate design (post-S7)

- **Canonical pre-merge gate (Forgejo Actions)** runs in **BLOCKLIST mode**
  and **FAILS CLOSED**. `$AGENTFORGE_PII_BLOCKLIST` is materialized from a
  Forgejo secret to a `600`-mode temp file, consumed by
  `tool/check_no_pii.dart`, deleted in `finally`. Never echoed, logged, or
  uploaded.
- Guard checks **all tracked scopes** — `lib/`, `test/`, `tool/`,
  `android/`, `ios/`, `web/`, `docs/`, plus repo-root markdown — covering
  content, paths, and filenames (case-insensitive / path-segment variants).
- **Public/fork secondary gate** (`.github/workflows/ci.yml`): structural
  mode only (no secret) — synthetic example in use; no raw `https://`
  host literals in `lib/`/`test/`/`tool/`. Backstop only; privacy claim is
  the canonical fail-closed gate **after S7**.

### 8.2 Allow-list format (secret file, not committed)

The same non-public blocklist file may contain an `allow:` section. Each
entry is a **path regex + line regex** pair (not line numbers). A hit that
does not match an allow entry is a hard fail.

### 8.3 Concrete D1 / provenance allow-list selectors

These are the **only** intentional owner-string survivals after the
workstream. Implement them as allow entries (illustrative regexes; final
patterns live in the secret file):

| ID | Path selector (regex) | Line selector (regex) | Why |
|---|---|---|---|
| A1 | `^android/app/build\.gradle\.kts$` | `applicationId\s*=\s*"com\.<OWNER>\.agentforge"` | D1 application id |
| A2 | `^android/app/build\.gradle\.kts$` | (optional) comments that only restate A1 | D1 docs in Gradle |
| A3 | `^ios/Runner\.xcodeproj/project\.pbxproj$` | `PRODUCT_BUNDLE_IDENTIFIER\s*=\s*com\.<OWNER>\.agentforge` | D1 bundle id (until fully xcconfig-only; then only Generated.xcconfig) |
| A4 | `^ios/Flutter/AgentForge\.xcconfig(\.example)?$` | `PRODUCT_BUNDLE_IDENTIFIER=com\.<OWNER>\.agentforge` | D1 app id in AgentForge xcconfig (not Flutter Generated) |
| A4b | `^ios/Runner\.xcodeproj/project\.pbxproj$` | `PRODUCT_BUNDLE_IDENTIFIER\s*=\s*com\.<OWNER>\.agentforge\.RunnerTests` | RunnerTests unique id |
| A5 | `^README\.md$` | canonical mirror table cell linking `github\.com/<OWNER>/agentforge` | D4 provenance |
| A6 | `^docs/08-Implementation-Plan-and-Milestones\.md$` | D4-format evidence links only: `github\.com/<OWNER>/agentforge/commit/` | Tracker evidence |
| A7 | `^docs/CONFIGURATION\.md$` | example showing `com\.<OWNER>\.agentforge` as the *kept* id shape | Operator docs |

**Hard rules:**

- Any other match of owner/host/name/path tokens in tracked files → **fail**.
- Changing an allow-listed line’s *content* so the line regex no longer
  matches → **fail** (forces re-review of provenance exceptions).
- The planning doc and all public docs use **masked** tokens only; they
  must not embed the live blocklist patterns.

## 9. Implementation strategy — topological, one row per PR

**Rule:** each branch starts from a **fresh `origin/main` after all its
dependencies have merged**. PR #3 is **AF-016** (planning only). Workstream
= **8 shippable PRs**.

| Step | Ledger | Scope | Depends on | CI gate (per PR) |
|---|---|---|---|---|
| S0 | AF-016 | **Planning only:** approved bug doc + tracker rows. No product code. | — | docs-only; format/analyze/test unchanged |
| S1 | AF-009 | Schema + generator (build + `--release` **unit** validation) + tracked **synthetic defaults** + gitignored real gen path + `check_no_pii` tool + **fixture-only** tests. CI: generator step; guard **report-only** on real tree (not fail-closed). No source cleanup. | AF-016 | analyze/test green on clean clone (defaults); generator unit tests; fixture guard tests; `--release` unit test fails closed on empty signing |
| S2 | AF-010 | Origin-bound credential store + legacy-key deletion migration + upgrade test | AF-009 | new tests green; legacy-key-deletion test passes; coverage floor held |
| S3 | AF-011 | Wire Dart source to `AppConfig` via **const aliases**; remove `<HOST>` literals from `lib/` | AF-010 | deep-link + provider tests green with synthetic defaults; soft report clean on `lib/` |
| S4 | AF-012 | Tests/tool swap to synthetic fixtures; rename demo tool; remove `<REALNAME>`/`<MACHINE>` | AF-011 | coverage floor; soft report clean on `test/`+`tool/` |
| S5 | AF-013 | Android: neutral namespace + source-path move (D2); kept `applicationId` (D1); manifest host placeholder; AVD custom-scheme CUJ | AF-011 | `flutter build apk --debug`; AVD CUJ recorded |
| S6 | AF-014 | iOS: `AgentForge.xcconfig` include chain (§6.2); preserve RunnerTests id; entitlements host; `-showBuildSettings` both targets | AF-011 | both targets’ bundle IDs correct; plists/AASA valid |
| S7 | AF-015 | Docs/handoff redaction + **D4 rewrite of remaining private-host tracker links** + `docs/CONFIGURATION.md` + well-known render + tracked-`web/` sweep; **promote** blocklist job to required fail-closed | AF-010, AF-012, AF-013, AF-014 | fail-closed blocklist green on `main`; release-Web green |

> **Verified-link gates** stay under **AF-002**, not this workstream.

## 10. Tracker updates (truthful — review 250 finding 5)

**This planning PR (AF-016) does:**

- Add ledger rows **AF-016 (planning), AF-009…AF-015** to
  `docs/08-Implementation-Plan-and-Milestones.md`.
- Add changelog entries describing the planning work.

**This planning PR does *not* rewrite pre-existing private-host PR links**
already on `main` inside `docs/08-*` (AF-001/AF-002 evidence, etc.). That
rewrite is **explicitly deferred to S7 / AF-015**. Do not claim it is done
here.

## 11. Acceptance criteria (workstream DoD)

- [ ] Canonical Forgejo Actions gate runs `tool/check_no_pii.dart` in
      **blocklist mode, fail-closed**; secret to `600` temp file; never
      logged/uploaded.
- [ ] No tracked file under the listed scopes contains redacted tokens
      except the **concrete D1/D4 allow-list** in §8.3.
- [ ] Clean clone builds/tests against checked-in synthetic
      `app_config.defaults.dart` with **zero** required pre-steps; release jobs
      fail closed on missing real config; generator is explicit CI step.
- [ ] One schema → all consumers; build vs release validation split
      enforced; properties path = repo-root
      `agentforge-config.properties`.
- [ ] Credentials origin-bound; legacy key deleted; upgrade test proves no
      cross-origin PAT reuse.
- [ ] `flutter analyze --fatal-infos`, `flutter test --coverage` (floor),
      format gate, `flutter build apk --debug`, and
      `flutter build web --release` pass at end state.
- [ ] Rendered well-known JSON/plists clean; iOS settings verified on macOS
      where applicable.
- [ ] `docs/CONFIGURATION.md` documents schema, generator, CI steps,
      overrides, no-secrets rule.
- [ ] Ledger AF-016 + AF-009…AF-015 accurate; D4 evidence only.

## 12. Finding-by-finding response

### Second-pass review (id 246) — carried from rev 3

| # | Finding | Resolution |
|---|---|---|
| 1 | S1 guard can't pass staged sequence | S1 report-only + synthetic fixtures; cleanup in S3/S4 (§9) |
| 2 | No clean-clone bootstrap | Checked-in synthetic gen + **explicit** generator/CI (no pub-hook requirement) (§5.3) |
| 3 | Generator graph / path errors | `const` AppConfig; root `agentforge-config.properties`; native placeholders (§5.3–5.4) |
| 4 | Canonical CI fail-open | Fail-closed blocklist gate + §8.2 allow-list (§8) |
| 5 | Origin/association validation | Build vs release split; port ≠ 443 reject (§5.2) |
| 6 | Identity / credential migration | D1 keeps application id (§1.1, §6) |
| 7 | Ledger/dependency graph | AF-016 + topological 8 PRs (§9) |
| 8 | Audit not reproducible | Opaque counts + operator procedure; **no live patterns in tree** (§2.1) |

### Third-pass review (comment 1622 / reviews 247–248) — rev 4

| # | Finding | Resolution in rev 4 |
|---|---|---|
| P0 | Live blocklist / private host in planning doc | §2.1 rewritten; header uses D4 evidence only; zero live owner/host/name/path strings in this file |
| P1 | D1 vs fail-closed gate | §8.2 concrete path+line allow-list selectors |
| P1 | Pub-hook bootstrap | Removed as correctness dependency; synthetic gen + explicit generator/CI (§5.3) |
| P2 | `web/main.dart.js` | Removed; only real tracked web paths (§7.3) |
| P2 | S1 signing over-claim | S1 gate = `--release` unit test fail-closed, not a full release job (§9) |
| P2 | Properties path drift | Single path: repo-root `agentforge-config.properties` (§5.3) |
| P2 | AF-016 wording | Planning doc + tracker rows only (§9 S0 / §10) |

### Review 250 (pinned at `c49c668`; rev 5)

| # | Finding | Resolution in rev 5 |
|---|---|---|
| 1 | S1 fail-closed full-tree gate impossible while literals remain | **§8.0** stages enforcement: S1 fixture/report-only; **required fail-closed only at S7** after cleanup |
| 2 | Pub-hook / tracked private gen | **§5.3**: tracked synthetic **defaults**; real gen **gitignored**; explicit CLI/CI only; no hooks |
| 3 | iOS xcconfig chain + RunnerTests | **§6.2**: `ios/Flutter/AgentForge.xcconfig` included from Debug/Release after Flutter Generated; never overwrite Flutter Generated; keep unique RunnerTests bundle id |
| 4 | Audit not truly NUL-safe | **§2.1**: tool-based `git ls-files -z` path; withdraw Select-String NUL-safe claim |
| 5 | Tracker claims D4 rewrite already done | **§10**: rewrite deferred to S7/AF-015; this PR only adds planning rows |

## 13. Requested re-review (rev 5)

Please re-review exact PR tip after this revision. Answers:

1. **8-PR graph / AF-016:** Confirmed; planning-only; strict enforcement
   moves to S7 (§8.0).
2. **Legacy-key deletion:** Unchanged — delete + re-prompt.
3. **Fail-closed gate:** Final design unchanged; **activation** only after
   cleanup (S7), not S1.

**Checklist for LGTM (includes review 250)**

- [x] No live blocklist / private-host strings in this planning doc
- [x] S1 does not enable required full-tree fail-closed gate (§8.0)
- [x] Real gen outputs gitignored; tracked synthetic defaults only (§5.3)
- [x] iOS include chain + RunnerTests identity specified (§6.2)
- [x] Audit command honesty / tool path (§2.1)
- [x] Tracker D4 rewrite deferred truthfully to S7 (§10)
- [x] Explicit D1 allow-list selectors (§8.3)

On LGTM: merge AF-016 → fast-forward GitHub mirror → branch AF-009 from
fresh `origin/main`.
