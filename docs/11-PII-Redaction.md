# Bug: Personal / environment-specific info is hard-coded across the project

**Type:** Privacy / maintainability defect

**Status:** OPEN — awaiting review (LGTM) before implementation

**Filed:** 2026-07-18

**Owner:** `avidullu`

**Tracker row:** `AF-009` (to be added to
[`docs/08-Implementation-Plan-and-Milestones.md`](08-Implementation-Plan-and-Milestones.md)
on implementation)

---

## 1. Summary

The repository hard-codes owner-specific and machine-specific identifiers
throughout source, build configuration, tests, docs, and handoffs. This:

1. **Leaks personal / infra information** into a public mirror
   (`github.com/avidullu/agentforge`) — Tailscale host name, GitHub/Forgejo
   username, real name, and a Windows local path.
2. **Makes the project non-portable** — anyone forking/cloning cannot run it
   without editing dozens of files, and merges between the owner's machines
   churn on environment lines.
3. **Defeats the stated privacy goal** — `README.md` declares "private tailnet
   operation" as a runtime goal, yet the host name and owner identity are
   baked into every layer.

## 2. Evidence (full audit)

A workspace-wide search for `avidu`, `avidullu`, `avis-pbook`,
`tail651ec3`, `Avi Dullu`, and `avis-msi` returned hits in **29 files**. They
group into five categories:

### 2.1 Local filesystem paths (Windows user dir)

| File | Line | Example |
|---|---|---|
| `HANDOFF.md` | 9 | `C:\Users\avidu\OneDrive\Documents\claude-sync\memory\Agentforge\session-handoff.md` |
| `SESSION_HANDOFF.md` | 7 | same path |

### 2.2 Forgejo host / Tailscale tailnet name

`avis-pbook.tail651ec3.ts.net` appears in **17 files**, including:

- Source: `lib/core/deep_links/deep_link.dart`, `lib/core/settings/app_settings.dart`
- Tests: `test/deep_link_test.dart`, `test/forgejo_client_test.dart`, `test/forgejo_models_test.dart`
- Docs: `docs/08-*`, `docs/DEEP_LINKING.md`, `docs/AGENT_MCP_CONTRACT.md`, `README.md`
- Build/native: `android/app/src/main/AndroidManifest.xml`,
  `ios/Runner/Runner.entitlements`, `docs/well-known/*`, `tool/demo_avis_pbook.dart`
- UI strings: `lib/features/agents/agents_screen.dart`, `lib/features/home/home_screen.dart`
- Design handoff mockups (HTML/JSX) under `App building assistance/`

### 2.3 Application / bundle identifier

`com.avidullu.agentforge` is the Android `applicationId`, iOS bundle id,
Android namespace, and the deep-link package identity in
`assetlinks.json` / `apple-app-site-association`:

- `android/app/build.gradle.kts`, `android/app/src/main/kotlin/com/avidullu/agentforge/MainActivity.kt`
- `ios/Runner.xcodeproj/project.pbxproj`, `ios/Runner/Info.plist`,
  `ios/Runner/Info-Debug.plist`
- `docs/well-known/assetlinks.json`, `docs/well-known/apple-app-site-association`

### 2.4 Owner identity (username / display name)

`avidullu` is referenced as the Forgejo/GitHub owner in README, docs,
`AGENT_MCP_CONTRACT.md`, and several test fixtures. The display name
`Avi Dullu` and the machine hint `avis-msi` appear in test/UI strings.

### 2.5 Generated / vendored artifacts

`build/`, `unit_test_assets/`, and `web/` (release output) contain derived
copies of the above. These are gitignored and **out of scope** for in-repo
edits — they regenerate from source. The handoff HTML/JSX mockups under
`App building assistance/` are vendored design artifacts; redaction there is
cosmetic and lower priority.

## 3. Impact

- **Privacy:** Tailscale magic-DNS host + tailnet name + owner real name are
  published to the public GitHub mirror. While the Forgejo instance is
  tailnet-only, the host name is a stable identifier the owner may not want
  public.
- **Portability:** No second contributor can build/run without sweeping edits.
- **Maintainability:** Every environment change (new host, new machine) forces
  a wide diff; merges between owner machines conflict on these lines.
