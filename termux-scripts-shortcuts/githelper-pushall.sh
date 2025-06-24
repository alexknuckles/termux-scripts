#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

# githelper-pushall.sh - run githelper push-all
# TAG: shortcut

exec "$HOME/bin/termux-scripts/githelper" push-all "$@"
