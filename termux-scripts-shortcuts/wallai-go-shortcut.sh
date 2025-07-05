#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

# wallai-go-shortcut.sh - launch the Go version of wallai
# TAG: shortcut

exec "$HOME/bin/termux-scripts/wallai-go" "$@"
