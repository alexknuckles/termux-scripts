#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

# test_wallai.sh - verify wallai.sh argument parsing and generation
# Usage: test_wallai.sh
# Dependencies: curl, jq, file, python3-yaml
# Output: prints progress and exits with non-zero on failure
# TAG: test

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
WALLAI="$ROOT_DIR/scripts/wallai.sh"

run_test() {
  local desc="$1"
  shift
  echo "Testing: $desc"
  bash "$WALLAI" "$@" >/dev/null
}

tests=(
  "-h" "-h -v" "-h -g test" "-h -k token" "-h --describe-image img.jpg" \
  "-h -p prompt" "-h -t tag" "-h -s style" "-h -m mood" "-h -n neg" \
  "-h -w" "-h -l" "-h -d" "-h -d tag" "-h -d style" "-h -d both" \
  "-h -i" "-h -i tag" "-h -i style" "-h -i pair" \
  "-h -f" "-h -f group" "-h -r" \
  "-h -im pollinations:flux" "-h -pm pollinations:openai" \
  "-h -tm pollinations:openai" "-h -sm pollinations:openai" \
  "-h -u latest" "-h --use group=main" )

for args in "${tests[@]}"; do
  # split args into array
  IFS=' ' read -r -a arr <<< "$args"
  run_test "$args" "${arr[@]}"

done

echo "All wallai argument tests passed."
run_gen_test() {
  local desc="$1"
  shift
  echo "Generating: $desc"
  local before after
  before=$(find "$HOME/pictures/generated-wallpapers" -type f 2>/dev/null | wc -l)
  bash "$WALLAI" "$@" >/dev/null
  after=$(find "$HOME/pictures/generated-wallpapers" -type f 2>/dev/null | wc -l)
  if [ "$after" -le "$before" ]; then
    echo "❌ No image generated for $desc" >&2
    exit 1
  fi
}
# use a temporary HOME so tests do not pollute real files
export HOME=$(mktemp -d)
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
  "-p test -sm pollinations:openai"
)

for gargs in "${GEN_TESTS[@]}"; do
  IFS=' ' read -r -a arr <<< "$gargs"
  run_gen_test "$gargs" "${arr[@]}"
done

echo "All wallai generation tests passed."
