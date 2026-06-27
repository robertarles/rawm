# Plan: Excellent Testing + >80% Coverage (line & branch), Enforced in the SDLC

## Goal

1. Build a genuinely useful test suite for `rawm`, concentrated on the logic that
   matters (window geometry, clipboard model/storage, shortcut/cycle/defaults logic,
   utilities).
2. Reach **>80% coverage including branches** over a defined **testable core**.
3. Make coverage a first-class part of the SDLC: **builds break** locally (pre-push)
   and in CI when tests fail *or* coverage drops below the gate.

---

## Current state (assessment)

- ~22,400 LOC / 264 Swift files across 16 modules.
- **2 test files**, ~60 test methods — covers a thin slice only.
- **No coverage instrumentation** in the scheme (`codeCoverageEnabled` absent).
- **CI is broken**: `.github/workflows/build.yml` references `Rectangle.xcodeproj`
  /`Rectangle` (the project is `rawm`), and only *builds* — it never runs tests.
- Git hooks (`pre-commit`/`pre-push`) only do secret scanning. No test/coverage gate.
- `Makefile` has a `test` target but no coverage collection or gate.
- `jq` available; `xcpretty`/`slather`/`xcov` not installed (we avoid the heavy
  third-party tools and use native `xccov` + `llvm-cov`).

---

## Strategy decisions (confirmed)

- **Denominator = "testable core", then ratchet.** The 80% gate applies to logic
  modules, not UI glue. Pure-UI/bootstrap files are excluded via a single
  `-ignore-filename-regex` shared by the gate. The excluded set is documented and
  small; everything else counts.
- **Line coverage via `xccov`** (Xcode result bundle) **and branch coverage via
  `llvm-cov`** (against the `.profdata` + test binary). Both must pass the gate.
- **Ratchet, don't big-bang.** Start the gate at the measured baseline and raise the
  floor as tests land, until line ≥ 80% and branch ≥ 80%. The floor can only go up.

### Testable core (counts toward the gate)

- `Sources/WindowCalculation/**` — pure geometry (largest, highest value)
- `Sources/Utilities/**` — extensions, `Debounce`, `TimeoutCache`, `SequenceExtension`,
  `StringExtension`, `CGExtension`, `CFExtension`, etc.
- `Sources/Clipboard/Models/**` and most of `Sources/Clipboard/Observables/**`
  (`History`, `HistoryItemDecorator`, `NavigationManager`, `ModifierFlags`, `FooterItem`)
- `Sources/Snapping/**` (session/state logic)
- Root logic: `WindowAction`, `WindowActionCategory`, `CycleSize`, `Defaults`,
  `ShortcutManager`, `ShortcutMigration`, `WindowHistory`, `ScreenDetection`,
  `RawmActionTypes`, `SubsequentExecutionMode`, `ApplicationToggle`, `AccessibilityElement`

### Excluded from the gate (pure UI / bootstrap — documented exclusion list)

- `Sources/Clipboard/Views/**`, `Sources/PrefsWindow/**`, `Sources/WelcomeWindow/**`,
  `Sources/Popover/**`
- `AppDelegate`, `RawmStatusItem`, `TitleBarManager`, `GreenButtonManager`,
  `CrashReporter`, `LaunchOnLogin`, `ClipboardBootstrap`, `*View.swift`, `*.xcassets`
- Generated/3rd-party (MASShortcut shims if vendored)

> Exclusions live in **one** place: `scripts/coverage-ignore.txt` (regex fragments),
> consumed by both `xccov` post-filter and `llvm-cov -ignore-filename-regex`.

---

## Phase 0 — Coverage instrumentation & gate tooling (foundation)

**bean: infra — enable coverage + gate script**

- [ ] Enable coverage in `rawm.xcscheme` `TestAction`:
  `codeCoverageEnabled = "YES"`, `onlyGenerateCoverageForSpecifiedTargets = "YES"`,
  `<CodeCoverageTargets>` → the `rawm` app target.
- [ ] Add `scripts/coverage-ignore.txt` (regex fragments for the exclusion list above).
- [ ] Add `scripts/run-tests.sh`: runs
  `xcodebuild test -project rawm.xcodeproj -scheme rawm -destination 'platform=macOS'
   -enableCodeCoverage YES -resultBundlePath build/TestResults.xcresult
   -derivedDataPath build/DerivedData` (with the existing `SIGN_FLAGS`).
- [ ] Add `scripts/coverage-gate.sh`:
  - **Line %**: `xcrun xccov view --report --json build/TestResults.xcresult`,
    filter files by the include/exclude rules, aggregate covered/executable lines via `jq`.
  - **Branch %**: locate `Coverage.profdata` under `build/DerivedData` and the test
    host binary, run
    `xcrun llvm-cov export -instr-profile <profdata> <binary>
     -ignore-filename-regex="$(paste -sd'|' scripts/coverage-ignore.txt)"
     --summary-only` → parse `data[].totals.branches.percent` and `.lines.percent`.
  - Read floors from `coverage-thresholds.json` (`{ "line": N, "branch": N }`).
  - Print a per-module table; **exit non-zero** if line% or branch% < floor.
- [ ] Add `coverage-thresholds.json` seeded with the **measured baseline** (Phase 1).
- [ ] Makefile targets: `make test` (runs `run-tests.sh`), `make coverage`
  (test + `coverage-gate.sh`), `make coverage-report` (human-readable table / html).

