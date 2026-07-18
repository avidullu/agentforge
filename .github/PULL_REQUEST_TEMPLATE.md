<!-- Describe the change and link the issue it closes. -->

## Summary



## Pre-submit checklist
- [ ] `dart format --output=none --set-exit-if-changed lib test tool` — clean
- [ ] `flutter analyze --fatal-infos` — clean
- [ ] `dart run tool/run_all_tests.dart` — all tests green, coverage ≥ floor (29%)
- [ ] `flutter build apk --debug` — succeeds
- [ ] `flutter build web --release --no-wasm-dry-run` — succeeds
- [ ] Tracker row updated (`docs/08-Implementation-Plan-and-Milestones.md`)
- [ ] Changelog entry in the tracker doc

## Only for PRs that close a tracked deliverable
- [ ] Verified each doc claim against shipped code
- [ ] Updated all inbound references (README, handoff, cross-doc links)
- [ ] Archived terminal docs per `DOC_STATUS.md` if one exists
