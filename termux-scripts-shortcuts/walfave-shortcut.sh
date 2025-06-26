#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

# walfave-shortcut.sh - archive the latest generated wallpaper
# TAG: shortcut

exec "$HOME/bin/termux-scripts/wallai" -f "$@"
