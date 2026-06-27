#!/usr/bin/env bash
# scripts/run-tests.sh
#
# Runs the rawm test suite with code coverage enabled, producing a result
# bundle and derived data that scripts/coverage-gate.sh consumes.
#
# Output:
#   build/TestResults.xcresult   — xccov reads line coverage from here
#   build/DerivedData/...        — contains Coverage.profdata + test binary
#   reports/testing/junit.xml    — JUnit XML (per CONTRIBUTING.md)
#   reports/testing/index.html   — HTML summary
#
# Exit status mirrors the test run (non-zero if any test fails) — JUnit is still
# emitted on failure so the failures are recorded.
#
# Usage: scripts/run-tests.sh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

PROJECT="rawm.xcodeproj"
SCHEME="rawm"
BUILD_DIR="$REPO_ROOT/build"
RESULT_BUNDLE="$BUILD_DIR/TestResults.xcresult"
DERIVED_DATA="$BUILD_DIR/DerivedData"
REPORTS_DIR="$REPO_ROOT/reports/testing"

# Ad-hoc signing for test builds (matches Makefile SIGN_FLAGS).
SIGN_FLAGS=(CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=YES)

# Fresh result bundle each run (xcodebuild refuses to overwrite).
rm -rf "$RESULT_BUNDLE"
mkdir -p "$BUILD_DIR"

echo "[run-tests] building & testing $SCHEME with coverage…"
set -o pipefail
# Capture the test exit status without aborting — we want JUnit emitted even on failure.
test_status=0
xcodebuild test \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -destination 'platform=macOS' \
  -enableCodeCoverage YES \
  -resultBundlePath "$RESULT_BUNDLE" \
  -derivedDataPath "$DERIVED_DATA" \
  "${SIGN_FLAGS[@]}" \
  | (xcpretty 2>/dev/null || cat) || test_status=$?

# Emit JUnit XML + HTML summary (per CONTRIBUTING.md) from the result bundle.
if [[ -d "$RESULT_BUNDLE" ]]; then
  mkdir -p "$REPORTS_DIR"
  python3 "$REPO_ROOT/scripts/xcresult-to-junit.py" "$RESULT_BUNDLE" "$REPORTS_DIR" || true
fi

echo "[run-tests] done. Result bundle: $RESULT_BUNDLE"
exit "$test_status"
