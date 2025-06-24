#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

# githelper-pullall.sh - run githelper pull-all
# TAG: shortcut

exec "$HOME/bin/termux-scripts/githelper" pull-all "$@"
