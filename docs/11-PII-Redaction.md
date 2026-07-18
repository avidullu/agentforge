# Bug: Personal / environment-specific info is hard-coded across the project

**Type:** Privacy / maintainability / security defect

**Status:** OPEN — revision 2 (addressing PR #3 review, request-changes)

**Filed:** 2026-07-18 · **Revised:** 2026-07-18

**Owner:** `avidullu`

**PR:** [Forgejo #3](https://avis-pbook.tail651ec3.ts.net/avidullu/agentforge/pulls/3)

---

> **Revision 2 note.** Revision 1 proposed four independent configuration
> channels and a regex guard that would have had to exempt itself. The PR #3
> review (commit-pinned at head `3370b42`) correctly blocked on six points.
> This revision replaces the architecture with **one versioned config schema
> + generator + validator**, makes the credential store **origin-bound**, and
> narrows the goal to **current-tree/default sanitization** with the
> identifier evidence masked. The review's decisions are accepted verbatim
> (§10). Each original finding is mapped to a fix in §11.

## 1. Summary

The repository hard-codes owner-specific and machine-specific identifiers in
source, build config, tests, and docs. This:

1. **Leaks personal/infra info** to the public GitHub mirror — Tailscale host,
   owner username, real name, and a Windows local path.
2. **Makes the project non-portable** — a fork needs dozens of edits to run.
3. **Contradicts the stated privacy goal** (`README.md`: "private tailnet
   operation").
4. **Is a credential-reuse hazard** — there is no binding between a persisted
   PAT and the Forgejo origin it belongs to (see §3, finding C).

## 2. Evidence (masked, reproducible)

> Identifiers are masked here as `<HOST>`, `<OWNER>`, `<APPID>`, `<USERPATH>`,
> `<REALNAME>`, `<MACHINE>`. The unmasked strings live in the tree today; the
> point of this bug is to remove them. A reviewer with checkout access can
> reproduce the full list with the command in §2.2.

### 2.1 Categories

| Category | Masked token | Where (representative) |
|---|---|---|
| Local Windows path | `<USERPATH>` | `HANDOFF.md`, `SESSION_HANDOFF.md` |
| Tailscale host | `<HOST>` (`<HOST>.tail<TAILNET>.ts.net`) | `lib/core/deep_links/deep_link.dart`, `lib/core/settings/app_settings.dart`, `test/deep_link_test.dart`, `test/forgejo_*_test.dart`, `android/.../AndroidManifest.xml`, `ios/Runner/Runner.entitlements`, `docs/well-known/*`, `tool/demo_avis_pbook.dart`, several `docs/*.md`, `README.md`, UI strings |
| Application identity | `<APPID>` (`com.<OWNER>.agentforge`) | `android/app/build.gradle.kts`, `android/.../kotlin/com/<OWNER>/agentforge/MainActivity.kt`, `ios/Runner.xcodeproj/project.pbxproj`, `ios/Runner/Info*.plist`, `docs/well-known/assetlinks.json`, `docs/well-known/apple-app-site-association` |
| Owner identity | `<OWNER>` (Forgejo/GitHub owner + display name) | `README.md`, `docs/08-*`, `docs/AGENT_MCP_CONTRACT.md`, `test/forgejo_models_test.dart`, UI hints |
| Machine hint | `<MACHINE>` (e.g. `avis-msi`) | `lib/features/agents/agents_screen.dart` hint text |

### 2.2 Reproducible audit command and count

The §1 audit count must be reproducible from a clean checkout, counting only
**tracked** files (not generated output, not untracked local artifacts).

```bash
# Count tracked files matching the masked patterns (run from repo root).
git ls-files | xargs grep -lE '<HOST_RE>|<APPID_RE>|<OWNER_RE>|<USERPATH_RE>|<REALNAME_RE>' 2>/dev/null | wc -l
```

(The actual regexes are owner-specific and shipped outside the public tree —
see §5.4. The current count on `main` is **27 tracked files** after excluding
generated `build/` output and the untracked `App building assistance/`
directory. Note: `web/` is **tracked source** in this repo, not generated
output — generated web artifacts live under `build/web/`, which is
gitignored.)

The owner-specific regex list, the allow-list, and the masked key are
maintained in a **non-public file** consumed by the guard (§5.4). They are
never committed to the public tree, which resolves the rev-1
self-exemption contradiction (review finding 1).

## 3. Impact (incl. credential-reuse hazard — review finding 3)

- **Privacy / portability / maintainability** — as §1.
- **Credential reuse (new).** Today `SettingsRepository` stores one global
  PAT under key `forgejo_token` (`lib/core/settings/settings_repository.dart`),
  and `ForgejoClient` sends it to whatever `baseUrl` is configured
  (`lib/core/forgejo/forgejo_client.dart`). If a future build accepts a
  different origin (the whole point of this work), an upgraded install could
  silently send the old PAT to a new host. This must be addressed **as part
  of** the redaction work, not after.

## 4. Goals / non-goals (reworded — review finding 1)

**Goals**

- Remove all owner/machine identifiers from **tracked** source, native
  config, tests, and docs, with a reproducible audit.
- Provide **one versioned, validated** config schema that derives every
  consumer (Dart, Android manifest placeholders, Xcode settings/entitlements,
  well-known JSON) so they cannot drift.
- Bind persisted credentials to the exact normalized origin; migrate or
  clear on mismatch.
- Prevent regression with a guard that consumes an owner-specific blocklist
  kept **outside the public tree**.
- **Goal wording (corrected).** "Current-tree/default-sanitization": the
  checked-in tree contains no owner identifiers by default, and the public
  mirror does not either. Git **history** and **author/committer metadata**
  are explicitly **out of scope** unless AF-010-history is approved (§10).

**Non-goals**

- Changing the owner's actual username/Tailscale host.
- Editing `build/`, `build/web/`, or `unit_test_assets/` (gitignored,
  regenerated). `web/` tracked source **is** in scope.
- Re-licensing or changing distribution model (that is `AF-008`).
- Rewriting git history (destructive; deferred to a separately-approved
  history-rewrite item).
- Putting tokens or secrets into `--dart-define` (dart-defines are embedded
  configuration, not a secret store).

## 5. Proposed architecture (one schema, derived everywhere)

Replaces the rev-1 "four independent channels" model (review finding 2).

### 5.1 One versioned schema: `agentforge.config.json`

A single JSON document is the **only** place environment values are
authored. Versioned (`schemaVersion`), validated by a Dart script, and the
basis for every derived artifact.

```jsonc
// config/agentforge.config.schema.json (shape; the real file is a JSON Schema)
{
  "schemaVersion": 1,
  "forgejo": {
    "origin": "https://<HOST>",           // normalized; host derived from this
    "canonicalOwnerRepo": "<OWNER>/agentforge"  // provenance, allow-listed
  },
  "app": {
    "releaseApplicationId": "dev.agentforge.app",  // stable, neutral
    "debugApplicationIdSuffix": ".debug",           // local variants only
    "urlScheme": "agentforge"
  },
  "signing": {
    "androidSha256Fingerprints": [],     // injected into assetlinks at render
    "appleTeamId": ""                    // injected into AASA at render
  }
}
```

- The **trusted host is derived** from `forgejo.origin` (normalized HTTPS,
  no path/userinfo/query, port 443) by the generator. Dart, the Android
  manifest placeholder, the iOS entitlement, and the well-known JSON all
  consume that **single derived value** — there is no independent
  `trustedHost` field to drift (review finding 2).
- Real values live in `config/agentforge.config.json`, which is
  **gitignored**. A checked-in `config/agentforge.config.example.json`
  uses synthetic values (`https://forge.example.test`,
  `example/agentforge`, `dev.agentforge.app`) so the public tree is clean
  and a fresh clone builds immediately against the example.

### 5.2 Generator + validator: `tool/generate_config.dart`

`dart run tool/generate_config.dart` reads the schema and:

1. **Validates** origin is HTTPS, normalized, no path/userinfo/query; warns
   if port ≠ 443; rejects empty/malformed values (review finding 5:
   missing/malformed coverage).
2. **Detects mismatch** between schema origin and any hard-coded residual in
   source (cross-check, not independent input).
3. **Emits** derived artifacts into a build-time location:
   - `lib/core/config/generated/app_config.gen.dart` — typed Dart config
     (see §5.3).
   - `android/app/src/main/AndroidManifest.xml` placeholders
     (`${forgejoHost}`) via Gradle `manifestPlaceholders` read from a
     generated `android/agentforge-config.properties`.
   - `ios/Runner/Generated.xcconfig` consumed by the Xcode project for
     bundle id and the entitlement host.
   - `docs/well-known/assetlinks.rendered.json` and
     `apple-app-site-association.rendered` from templates, with signing
     fingerprints/team id injected.
4. **Verifies rendered output**: JSON parses, plists parse, and **no
   unresolved `${...}` placeholders** remain (review finding 6).

The generator is idempotent and is the single entry point; there is no path
for a developer to edit Dart host, Gradle host, and Xcode host
independently.

### 5.3 Dart design (concrete — review finding 5)

Rev-1 referenced an undefined `_$AppConfigInstance` and called a
compile-time wrapper a runtime fallback. This revision specifies the design
explicitly:

- **Build-time values** (origin host, app scheme, default owner/repo) come
  from the generated `app_config.gen.dart` as a plain `const` class — not
  from `String.fromEnvironment` scattering. The generated file is the
  single Dart source of truth and is gitignored (it regenerates from the
  schema).
- **Runtime user values** (the user's own base URL + PAT) are **not**
  compile-time; they flow through the existing injectable
  `SettingsRepository` / provider tree, extended to be origin-bound (§5.5).
- **Failure modes covered by tests**: missing config file, malformed JSON,
  non-HTTPS origin, origin with path/userinfo, port mismatch, and
  schema-version mismatch each produce a typed, user-readable error and
  never fall back to a hard-coded owner value.
- **Explicit non-secret guarantee.** A unit test asserts the generated
  config and dart-defines contain no `token`/`secret`/`password` keys, and
  the JSON Schema forbids those property names. dart-defines are documented
  as embedded configuration only.

`AppSettings.defaultBaseUrl` / `trustedHost` become getters that read the
generated config; `deep_link.dart`'s `kForgejoHost` becomes
`AppConfig.trustedHost`. All existing call sites in §"ground-truth grep"
keep working through these aliases.

### 5.4 Regression guard: `tool/check_no_pii.dart` (blocklist outside tree — review finding 1)

- Consumes an **owner-specific blocklist** from
  `$AGENTFORGE_PII_BLOCKLIST` (a machine-local path, e.g.
  `~/.config/agentforge/pii-blocklist.txt`) — **never** committed. On CI it
  is provided as a secret/variable. If absent, the guard runs in
  **structural mode** only.
- **Structural mode (runs in public CI, no secrets):** synthetic detector
  tests — `test/config/no_hardcoded_pii_test.dart` — assert that
  `lib/core/config/generated/*.gen.dart` is gitignored, that no `lib/` /
  `test/` / `tool/` file contains `https://` host literals matching the
  deep-link host placeholder pattern, and that the example config uses the
  synthetic `forge.example.test`. This catches regressions **without** the
  real identifiers ever being in the repo.
- **Allow-list (narrow, reviewed):** the canonical
  `<OWNER>/agentforge` repository reference in `README.md`'s "Repository"
  table and the tracker's real PR evidence links are **provenance, not
  runtime endpoints**, and are explicitly allow-listed (review decision 1).
  The allow-list entries are structural (e.g. "the line in README.md's
  Repository table"), not identifier strings.
- Adding a pattern = one line in the machine-local blocklist. This is the
  "extensible" anchor.

### 5.5 Origin-bound credential store (review finding 3)

`SettingsRepository` is extended so a credential is bound to the exact
normalized origin it was entered for:

- Storage keys become origin-scoped: `forgejo_token::<normalizedOrigin>`.
- `load(currentOrigin)` returns the PAT only if it was stored for that
  origin; otherwise returns empty and surfaces a "credential entered for a
  different instance" state.
- On origin change in settings UI: if a PAT exists for the old origin, do
  **not** carry it over; prompt re-entry. `clearToken(origin)` is scoped.
- **Upgrade test:** a test seeds the legacy unscoped `forgejo_token` key
  (the pre-AF-009 format), runs a migration, and asserts the token is
  **not** reused against a different configured origin — it is either
  migrated under the original origin key or cleared. This is the proof that
  an old token can never reach a new host.

## 6. Native specifics (corrected — review findings 2 & 4)

### 6.1 Android (no launch-breaking namespace split)

Rev-1 proposed per-developer `namespace` with a fixed source package — this
breaks because `AndroidManifest.xml` uses `.MainActivity`
(`android/app/src/main/AndroidManifest.xml:10-12`), which resolves relative
to `namespace`. Corrected design:

- **Fixed neutral namespace = fixed source package** =
  `dev.agentforge.app`. The Kotlin directory is renamed to
  `android/app/src/main/kotlin/dev/agentforge/app/` and `MainActivity.kt`
  gets `package dev.agentforge.app`. Namespace and source package match, so
  `.MainActivity` resolves.
- **Stable canonical release `applicationId`** = `dev.agentforge.app`
  (review decision 3: stable identity, chosen deliberately).
- **Local variants use debug flavors/suffixes**, not a different namespace:
  `debug { applicationIdSuffix ".debug" }` so a second developer's install
  coexists without touching namespace or source package.
- **`local.properties` correction (review finding 4).** Rev-1 claimed
  `project.property(...)` reads `android/local.properties`; it does not —
  Gradle reads `gradle.properties` (project + `~/.gradle/`). The generator
  emits `android/agentforge-config.properties`, loaded explicitly via
  `Properties().load(file("agentforge-config.properties").inputStream())`
  in `build.gradle.kts`, and feeds `manifestPlaceholders[forgejoHost]`.
  Release signing remains `AF-002`'s scope.
- **Verification bar (review finding 6):** not just APK compile —
  `flutter build apk --debug`, install on an AVD, launch, and verify the
  deep link routes (custom scheme + app-link host) on the **installed**
  build. CI repeats at least the build; the device CUJ is a manual gate
  recorded in the tracker row.

### 6.2 iOS

- `PRODUCT_BUNDLE_IDENTIFIER` and the Associated Domains host come from
  `ios/Runner/Generated.xcconfig` (gitignored; example template checked in
  as `ios/Runner/Generated.xcconfig.example`). The `.entitlements` host is
  also generated.
- **Verification (review finding 6):** `xcodebuild -showBuildSettings`
  (corrected from `-showConfig`) confirms the override resolves; rendered
  plist + AASA parse and contain no unresolved placeholders; **iOS no-sign
  verification runs on macOS only** and is explicitly skipped on non-mac
  CI with a recorded reason.

## 7. Docs & handoffs (review decision 1)

- Replace `<USERPATH>` absolute paths in `HANDOFF.md` / `SESSION_HANDOFF.md`
  with the portable "shared project-memory store (path resolved by the
  `claude-sync` tooling per machine)" wording.
- Replace `<HOST>` in user-facing docs with `<your-forgejo-host>` plus the
  override step; document in a new `docs/CONFIGURATION.md`.
- **Keep** the canonical `<OWNER>/agentforge` reference and real PR links
  in the tracker / README repository table — they are **public provenance**,
  allow-listed (decision 1). Do not blanket-redact tracker evidence.

## 8. Implementation strategy (one ledger row per PR — review finding 6)

Each row is an independently reviewable PR **with a tracker ledger entry
and explicit dependency** (rev-1 said both "off origin/main" and "stack on
S1" — corrected: rows are sequential, each branches from the previous
merge to `main`).

| Step | Ledger | Scope | Depends on | Verify |
|---|---|---|---|---|
| S1 | AF-009 | Schema + generator + validator + structural guard scaffold; example config; gitignore entries | — | `flutter analyze` clean; generator produces synthetic example output; `tool/check_no_pii.dart` runs in structural mode; rendered-output validation passes |
| S2 | AF-010 | Origin-bound credential store + migration + upgrade test | AF-009 | new tests green; legacy-token migration test proves no cross-origin reuse; coverage ≥ 29% |
| S3 | AF-011 | Wire Dart source to generated config (`deep_link.dart`, `app_settings.dart`, UI strings, providers) | AF-009 | deep-link + provider tests pass with synthetic config; no host literal in `lib/` |
| S4 | AF-012 | Tests swap to synthetic fixtures; rename `tool/demo_avis_pbook.dart` → `tool/demo_forgejo.dart` | AF-011 | `flutter test --coverage` ≥ 29%; no real identifiers in `test/`/`tool/` |
| S5 | AF-013 | Android: fixed neutral namespace + stable release id + debug suffix; manifest placeholder; device CUJ | AF-009 | APK build + AVD install + launch + deep-link route on installed build |
| S6 | AF-014 | iOS: `Generated.xcconfig` + entitlement host; `-showBuildSettings`; rendered plist/AASA validation; macOS no-sign verify | AF-009 | settings resolve; plists/AASA valid; no unresolved placeholders |
| S7 | AF-015 | Docs/handoff redaction + `docs/CONFIGURATION.md` + well-known templates + render script; CI wires guard | AF-003, AF-011, AF-013, AF-014 | guard passes on `main`; docs render; CI green |

> **Note on AF numbering.** The rev-1 single `AF-009` is now a **workstream**
> spanning AF-009…AF-015, because review finding 6 requires one ledger row
> per shippable PR. The umbrella bug remains this doc; the ledger rows are
> added to `docs/08-*` by this revision (§9).

## 9. Tracker updates (added in this revision)

Adds seven ledger rows to `docs/08-Implementation-Plan-and-Milestones.md`
(status PLANNED, dependencies per §8) and this changelog entry. The
separate, destructive **git-history rewrite** is **not** opened — it is
deferred per review decision 4 until data is classified and migration
impact is approved.

## 10. Review decisions (accepted verbatim from PR #3)

1. **Canonical repo reference:** keep, narrowly allow-list. Do not
   blanket-redact tracker PR evidence. *(accepted)*
2. **Android package rename:** reasonable only with a fixed matching
   namespace and a deliberately chosen stable application id. *(accepted —
   §6.1)*
3. **History rewrite:** defer until data classification + Forgejo/GitHub
   migration impact approved. *(accepted — not opened)*
4. **Four-layer idea:** approve only after backed by one
   schema/generator/validator + origin-bound credential migration.
   *(accepted — §5 replaces the four-layer model)*

## 11. Finding-by-finding response

| # | Finding | Resolution |
|---|---|---|
| 1 | Guard republishes identifiers then exempts itself | §2 masks evidence; §5.4 blocklist lives outside public tree; structural detector tests in public CI; goal reworded to current-tree/default sanitization (§4); history explicitly out of scope (§4, decision 3) |
| 2 | Four config channels drift | §5.1 one schema; §5.2 generator derives every consumer; trusted host **derived** from one normalized HTTPS origin; signing fingerprints in schema (§5.1); cross-check in CI |
| 3 | PAT can be sent to a different origin | §5.5 origin-bound credential store + scoped keys + migration + upgrade test proving no cross-origin reuse |
| 4 | Android namespace/launch break + `local.properties` myth | §6.1 fixed namespace = source package; stable release id; debug suffix for variants; explicit `Properties().load(...)` not `project.property`; verify install+launch+deeplink, not just compile |
| 5 | Dart config not implementable | §5.3 generated `const` class (not `String.fromEnvironment` scatter); runtime values via injectable providers; missing/malformed/mismatch covered by tests; explicit no-secrets guarantee + test |
| 6 | Tracker/branching/audit/verification errors | §8 one ledger row per PR with explicit dependencies (sequential off `main`); §2.2 reproducible tracked-file command/count + `web/` clarification; §6.2 `-showBuildSettings`; rendered JSON/plist validation + unresolved-placeholder checks + macOS iOS no-sign + installed Android link tests; §9 adds the rows |

## 12. Acceptance criteria (Definition of Done for the AF-009 workstream)

- [ ] `tool/check_no_pii.dart` runs in structural mode in public CI and
      passes on `main`; blocklist mode runs locally/with secret.
- [ ] No **tracked** file under `lib/`, `test/`, `tool/`, `android/`,
      `ios/`, `web/`, or `docs/` contains the owner identifiers, except the
      narrow, reviewed provenance allow-list (decision 1).
- [ ] A clean clone builds and runs against
      `config/agentforge.config.example.json` with no code edits.
- [ ] One schema → all consumers; generator cross-checks and rejects drift.
- [ ] Credentials are origin-bound; upgrade test proves an old PAT cannot
      reach a new host.
- [ ] `flutter analyze --fatal-infos`, `flutter test --coverage` (≥ 29%),
      `dart format --set-exit-if-changed`, and `flutter build apk --debug`
      pass; installed-AVD launch + deep-link CUJ recorded.
- [ ] Rendered well-known JSON/plists parse and contain no unresolved
      placeholders; iOS settings verified via `-showBuildSettings` (macOS
      no-sign on mac only).
- [ ] `docs/CONFIGURATION.md` documents the schema, generator, overrides,
      and the no-secrets rule.
- [ ] Ledger rows AF-009…AF-015 present with accurate status and PR links;
      changelog updated.

## 13. Requested re-review

Re-requesting review on PR #3 after this revision. Remaining open question
for the reviewer:

- Confirm the **AF-009…AF-015** split (one row per PR) and the sequential
  dependency graph in §8 match your expectation, so S1 can begin on LGTM.
