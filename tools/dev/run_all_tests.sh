#!/usr/bin/env bash
# Loop Town Demo 9 - full validator matrix (macOS / Linux).
#
# Usage: GODOT=/path/to/godot tools/dev/run_all_tests.sh [log_dir]
# A suite fails on a non-zero exit code OR on any engine/script ERROR line that
# is not listed in tools/dev/error_whitelist.txt (one extended regex per line).
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
GODOT="${GODOT:-godot}"
LOG_DIR="${1:-$ROOT/logs/validators}"
WHITELIST="$ROOT/tools/dev/error_whitelist.txt"
mkdir -p "$LOG_DIR"

SUITES=(
  validate_project validate_assets validate_runtime validate_gameplay
  validate_transition validate_exploration validate_experience_improvements
  validate_v9_art validate_v9_museum_mid validate_v9_item3 validate_v9_item4
  validate_v9_item5 validate_v9_item6 validate_v9_animation
  validate_visual_pass
)

failed=0
printf "%-36s %5s %7s  %s\n" "suite" "exit" "errors" "verdict" > "$LOG_DIR/summary.txt"
for suite in "${SUITES[@]}"; do
  log="$LOG_DIR/$suite.log"
  "$GODOT" --headless --path "$ROOT" --script "res://tools/dev/$suite.gd" > "$log" 2>&1
  code=$?
  errs="$(grep -E '(^|[[:space:]])(SCRIPT ERROR|ERROR):|ObjectDB instances leaked' "$log" || true)"
  if [ -n "$errs" ] && [ -f "$WHITELIST" ]; then
    errs="$(printf '%s\n' "$errs" | grep -v -E -f <(grep -v -E '^\s*(#|$)' "$WHITELIST") || true)"
  fi
  count=0
  [ -n "$errs" ] && count="$(printf '%s\n' "$errs" | wc -l | tr -d ' ')"
  verdict=PASS
  if [ "$code" -ne 0 ] || [ "$count" -ne 0 ]; then verdict=FAIL; failed=1; fi
  printf "%-36s %5s %7s  %s\n" "$suite" "$code" "$count" "$verdict" | tee -a "$LOG_DIR/summary.txt"
  [ "$count" -ne 0 ] && printf '%s\n' "$errs" | head -5 | sed 's/^/    /'
done
if [ "$failed" -ne 0 ]; then echo "REGRESSION: FAILURES PRESENT"; exit 1; fi
echo "REGRESSION: ALL PASSED"
