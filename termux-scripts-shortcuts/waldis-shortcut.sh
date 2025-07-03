#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

# waldis-shortcut.sh - generate a wallpaper using discovery mode
# TAG: shortcut

exec "$HOME/bin/termux-scripts/wallai" -d -x "$@"
