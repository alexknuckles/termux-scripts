#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

# githelper-setnextall.sh - run githelper set-next-all
# TAG: shortcut

exec githelper set-next-all -t testing "$@"
