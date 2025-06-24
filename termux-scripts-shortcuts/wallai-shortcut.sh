#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

# wallai-shortcut.sh - simple wrapper to launch wallai
# TAG: shortcut

exec "$HOME/bin/termux-scripts/wallai" "$@"
