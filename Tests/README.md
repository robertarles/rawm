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

Artifacts land in `build/` (gitignored): `build/TestResults.xcresult` and
`build/DerivedData`.

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

## Coverage gate

`coverage-thresholds.json` holds the floor (`line`, `region`). The floor only moves
up: after landing tests, run `make coverage-baseline` to ratchet it. The gate's
scope (the "testable core") is whatever is **not** matched by
`scripts/coverage-ignore.txt` — pure-UI/bootstrap files are excluded there.
