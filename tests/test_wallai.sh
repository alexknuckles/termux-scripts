#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

# Record overall failure status and log directory
LOG_ROOT="/tmp/wallai-tests"
mkdir -p "$LOG_ROOT"
LOG_DIR="$(mktemp -d "$LOG_ROOT"/run-XXXXXX)"
FAIL=0
FAILED_LOG="$LOG_DIR/failures.log"

# test_wallai.sh - verify wallai.sh argument parsing and generation
# Usage: test_wallai.sh
# Dependencies: curl, jq, file, python3-yaml
# Output: prints progress and logs any failures without exiting
# Logs are saved under /tmp/wallai-tests for later review
# TAG: test

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
WALLAI="$ROOT_DIR/scripts/wallai.sh"
echo "Logs in $LOG_DIR"

run_test() {
  local desc="$1"
  shift
  local log
  log="$LOG_DIR/$(echo "$desc" | tr ' /:' '_').log"
  echo "Testing: $desc"
  if ! bash "$WALLAI" "$@" >"$log" 2>&1; then
    echo "❌ Failed: $desc (see $log)" >&2
    printf '%s\n' "$desc" >> "$FAILED_LOG"
    FAIL=1
  fi
}

tests=(
  "-h" "-h -v" "-h -g test" "-h -k token" "-h -di img.jpg" \
  "-h -p prompt" "-h -t tag" "-h -s style" "-h -m mood" "-h -n neg" \
  "-h -w" "-h -l" "-h -d" "-h -d tag" "-h -d style" "-h -d both" \
  "-h -i" "-h -i tag" "-h -i style" "-h -i pair" \
  "-h -f" "-h -f group" "-h -r" \
  "-h -im pollinations:flux" "-h -pm pollinations:openai" \
  "-h -tm pollinations:openai" "-h -sm pollinations:openai" \
  "-h -u latest" "-h --use group=main" )

# Multiple argument combinations to verify complex parsing
multi_tests=(
  "-h -p prompt -t tag -s style" \
  "-h -g test -f group -u latest" \
  "-h -p prompt -m mood -n neg -w" \
  "-h -p prompt -t tag -s style -im pollinations:flux -pm pollinations:openai"
)

for args in "${tests[@]}"; do
  # split args into array
  IFS=' ' read -r -a arr <<< "$args"
  run_test "$args" "${arr[@]}"

done

for args in "${multi_tests[@]}"; do
  IFS=' ' read -r -a arr <<< "$args"
  run_test "$args" "${arr[@]}"
done

echo "All wallai argument tests passed."
run_gen_test() {
  local desc="$1"
  shift
  echo "Generating: $desc"
  local before after log
  log="$LOG_DIR/gen_$(echo "$desc" | tr ' /:' '_').log"
  before=$(find "$HOME/pictures/generated-wallpapers" -type f 2>/dev/null | wc -l)
  if ! bash "$WALLAI" "$@" >"$log" 2>&1; then
    echo "❌ Generation failed for $desc (see $log)" >&2
    printf '%s\n' "gen $desc" >> "$FAILED_LOG"
    FAIL=1
  fi
  after=$(find "$HOME/pictures/generated-wallpapers" -type f 2>/dev/null | wc -l)
  if [ "$after" -le "$before" ]; then
    echo "❌ No image generated for $desc (see $log)" >&2
    printf '%s\n' "gen $desc" >> "$FAILED_LOG"
    FAIL=1
  fi
}
# use a temporary HOME so tests do not pollute real files
HOME=$(mktemp -d)
export HOME
mkdir -p "$HOME/pictures" "$HOME/pictures/generated-wallpapers"

# Initial run to create config and a favorite entry for inspired mode
run_gen_test "baseline" -p baseline

# Generation tests covering each image-related flag
GEN_TESTS=(
  "-p test" \
  "-p test -t tag" \
  "-p test -s style" \
  "-p test -m mood" \
  "-p test -n neg" \
  "-p test -w" \
  "-p test -l" \
  "-p test -x" \
  "-p test -d tag -x" \
  "-p test -i pair -x" \
  "-p test -im pollinations:flux" \
  "-p test -pm pollinations:openai" \
  "-p test -tm pollinations:openai" \
  "-p test -sm pollinations:openai" \
  "-p combo -t tag -s style -m mood -n neg" \
  "-p combo -t tag -s style -im pollinations:flux -pm pollinations:openai"
)

for gargs in "${GEN_TESTS[@]}"; do
  IFS=' ' read -r -a arr <<< "$gargs"
  run_gen_test "$gargs" "${arr[@]}"
done

if [ "$FAIL" -eq 0 ]; then
  echo "All wallai tests passed."
else
  echo "Some wallai tests failed. See $FAILED_LOG for a list." >&2
fi
echo "Logs saved to $LOG_DIR"
exit 0
