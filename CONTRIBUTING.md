# CONTRIBUTING

## Makefile is the driver

This project exposes a consistent Make interface.
Targets may wrap native tooling (for example, `make build` may run `npm run build`, `go build`, `cargo build`, etc.);
The Makefile specifies the interface and required results, not the tools used to produce them.

`make build` MUST depend on `make test-all`; a build only succeeds when all tests
(unit, integration, and end-to-end) pass.

## Testing standards

Testing and code coverage are part of the SDLC and are driven through the Makefile.

### Makefile is the test and coverage driver

Required targets:

- `make test` — runs the unit/integration test suite.
- `make test-e2e` — runs the end-to-end suite (including UI).
- `make test-all` — runs `make test` then `make test-e2e`.
- `make coverage` — runs tests with coverage measurement.

`make build` MUST depend on `make test-all`.

### Gates

- `make test` MUST fail the build when any test fails.
- `make test-e2e` MUST fail the build when any scenario fails.
- `make coverage` MUST fail the build when total code coverage, including branches,
  is below 90%.
  Coverage applies to the `make test` unit/integration suite; end-to-end tests provide
  behavioral coverage of user journeys and are not subject to the line/branch threshold.

### End-to-end and UI testing

End-to-end tests, including UI, MUST be fronted by **Gherkin** feature specifications
(`Given`/`When`/`Then`). Gherkin is required as a *format*, not a specific tool — any
Cucumber-family runner (in any language) is acceptable, consistent with this document's
tool-agnostic stance.

Each feature file MUST clearly document its **purpose and goal** in the `Feature`
description, and scenarios MUST be named for the behavior they verify (not the mechanics).
Feature files live in a conventional top-level `./features/` directory.

The intent is that feature specs double as living documentation of intended behavior,
readable by non-engineers.

### Required output formats

Outputs are specified by result format, not by tool:

- Test results MUST be emitted as JUnit XML.
- End-to-end results MUST be emitted as JUnit XML.
- Coverage MUST be emitted in lcov format.
- HTML versions of test, end-to-end, and coverage output are optional but recommended.

### Output locations

- Test output: `./reports/testing/`
- End-to-end output: `./reports/e2e/`
- Coverage output: `./reports/coverage/`

`./reports/` is generated output and MUST be gitignored.

### HTML index (optional)

If HTML output is produced, a `./reports/index.html` will be created that links to the available test, end-to-end, and coverage HTML reports.
When `./reports/index.html` present it should be simple and professional, with clear labels describing each linked report's purpose.
