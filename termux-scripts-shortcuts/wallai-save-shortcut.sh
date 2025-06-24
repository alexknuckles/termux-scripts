#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

# wallai-save-shortcut.sh - archive the latest generated wallpaper
# TAG: shortcut

exec "$HOME/bin/termux-scripts/walsave" "$@"
