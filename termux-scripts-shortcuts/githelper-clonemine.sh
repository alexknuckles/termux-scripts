#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

# githelper-clonemine.sh - run githelper clone-mine
# TAG: shortcut

exec "$HOME/bin/termux-scripts/githelper" clone-mine "$@"
