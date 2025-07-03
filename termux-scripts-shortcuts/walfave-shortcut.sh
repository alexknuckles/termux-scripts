#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

# walfave-shortcut.sh - archive the latest generated wallpaper
# TAG: shortcut

"$HOME/bin/termux-scripts/wallai" -f "$@" || true
exit 0
