#!/usr/bin/env bash
set -euo pipefail

# lint.sh - run ShellCheck across the project
#
# Usage: lint.sh
# Dependencies: shellcheck
# Output: prints any warnings detected by ShellCheck
# TAG: utility

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

if ! command -v shellcheck >/dev/null 2>&1; then
  echo "shellcheck is required" >&2
  exit 1
fi

# Run shellcheck on all scripts and shortcuts
shellcheck "$SCRIPT_DIR"/*.sh "$ROOT_DIR"/termux-scripts-shortcuts/*.sh