- **Compliance with own tracker:** `AF-008` ("public-code/private-runtime
  licensing and data-boundary decision") cannot be closed cleanly while
  personal identifiers are hard-coded.

## 4. Goals / non-goals

**Goals**

- Remove all owner-specific and machine-specific identifiers from
  version-controlled source, config, tests, and docs.
- Introduce a **single, extensible mechanism** so environment values live in
  one place and can be overridden per-developer without touching tracked files.
- Keep the public mirror free of the owner's Tailscale host name, real name,
  and Windows user path.

**Non-goals**

- Changing the *owner's actual* Forgejo/GitHub username or Tailscale host.
- Redacting `build/`, `web/`, `unit_test_assets/` outputs (regenerated).
- Re-licensing or changing distribution model (that is `AF-008`).
- Touching git history (rewriting past commits is destructive and out of
  scope; the mirror's history already contains the identifiers and is
  addressed separately under "History considerations" if the owner requests).

## 5. Proposed plan (design)

Use a **layered configuration mechanism** with a single source of truth and
per-environment overrides:

### 5.1 Layer 1 — Dart compile-time / runtime config (source & tests)

Introduce `lib/core/config/app_config.dart` exporting typed constants:

```dart
/// Environment-driven app configuration.
///
/// Values come from `--dart-define` (CI/release) or `config/local.json`
/// (development fallback). Nothing owner-specific is hard-coded in source.
class AppConfig {
  const AppConfig({
    required this.defaultForgejoBaseUrl,
    required this.trustedForgejoHost,
    required this.appScheme,
  });

  final String defaultForgejoBaseUrl;
  final String trustedForgejoHost;
  final String appScheme;

  static const AppConfig instance = _$AppConfigInstance;
}
```

- Build-time values are injected via `--dart-define=KF_FORGEJO_BASE_URL=...`,
  `--dart-define=KF_FORGEJO_HOST=...`. A `tool/config.dart` generator reads
  `config/local.json` (gitignored) and emits the define flags for local runs.
- `lib/core/deep_links/deep_link.dart` and `lib/core/settings/app_settings.dart`
  consume `AppConfig` instead of string literals.
- Tests read from a public `test/fixtures/config.dart` with synthetic values
  (e.g. `forge.example.test`, `demo-user`) — no real identifiers.

### 5.2 Layer 2 — Native build config (Android / iOS)

- **Android:** move `applicationId` / `namespace` to
  `android/gradle.properties` as
  `AGENTFORGE_APPLICATION_ID` / `AGENTFORGE_NAMESPACE`, read into
  `build.gradle.kts` via `project.property(...)`. Developers set their own
  `~/.gradle/gradle.properties` (or a gitignored `android/local.properties`
  override). The Kotlin package directory is renamed to a neutral
  `dev.agentforge.app` path; the literal `com.avidullu.agentforge` survives
  only as the configured `applicationId`, never as a directory name.
- **iOS:** parameterize `PRODUCT_BUNDLE_IDENTIFIER` through a `Config.xcconfig`
  file that is gitignored by default, with a checked-in
  `Config.example.xcconfig` template. Same for the Associated Domains entry in
  `Runner.entitlements`.
- **Deep-link well-known files** (`docs/well-known/assetlinks.json`,
  `apple-app-site-association`) become **templates** (`*.template`) with
  `${APPLICATION_ID}`, `${TEAM_ID}`, `${FORGEJO_HOST}` placeholders; a
  `tool/render_well_known.dart` script materializes them for deployment.

### 5.3 Layer 3 — Docs & handoffs

- Replace `C:\Users\avidu\...` absolute paths in `HANDOFF.md` and
  `SESSION_HANDOFF.md` with a portable form: "see the shared project-memory
  store (path resolved by the `claude-sync` tooling on each machine)".
- Replace `avis-pbook.tail651ec3.ts.net` in docs with `<your-forgejo-host>`
  placeholders plus a documented override step in `README.md`.
- Replace `avidullu/agentforge` owner/repo examples with
  `<owner>/<repo>` placeholders in user-facing docs; keep the real
  owner/repo only where it is genuinely the canonical reference (e.g. the
  "Repository" table in `README.md`), and make even that configurable via the
  new config layer.
- Add a `docs/CONFIGURATION.md` explaining all override points.

### 5.4 Layer 4 — Pre-commit guard (prevents regression)

Add `tool/check_no_pii.dart` (wired into CI and a git pre-commit hook) that
fails if any tracked file matches the known PII patterns:

```
C:\Users\\avidu
avis-pbook
tail651ec3
Avi Dullu
com\.avidullu
```

with an explicit allow-list for the canonical-repo reference lines if the
owner chooses to keep them. This is the **extensible** anchor: adding a new
pattern is a one-line edit.

## 6. Implementation strategy

Sequenced so each step is independently shippable and reviewable. Every step
keeps `flutter analyze`, `flutter test --coverage`, format, and the Android
build green.

| Step | Scope | Files (representative) | Verify |
|---|---|---|---|
| **S1** | Add config layer + PII guard scaffold | `lib/core/config/app_config.dart`, `tool/check_no_pii.dart`, `config/local.example.json`, `.gitignore` entry for `config/local.json`, `tool/config.dart` define-generator | `flutter analyze` clean; guard runs and reports the current PII hits |
| **S2** | Wire Dart source to `AppConfig` | `lib/core/deep_links/deep_link.dart`, `lib/core/settings/app_settings.dart`, `lib/features/home/*`, `lib/features/agents/*`, `tool/demo_avis_pbook.dart` (rename → `tool/demo_forgejo.dart`) | UI smoke; deep-link unit tests still pass after fixture swap |
| **S3** | Swap tests to synthetic fixtures | `test/deep_link_test.dart`, `test/forgejo_client_test.dart`, `test/forgejo_models_test.dart` | `flutter test --coverage` ≥ 29% floor, no real identifiers remain |
| **S4** | Parameterize Android | `android/app/build.gradle.kts`, `android/gradle.properties`, `android/app/src/main/AndroidManifest.xml`, rename Kotlin package dir | `flutter build apk --debug` succeeds with override id |
| **S5** | Parameterize iOS | `ios/Runner.xcodeproj/project.pbxproj`, `ios/Runner/*.plist`, `ios/Runner/Runner.entitlements`, `ios/Config.example.xcconfig` | `xcodebuild -showConfig` resolves override; plists valid |
| **S6** | Templatize well-known + docs | `docs/well-known/*.template`, `tool/render_well_known.dart`, `README.md`, `docs/*.md`, `HANDOFF.md`, `SESSION_HANDOFF.md`, new `docs/CONFIGURATION.md` | guard passes; docs render |
| **S7** | CI wire-up + tracker update | `.github/workflows/ci.yml` (run guard), Forgejo CI mirror, add `AF-009` row + changelog in `docs/08-*` | CI green; tracker row status accurate |

**Branching:** each step is a PR off `origin/main`; S2–S7 stack on S1.
Per repo convention, PRs are published **ready-for-review** (avidullu
preference).

**Extensibility rationale:** the four layers each have exactly one override
point, and the PII guard is the regression backstop. Adding a new
environment value or a new redacted pattern is a localized change — it does
not cascade through source. This satisfies the "clean and extensible
mechanism" requirement.

## 7. Risks and mitigations

| Risk | Mitigation |
|---|---|
| Renaming the Android package directory breaks the existing installed app / signing continuity | Document as a breaking reinstall; gate behind S4 PR review; the owner's release signing is `AF-002` and not yet shipped, so no released users are affected |
| Deep-link `autoVerify` depends on the exact host in `assetlinks.json` | Templates materialize at deploy time from the same config; CI guard ensures the checked-in template has no host |
| `--dart-define` increases local-run complexity | `tool/config.dart` reads `config/local.json` so the developer UX is `dart run tool/config.dart -- flutter run`; documented in `README.md` quick-start |
| Owner wants the canonical repo link to remain visible | Allow-list flag in `tool/check_no_pii.dart` for the explicit `README.md` repository table line |
| Git history still contains the identifiers | Out of scope by default; if requested, a separate force-push history rewrite + mirror re-publish is tracked as a follow-up `AF-010` |

## 8. Acceptance criteria (Definition of Done for AF-009)

- [ ] `tool/check_no_pii.dart` runs in CI and passes on `main`.
- [ ] No tracked file under `lib/`, `test/`, `tool/`, `android/`, `ios/`,
      `web/`, or `docs/` contains `C:\Users\avidu`, `avis-pbook`,
      `tail651ec3`, `Avi Dullu`, or `com.avidullu` (except an explicit,
      reviewed allow-list).
- [ ] A clean clone + `cp config/local.example.json config/local.json` +
      one-time native override lets a second developer build and run.
- [ ] `flutter analyze --fatal-infos`, `flutter test --coverage` (≥ 29%),
      `dart format --set-exit-if-changed`, and `flutter build apk --debug`
      all pass.
- [ ] `docs/CONFIGURATION.md` documents every override point.
- [ ] Tracker row `AF-009` added to `docs/08-*` with status and PR links;
      changelog updated.

## 9. Requested review

Per the global code-review gate, please review this bug doc and reply with
**LGTM** (or requested changes) before implementation begins. I will not
start S1 until the plan and implementation strategy are approved.

Specifically seeking sign-off on:

1. The **four-layer mechanism** (Dart config, native parameterization, doc
   templates, PII guard) as the chosen "clean and extensible" approach.
2. Whether the canonical `avidullu/agentforge` repository reference in
   `README.md` should be **kept** (allow-listed) or **also redacted**.
3. Whether the Android package directory rename in S4 is acceptable.
4. Whether a follow-up history-rewrite item (`AF-010`) should be opened now.
