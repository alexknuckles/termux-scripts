#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PREFIX_BIN="$PREFIX/bin"

install -Dm755 "$SCRIPT_DIR/wallai.sh" "$PREFIX_BIN/wallai"
install -Dm755 "$SCRIPT_DIR/githelper.sh" "$PREFIX_BIN/githelper"

if [ -f "$SCRIPT_DIR/.aliases" ]; then
  install -Dm644 "$SCRIPT_DIR/.aliases" "$PREFIX/bin/.aliases"
fi

if [ -f "$SCRIPT_DIR/aliases/aliases" ]; then
  install -Dm644 "$SCRIPT_DIR/aliases/aliases" "$PREFIX/bin/aliases"
fi

if [ -d "$SCRIPT_DIR/shortcuts" ]; then
  mkdir -p "$HOME/shortcuts"
  for sc in "$SCRIPT_DIR"/shortcuts/*.sh; do
    [ -f "$sc" ] || continue
    install -Dm755 "$sc" "$HOME/shortcuts/$(basename "$sc")"
  done
fi

echo "Installed wallai to $PREFIX_BIN/wallai"
echo "Installed githelper to $PREFIX_BIN/githelper"
