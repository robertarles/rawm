#!/usr/bin/env bash
# scripts/coverage-gate.sh
#
# Computes coverage over the "testable core" and fails (exit 1) if line% or
# region% is below the floor in coverage-thresholds.json.
#
#   Line coverage   <- xccov (Xcode result bundle)
#   Region coverage <- llvm-cov export (against Coverage.profdata + app object files)
#
# Why region coverage and not "branch" coverage:
#   The Swift toolchain shipped with Xcode emits source-based *region* coverage,
#   not LLVM per-branch counters (llvm-cov reports branches.count == 0 for Swift
#   binaries). Region coverage is the llvm-native, branch-sensitive metric for
#   Swift: every conditional path is its own region, so it is strictly finer than
#   line coverage and is what the ecosystem (e.g. Codecov) treats as the branch
#   equivalent. We gate on it as our "branch including" metric.
#
#   Also note: the linked rawm.app binary is NOT instrumented (DEAD_CODE_STRIPPING
#   drops the coverage sections), so llvm-cov is pointed at the app target's .o
#   files, which carry the __llvm_covmap/__llvm_covfun sections.
#
# The "core" = files under /Sources/ that do NOT match scripts/coverage-ignore.txt.
#
# Prerequisite: scripts/run-tests.sh has produced build/TestResults.xcresult and
# build/DerivedData. Run `make coverage` to do both in sequence.
#
# Flags:
#   --update-baseline   Write the measured line/region% into coverage-thresholds.json
#                       instead of gating. Use to seed or ratchet the floor up.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

BUILD_DIR="$REPO_ROOT/build"
RESULT_BUNDLE="$BUILD_DIR/TestResults.xcresult"
DERIVED_DATA="$BUILD_DIR/DerivedData"
IGNORE_FILE="$REPO_ROOT/scripts/coverage-ignore.txt"
THRESHOLDS="$REPO_ROOT/coverage-thresholds.json"
REPORTS_DIR="$REPO_ROOT/reports/coverage"

UPDATE_BASELINE=0
[[ "${1:-}" == "--update-baseline" ]] && UPDATE_BASELINE=1

command -v jq >/dev/null 2>&1 || { echo "coverage-gate: jq is required (brew install jq)"; exit 2; }
[[ -d "$RESULT_BUNDLE" ]] || { echo "coverage-gate: $RESULT_BUNDLE not found — run scripts/run-tests.sh first"; exit 2; }

# Exclude regex (extended) from the ignore file: strip comments/blanks, join with '|'.
EXCLUDE_RE="$(grep -vE '^[[:space:]]*(#|$)' "$IGNORE_FILE" | paste -sd'|' -)"
INCLUDE_RE='/Sources/'

# ---------------------------------------------------------------------------
# LINE COVERAGE via xccov
# ---------------------------------------------------------------------------
echo "[gate] computing line coverage (xccov)…"
LINE_JSON="$(xcrun xccov view --report --json "$RESULT_BUNDLE")"

