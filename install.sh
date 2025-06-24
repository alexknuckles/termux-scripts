#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SCRIPTS_DIR="$SCRIPT_DIR/scripts"
ALIASES_FILE="$SCRIPT_DIR/aliases/.aliases"

copy=0
while getopts ":c" opt; do
  case "$opt" in
    c)
      copy=1
      ;;
    *)
      echo "Usage: install.sh [-c]" >&2
      exit 1
      ;;
  esac
done
shift $((OPTIND - 1))

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

TARGET_BIN="$PREFIX/bin"
if [ "$copy" -eq 1 ]; then
  TARGET_BIN="$HOME/bin"
  mkdir -p "$TARGET_BIN"
  cp -f "$SCRIPTS_DIR/wallai.sh" "$TARGET_BIN/wallai"
  cp -f "$SCRIPTS_DIR/githelper.sh" "$TARGET_BIN/githelper"
else
  ln -sf "$SCRIPTS_DIR/wallai.sh" "$TARGET_BIN/wallai"
  ln -sf "$SCRIPTS_DIR/githelper.sh" "$TARGET_BIN/githelper"
fi

if [ -f "$ALIASES_FILE" ]; then
  if [ "$copy" -eq 1 ]; then
    cp -f "$ALIASES_FILE" "$HOME/.aliases"
  else
    ln -sf "$ALIASES_FILE" "$HOME/.aliases"
  fi
fi

if [ -d "$SCRIPT_DIR/shortcuts" ]; then
  mkdir -p "$HOME/.shortcuts"
  for sc in "$SCRIPT_DIR"/shortcuts/*.sh; do
    [ -f "$sc" ] || continue
    if [ "$copy" -eq 1 ]; then
      cp -f "$sc" "$HOME/.shortcuts/$(basename "$sc")"
    else
      ln -sf "$sc" "$HOME/.shortcuts/$(basename "$sc")"
    fi
  done
fi

echo "Installed wallai to $TARGET_BIN/wallai"
echo "Installed githelper to $TARGET_BIN/githelper"
