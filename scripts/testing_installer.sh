#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

# testing_installer.sh - always install the latest bleeding-edge scripts
# Usage: testing_installer.sh [installer options]
# Dependencies: git, curl, jq
# Copies all shortcuts, aliases and scripts, replacing older versions when newer ones are available.
# TAG: installer

REPO_URL="https://github.com/alexknuckles/termux-scripts"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

# Clone the repo and execute the included installer with passed arguments
git clone "$REPO_URL" "$TMP_DIR"
exec "$TMP_DIR/scripts/installer.sh" "$@"