**Acceptance:** `make coverage` runs tests, prints line+branch% for the core, and
exits non-zero when below the floor.

---

## Phase 1 — Establish baseline & fix CI (unblocks everything)

**bean: fix CI to test rawm + run coverage gate**

- [ ] Rewrite `.github/workflows/build.yml` (or add `test.yml`):
  - Correct project/scheme to `rawm` / `rawm.xcodeproj`.
  - Job `test`: checkout → select Xcode → `make coverage` (tests + gate).
  - **Build/archive job depends on `test` passing** so a red suite blocks the pipeline.
  - Upload `build/TestResults.xcresult` and a coverage summary as artifacts.
  - Run on `push` + `pull_request`; require the `test` check for merge (branch protection note).
- [ ] Capture the **baseline** line% and branch% from the first green run; write them
  into `coverage-thresholds.json` as the initial floor (no regressions allowed from day one).

**Acceptance:** CI runs `rawm` tests, fails on test failure or coverage regression,
and only builds/archives after tests pass.

---

## Phase 2 — Test infrastructure & helpers

**bean: test harness & fixtures**

- [ ] Reorganize `Tests/` into per-module files; add a `Tests/Helpers/` with:
  - Screen/`CGRect` fixture builders (common display geometries) for WindowCalculation.
  - A `UserDefaults` sandbox helper (isolated suite per test) for Defaults/Shortcut tests.
  - Clipboard `HistoryItem` builders.
- [ ] Document the testing conventions in `Tests/README.md` (naming, fixtures, how to
  run `make coverage`, how the ratchet works).

---

## Phase 3 — Write tests by module (parallelizable via coordinator/worker)

Each is an independent bean; dispatch in parallel. Target ≥80% line+branch per module.

- [ ] **bean: WindowCalculation tests** (largest payoff) — table-driven tests across the
  ~108 calculators: halves/thirds/fourths/sixths/eighths/ninths/twelfths/sixteenths,
  corners, cycle behavior, gaps/padding, multi-display, edge rects (zero/negative origin,
  tiny/huge screens). Branch focus: the conditional sizing/cycling paths.
- [ ] **bean: Utilities tests** — `Debounce`, `TimeoutCache`, `SequenceExtension`,
  `StringExtension`, `CGExtension`, `CFExtension`, `DispatchTimeExtension`,
  `NotificationExtension`. Pure, fast, high-branch-density.
- [ ] **bean: Clipboard model/storage tests** — `HistoryItem`, `HistoryItemContent`,
  `History`, `HistoryItemDecorator` (filtering/search/pinning/dedupe), `ModifierFlags`,
  `NavigationManager`, `FooterItem`. Cover the memory-only vs disk-persistence branches
  (recent `rawm-4ha8` change).
- [ ] **bean: Shortcut/cycle/defaults tests** — extend existing `ShortcutCycle`,
  `ShortcutManager`, `ShortcutMigration`, `CycleSize`, `Defaults` export/import, legacy
  key migration branches.
- [ ] **bean: Snapping + window-history tests** — extend `SnappingManager` session logic,
  `WindowHistory`, `ScreenDetection`, `ApplicationToggle`.
- [ ] **bean: Screen/geometry edge & accessibility logic** — `AccessibilityElement`
  testable paths, `ScreenFlipped`, clamping/overlap guards (extend existing).

> After each module bean lands, **raise the floor** in `coverage-thresholds.json` toward 80.

---

## Phase 4 — Local enforcement (pre-push gate)

**bean: pre-push test+coverage gate**

- [ ] Extend `.githooks/pre-push` to run `make coverage` after the secret scans
  (bypassable with `--no-verify`, consistent with current hooks).
- [ ] Keep it reasonably fast: run the full suite on push (not every commit); document
  the bypass and the CI fallback.

**Acceptance:** a push that fails tests or drops coverage is blocked locally.

---

## Phase 5 — Reach and lock 80%+ (ratchet to target)

**bean: ratchet floors to >=80% line & branch**

- [ ] Iterate: add tests for the lowest-covered core files (use the per-module table),
  raising floors until **line ≥ 80% and branch ≥ 80%** over the core.
- [ ] Freeze the gate at 80/80 (or higher if comfortably exceeded). Document that the
  floor only moves up.
- [ ] Update `README.md` / `AGENTS.md` with a "Testing & Coverage" section: how to run,
  the gate, the ratchet, and the exclusion policy.

---

## Deliverables checklist

- [ ] Coverage enabled in scheme; `scripts/run-tests.sh`, `scripts/coverage-gate.sh`,
      `scripts/coverage-ignore.txt`, `coverage-thresholds.json`.
- [ ] `make test` / `make coverage` / `make coverage-report`.
- [ ] CI runs `rawm` tests + coverage gate; build depends on tests passing.
- [ ] `pre-push` runs the coverage gate.
- [ ] Tests per module reaching ≥80% line & branch over the testable core.
- [ ] Docs: `Tests/README.md` + README/AGENTS testing section.

## Risks / notes

- 80% **branch** coverage on a GUI app is only realistic against the scoped core; the
  exclusion list is the lever that keeps the target honest and achievable.
- `xccov` reports line coverage; branch % comes from `llvm-cov export` — both wired into
  one gate so "including branching" is genuinely enforced, not approximated.
- Keep the exclusion regex minimal and reviewed — every excluded file is coverage we're
  choosing not to measure.
