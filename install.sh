#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PREFIX_BIN="$PREFIX/bin"

install -Dm755 "$SCRIPT_DIR/wallai.sh" "$PREFIX_BIN/wallai"

if [ -f "$SCRIPT_DIR/.aliases" ]; then
  install -Dm644 "$SCRIPT_DIR/.aliases" "$PREFIX/bin/.aliases"
fi

echo "Installed wallai to $PREFIX_BIN/wallai"
