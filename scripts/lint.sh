#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Run shellcheck on all scripts and shortcuts
shellcheck "$SCRIPT_DIR"/*.sh "$ROOT_DIR"/termux-scripts-shortcuts/*.sh
