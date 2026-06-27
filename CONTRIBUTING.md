# CONTRIBUTING

## Makefile is the driver

This project exposes a consistent Make interface.
Targets may wrap native tooling (for example, `make build` may run `npm run build`, `go build`, `cargo build`, etc.);
The Makefile specifies the interface and required results, not the tools used to produce them.

## Testing standards

Testing and code coverage are part of the SDLC and are driven through the Makefile.

### Makefile is the test and coverage driver

Required targets:

- `make test` — runs the test suite.
- `make coverage` — runs tests with coverage measurement.

### Gates

- `make test` MUST fail the build when any test fails.
- `make coverage` MUST fail the build when total code coverage, including branches,
  is below 90%.

### Required output formats

Outputs are specified by result format, not by tool:

- Test results MUST be emitted as JUnit XML.
- Coverage MUST be emitted in lcov format.
- HTML versions of test and coverage output are optional but recommended.

### Output locations

- Test output: `./reports/testing/`
- Coverage output: `./reports/coverage/`

`./reports/` is generated output and MUST be gitignored.

### HTML index (optional)

If HTML output is produced, a `./reports/index.html` will be created that links to the available test and coverage HTML reports.
When `./reports/index.html` present it should be simple and professional, with clear labels describing each linked report's purpose.
