#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PREFIX_BIN="$PREFIX/bin"

# Check for required dependencies and offer to install them if missing
deps=(curl jq git termux-wallpaper)
missing=()
for dep in "${deps[@]}"; do
  if ! command -v "$dep" >/dev/null 2>&1; then
    missing+=("$dep")
  fi
done
if [ "${#missing[@]}" -gt 0 ]; then
  echo "The following packages are required: ${missing[*]}"
  read -r -p "Install them now with pkg? [y/N] " ans
  if [[ $ans =~ ^[Yy]$ ]]; then
    pkg install -y "${missing[@]}"
  fi
fi

ln -sf "$SCRIPT_DIR/wallai.sh" "$PREFIX_BIN/wallai"
ln -sf "$SCRIPT_DIR/githelper.sh" "$PREFIX_BIN/githelper"

if [ -f "$SCRIPT_DIR/.aliases" ]; then
  ln -sf "$SCRIPT_DIR/.aliases" "$HOME/.aliases"
fi

if [ -f "$SCRIPT_DIR/aliases/aliases" ]; then
  ln -sf "$SCRIPT_DIR/aliases/aliases" "$PREFIX/bin/aliases"
fi

if [ -d "$SCRIPT_DIR/shortcuts" ]; then
  mkdir -p "$HOME/.shortcuts"
  for sc in "$SCRIPT_DIR"/shortcuts/*.sh; do
    [ -f "$sc" ] || continue
    ln -sf "$sc" "$HOME/.shortcuts/$(basename "$sc")"
  done
fi

echo "Symlinked wallai to $PREFIX_BIN/wallai"
echo "Symlinked githelper to $PREFIX_BIN/githelper"
