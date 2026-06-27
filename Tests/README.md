# rawm test suite

> Working conventions for the automated tests. For the higher-level testing
> philosophy doc see `TESTING_STANDARDS.md` (separate, in progress).

## Running

```bash
make test              # build + run the suite with coverage instrumentation
make coverage          # test + enforce the coverage floor (CI runs this)
make coverage-report   # print the coverage table without gating
make coverage-baseline # ratchet the floor up to the current measurement
```

Build artifacts land in `build/` (gitignored): `build/TestResults.xcresult` and
`build/DerivedData`.

### Reports (CONTRIBUTING.md compliance)

`make test`/`make coverage` also emit standardized reports under `./reports/`
(gitignored generated output):

- `reports/testing/junit.xml` — test results as **JUnit XML**; `index.html` summary.
- `reports/coverage/coverage.lcov` — coverage in **lcov** format; `html/` browsable report.
- `reports/index.html` — landing page linking both.

Scope is **whole-project** (all `/Sources/`; only test/build/toolchain code is excluded
via `scripts/coverage-ignore.txt`). CONTRIBUTING.md's **90%-incl-branches target** is the
goal; the enforced gate is the ratchet floor in `coverage-thresholds.json` (so CI isn't
blocked while coverage climbs). Note: Swift emits source-based *region* coverage, not LLVM
per-branch counters, so lcov branch (`BRDA`) records are empty — region% is the
branch-sensitive metric the gate uses.

## Layout

- `TestSupport.swift` — shared, dependency-free fixtures and assertions. Use these
  instead of re-deriving setup in each file.
  - `TestScreens` — common visible-frame `CGRect` fixtures.
  - `rectParams(_:visibleFrame:windowRect:lastAction:)` / `repeatedRectParams(...)`
    — build `RectCalculationParameters` for WindowCalculation tests.
  - `assertRectsEqual(_:_:accuracy:)` — tolerant rect comparison (reports the
    differing component).
  - `RawmDefaultsSnapshot` — capture in `setUp`, `.restore()` in `tearDown` to keep
    global `RawmDefaults` (UserDefaults-backed) state from leaking between tests.
- `WindowCalculationTests.swift` — window geometry calculators.
- `UtilitiesTests.swift` — `Sources/Utilities` helpers/extensions.
- `ClipboardModelTests.swift` — clipboard models/storage/observables.
- `ShortcutDefaultsTests.swift` — shortcut/cycle/defaults/migration logic.
- `SnappingHistoryTests.swift` — snapping, window history, screen detection.
- `RawmTests.swift`, `ShortcutRecordingObserverTests.swift` — pre-existing tests.

## Conventions

- **Pure where possible.** WindowCalculation tests call `calculateRect(_:)` with
  synthetic params — no `NSScreen`, no running app. Prefer this style.
- **No global state leaks.** Any test that mutates `RawmDefaults` must snapshot and
  restore via `RawmDefaultsSnapshot`.
- **Cover branches, not just lines.** The gate measures *region* coverage (Swift's
  branch-sensitive metric). Add cases for each conditional path: empty/zero/negative
  rects, deselected cycle sizes, repeated vs first invocation, optional-nil paths.
- **Floats use tolerance.** Compare geometry with `assertRectsEqual` /
  `XCTAssertEqual(_, accuracy:)`, never `==`.

## Adding a new test file

New files must be registered in the `rawm-tests` target:

```bash
scripts/add-test-files.py Tests/MyNewTests.swift
```

(Idempotent; skips files already registered.) Then `make test`.

## Local enforcement (pre-push hook)

The versioned hooks live in `.githooks/`. Activate them once per clone:

```bash
git config core.hooksPath .githooks
```

`pre-push` then runs the secret scans **and** `make coverage`, so a push is blocked
if tests fail or coverage drops below the floor. It builds the app, so it takes a
bit; bypass a single push with `git push --no-verify`, or disable entirely with
`git config --unset core.hooksPath`. CI enforces the same gate regardless.

## Coverage gate

`coverage-thresholds.json` holds the floor (`line`, `region`). The floor only moves
up: after landing tests, run `make coverage-baseline` to ratchet it. The gate's
scope (the "testable core") is whatever is **not** matched by
`scripts/coverage-ignore.txt` — pure-UI/bootstrap files are excluded there.