read -r LINE_COVERED LINE_EXEC LINE_PCT < <(
  echo "$LINE_JSON" | jq -r \
    --arg inc "$INCLUDE_RE" --arg exc "$EXCLUDE_RE" '
    [ .targets[].files[]
      | select(.path | test($inc))
      | select(.path | test($exc) | not) ]
    | (map(.coveredLines)    | add // 0) as $cov
    | (map(.executableLines) | add // 0) as $exe
    | "\($cov) \($exe) \(if $exe > 0 then ($cov*10000/$exe|floor)/100 else 0 end)"
  '
)

# ---------------------------------------------------------------------------
# REGION (branch-sensitive) COVERAGE via llvm-cov against the app .o files
# ---------------------------------------------------------------------------
echo "[gate] computing region coverage (llvm-cov)…"
PROFDATA="$(find "$DERIVED_DATA" -name 'Coverage.profdata' -print -quit 2>/dev/null || true)"
# App target objects only (exclude the rawm-tests target's Objects-normal dir).
APP_OBJ_DIR="$(find "$DERIVED_DATA/Build/Intermediates.noindex" -type d \
  -path '*/rawm.build/Objects-normal/*' 2>/dev/null | grep -v 'rawm-tests' | head -1 || true)"

REGION_COVERED=0 REGION_TOTAL=0 REGION_PCT=0
OBJ_ARGS=()
if [[ -n "$PROFDATA" && -n "$APP_OBJ_DIR" ]]; then
  while IFS= read -r o; do OBJ_ARGS+=( -object "$o" ); done < <(find "$APP_OBJ_DIR" -name '*.o')
  if [[ ${#OBJ_ARGS[@]} -gt 0 ]]; then
    REGION_JSON="$(xcrun llvm-cov export \
      -instr-profile "$PROFDATA" "${OBJ_ARGS[@]}" \
      -ignore-filename-regex="$EXCLUDE_RE" \
      --summary-only 2>/dev/null)"
    read -r REGION_COVERED REGION_TOTAL REGION_PCT < <(
      echo "$REGION_JSON" | jq -r '
        .data[0].totals.regions
        | "\(.covered) \(.count) \((.percent*100|floor)/100)"
      '
    )
  fi
else
  echo "[gate] WARNING: profdata or app object dir not found; region coverage unavailable."
  echo "[gate]   profdata:    ${PROFDATA:-<none>}"
  echo "[gate]   app obj dir: ${APP_OBJ_DIR:-<none>}"
fi

# ---------------------------------------------------------------------------
# EMIT REPORTS: lcov (required) + HTML (recommended), per CONTRIBUTING.md
# Note: the Swift toolchain emits source-based *region* coverage, not LLVM
# per-branch counters, so lcov BRDA/branch records will be empty/minimal.
# ---------------------------------------------------------------------------
if [[ -n "$PROFDATA" && ${#OBJ_ARGS[@]} -gt 0 ]]; then
  mkdir -p "$REPORTS_DIR"
  echo "[gate] writing lcov -> $REPORTS_DIR/coverage.lcov"
  xcrun llvm-cov export -format=lcov \
    -instr-profile "$PROFDATA" "${OBJ_ARGS[@]}" \
    -ignore-filename-regex="$EXCLUDE_RE" \
    > "$REPORTS_DIR/coverage.lcov" 2>/dev/null || echo "[gate] WARNING: lcov export failed"
  echo "[gate] writing HTML -> $REPORTS_DIR/html/index.html"
  xcrun llvm-cov show -format=html \
    -instr-profile "$PROFDATA" "${OBJ_ARGS[@]}" \
    -ignore-filename-regex="$EXCLUDE_RE" \
    -output-dir "$REPORTS_DIR/html" >/dev/null 2>&1 || echo "[gate] WARNING: HTML report failed"
fi

# ---------------------------------------------------------------------------
# REPORT
# ---------------------------------------------------------------------------
echo
echo "  ┌─ Coverage (whole project)  [target: 90% incl. branches] ──"
printf "  │  Line:   %6s%%   (%s / %s lines)\n"   "$LINE_PCT"   "$LINE_COVERED"   "$LINE_EXEC"
printf "  │  Region: %6s%%   (%s / %s regions)\n" "$REGION_PCT" "$REGION_COVERED" "$REGION_TOTAL"
echo "  └───────────────────────────────────────────────────────────"
echo

echo "  Lowest-covered files (by line %):"
echo "$LINE_JSON" | jq -r \
  --arg inc "$INCLUDE_RE" --arg exc "$EXCLUDE_RE" '
  [ .targets[].files[]
    | select(.path | test($inc)) | select(.path | test($exc) | not)
    | select(.executableLines > 0)
    | { name: (.path | split("/Sources/")[-1]), pct: ((.lineCoverage*10000|floor)/100), exe: .executableLines } ]
  | sort_by(.pct) | .[:12][]
  | "    \((.pct|tostring|. + "       ")[0:7])%  \(.name)  (\(.exe) lines)"
'
echo

# ---------------------------------------------------------------------------
# UPDATE BASELINE or GATE
# ---------------------------------------------------------------------------
if [[ "$UPDATE_BASELINE" == "1" ]]; then
  jq -n --argjson line "$LINE_PCT" --argjson region "$REGION_PCT" \
    '{line:$line, region:$region}' > "$THRESHOLDS"
  echo "[gate] baseline written to coverage-thresholds.json: line=$LINE_PCT% region=$REGION_PCT%"
  echo "[gate] NOTE: the floor only moves up — do not lower these by hand."
  exit 0
fi

[[ -f "$THRESHOLDS" ]] || { echo "coverage-gate: $THRESHOLDS missing — seed it with: scripts/coverage-gate.sh --update-baseline"; exit 2; }
FLOOR_LINE="$(jq -r '.line'   "$THRESHOLDS")"
FLOOR_REGION="$(jq -r '.region' "$THRESHOLDS")"

fail=0
awk "BEGIN{exit !($LINE_PCT   < $FLOOR_LINE)}"   && { echo "✗ line coverage $LINE_PCT% < floor $FLOOR_LINE%";       fail=1; } || echo "✓ line coverage $LINE_PCT% >= floor $FLOOR_LINE%"
awk "BEGIN{exit !($REGION_PCT < $FLOOR_REGION)}" && { echo "✗ region coverage $REGION_PCT% < floor $FLOOR_REGION%"; fail=1; } || echo "✓ region coverage $REGION_PCT% >= floor $FLOOR_REGION%"

if [[ "$fail" == "1" ]]; then
  echo
  echo "coverage-gate: FAILED — coverage dropped below the floor."
  exit 1
fi
echo
echo "coverage-gate: PASSED"
