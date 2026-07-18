# Bug: Personal / environment-specific info is hard-coded across the project

**Type:** Privacy / maintainability / security defect

**Status:** OPEN — revision 4 (addresses third-pass review on PR #3)

**Filed:** 2026-07-18 · **Revised:** 2026-07-18 (rev 4)

**Owner:** repository owner (username omitted from this tracked doc)

**Evidence (D4 — no private host):** [Forgejo #3 @ c49c668](https://github.com/avidullu/agentforge/commit/c49c668ef51880f314f4c4ac141b1c2b0ebfb327)
(when the PR branch is mirrored; after merge, update to the merge commit SHA on the public GitHub mirror). Planning row: **AF-016**.

---

> **Revision 4 note.** Third-pass review (conversation comment + reviews 247/248)
> at head `c49c668` requested changes. Blocking items: (1) §2.1 re-published
> the real blocklist into the tracked tree; (2) D1 allow-list selectors were
> not concrete enough for a fail-closed gate; (3) clean-clone bootstrap
> depended on non-portable pub hooks. Rev 4 fixes those and the P2 accuracy
> notes (web file list, S1 signing gate, properties path, AF-016 wording).
> Owner-locked decisions D1–D4 are unchanged.

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

**Rule (third-pass P0):** this tracked document must never contain the
owner-specific blocklist strings themselves. The blocklist lives only in
the non-public secret file `$AGENTFORGE_PII_BLOCKLIST` (CI) / the operator
runbook outside git.

**How to re-run the audit (operators):**

1. Materialize the private blocklist file (newline-separated patterns) from
   the Forgejo secret or local password manager — **never commit it**.
2. From a clean checkout of the pin below, scan **tracked** files only with
   a NUL-safe tool (`git ls-files -z` + `rg --null-data` / PowerShell
   `Select-String` over `git ls-files` output).
3. Record **counts only** in public docs / PR text.

```text
# Pseudocode — patterns come from $AGENTFORGE_PII_BLOCKLIST, not this file.
# git ls-files -z | scan-with-blocklist-file | count-unique-paths
```

**Verified result on `origin/main` @ `37732b4`:** **24 tracked files** match
the private blocklist. (At planning head `c49c668` the count is higher only
while intermediate planning text still lands; rev 4 is required to keep
**zero** live blocklist strings in this file.)

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

### 5.3 Generator + bootstrap (third-pass P1 — no pub-hook dependency)

`tool/generate_config.dart` is the single entry point. It reads the schema,
runs the §5.2 build validation, and emits:

- `lib/core/config/generated/app_config.gen.dart` — **`const`** Dart config
  (§5.4).
- **`agentforge-config.properties` at the repository root** (not under
  `android/app/`). Loaded in `android/app/build.gradle.kts` via
  `rootProject.file("agentforge-config.properties")`.
- `ios/Runner/Generated.xcconfig`, consumed at the **project level** so it
  overrides target-level bundle ids; per-target `PRODUCT_BUNDLE_IDENTIFIER`
  overrides in `project.pbxproj` are removed so the xcconfig wins.
- Native scheme output: Android manifest and both iOS plists register the
  scheme via a generated placeholder, not a hard-coded literal.

**Bootstrap (portable — third-pass P1):**

1. **Checked-in synthetic default** `lib/core/config/generated/app_config.gen.dart`
   is committed (generated from `config/agentforge.config.example.json`).
   A clean clone **builds and tests with zero pre-steps**.
2. **Explicit regeneration** (documented in `docs/CONFIGURATION.md` and
   invoked in CI before any job that must reflect a non-example config):

   ```bash
   dart run tool/generate_config.dart
   # release render only when deploying association files:
   dart run tool/generate_config.dart --release
   ```

3. **CI:** the canonical Forgejo workflow runs the generator as a named step
   before analyze/test/build when a real config is present; release jobs set
   `AGENTFORGE_CONFIG` to the secret-backed config and **fail closed** if it
   is missing (never ship an example-config release artifact).
4. **Optional DX only:** a local shell helper `tool/bootstrap.sh` may wrap
   `cp example → config` + `generate_config.dart`. **Pub hooks are not
   required** and are not part of the correctness contract.

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

### 6.2 iOS

- `PRODUCT_BUNDLE_IDENTIFIER` stays `com.<OWNER>.agentforge` (D1); remove
  per-target overrides so `Generated.xcconfig` is the single source.
- Associated Domains host generated from `forgejo.origin`.
- **Verification:** `xcodebuild -showBuildSettings`; rendered plists/AASA
  parse with no unresolved placeholders; macOS-only no-sign checks skipped
  on non-mac CI with a recorded reason.

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
  the canonical gate.

### 8.1 Allow-list format (secret file, not committed)

The same non-public blocklist file may contain an `allow:` section. Each
entry is a **path regex + line regex** pair (not line numbers). A hit that
does not match an allow entry is a hard fail.

### 8.2 Concrete D1 / provenance allow-list selectors (third-pass P1)

These are the **only** intentional owner-string survivals after the
workstream. Implement them as allow entries (illustrative regexes; final
patterns live in the secret file):

| ID | Path selector (regex) | Line selector (regex) | Why |
|---|---|---|---|
| A1 | `^android/app/build\.gradle\.kts$` | `applicationId\s*=\s*"com\.<OWNER>\.agentforge"` | D1 application id |
| A2 | `^android/app/build\.gradle\.kts$` | (optional) comments that only restate A1 | D1 docs in Gradle |
| A3 | `^ios/Runner\.xcodeproj/project\.pbxproj$` | `PRODUCT_BUNDLE_IDENTIFIER\s*=\s*com\.<OWNER>\.agentforge` | D1 bundle id (until fully xcconfig-only; then only Generated.xcconfig) |
| A4 | `^ios/Runner/Generated\.xcconfig$` | `PRODUCT_BUNDLE_IDENTIFIER=com\.<OWNER>\.agentforge` | D1 after S6 |
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
| S1 | AF-009 | Schema + generator (build + release **render** validation unit tests) + checked-in synthetic `app_config.gen.dart` + structural `check_no_pii` scaffold + CI wiring for fail-closed blocklist gate. **Report-only** guard against synthetic fixtures — no source/test cleanup yet. | AF-016 | analyze clean; generator produces synthetic output; structural guard green on synthetic fixture; `generate_config.dart --release` unit test fails closed on empty signing |
| S2 | AF-010 | Origin-bound credential store + legacy-key deletion migration + upgrade test | AF-009 | new tests green; legacy-key-deletion test passes; coverage floor held |
| S3 | AF-011 | Wire Dart source to `AppConfig` via **const aliases**; remove `<HOST>` literals from `lib/` | AF-010 | deep-link + provider tests green with synthetic config; blocklist green on `lib/` |
| S4 | AF-012 | Tests/tool swap to synthetic fixtures; rename demo tool; remove `<REALNAME>`/`<MACHINE>` | AF-011 | `flutter test --coverage` holds floor; blocklist green on `test/`+`tool/` |
| S5 | AF-013 | Android: neutral namespace + source-path move (D2); kept `applicationId` (D1); manifest host placeholder; AVD custom-scheme CUJ (verified links → AF-002) | AF-011 | `flutter build apk --debug`; AVD install+launch+custom-scheme (manual, recorded) |
| S6 | AF-014 | iOS: remove per-target bundle-id overrides; entitlement host from config; `-showBuildSettings`; rendered plist/AASA validation | AF-011 | settings resolve; plists/AASA valid |
| S7 | AF-015 | Docs/handoff redaction + D4 link rewrite + `docs/CONFIGURATION.md` + well-known templates/render + tracked-`web/` sweep (§7.3 list only) | AF-010, AF-012, AF-013, AF-014 | blocklist green on `main`; release-Web build green; docs render |

> **Verified-link gates** stay under **AF-002**, not this workstream.

## 10. Tracker updates

- Ledger rows **AF-016 (planning), AF-009…AF-015** in
  `docs/08-Implementation-Plan-and-Milestones.md`.
- Changelog entry for rev 4.

## 11. Acceptance criteria (workstream DoD)

- [ ] Canonical Forgejo Actions gate runs `tool/check_no_pii.dart` in
      **blocklist mode, fail-closed**; secret to `600` temp file; never
      logged/uploaded.
- [ ] No tracked file under the listed scopes contains redacted tokens
      except the **concrete D1/D4 allow-list** in §8.2.
- [ ] Clean clone builds/tests against checked-in synthetic
      `app_config.gen.dart` with **zero** required pre-steps; release jobs
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

## 13. Requested fourth-pass review

Re-requesting review on PR #3 after rev 4. Open questions from third-pass
are answered as follows:

1. **8-PR graph / AF-016:** Confirmed; AF-016 is planning-only.
2. **Legacy-key deletion:** Unchanged LGTM position — delete + re-prompt.
3. **Fail-closed gate:** Implementable via §8 + §8.2 without re-publishing
   the blocklist in-tree.

**Checklist for LGTM**

- [x] Zero real owner/host/name/path strings in this planning doc
- [x] D4-format evidence links only
- [x] Explicit D1 allow-list selectors in §8.2
- [x] Bootstrap without non-portable pub hooks
- [x] §7.3 web list; S1 signing gate; properties path wording

On LGTM: merge AF-016 → fast-forward GitHub mirror → branch AF-009 from
fresh `origin/main` → implement → full verify → ready-for-review follow-up.
