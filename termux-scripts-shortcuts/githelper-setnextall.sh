#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

# githelper-setnextall.sh - run githelper set-next-all
# TAG: shortcut

exec "$HOME/bin/termux-scripts/githelper" set-next-all "$@"
