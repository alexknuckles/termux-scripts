#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SCRIPTS_DIR="$SCRIPT_DIR/scripts"
ALIASES_FILE="$SCRIPT_DIR/aliases/.aliases"

safe_copy() {
  local src="$1" dest="$2"
  if [ "$src" -ef "$dest" ]; then
    # Destination is a symlink or hard link to the source; replace it with
    # an independent copy so future edits don't modify the repo version.
    echo "Replacing symlinked $dest with a fresh copy of $src" >&2
    rm -f "$dest"
  fi
  if [ -f "$dest" ]; then
    mapfile -t extra < <(grep -Fvx -f "$src" "$dest" || true)
    if [ "${#extra[@]}" -gt 0 ]; then
      echo "Lines in $dest not present in $src:" >&2
      printf '  %s\n' "${extra[@]}" >&2
      read -r -p "Replace file or append these lines? [r/a] " ans
      if [[ $ans =~ ^[Aa]$ ]]; then
        cp -f "$src" "$dest"
        printf '%s\n' "${extra[@]}" >> "$dest"
        return
      fi
    fi
  fi
  cp -f "$src" "$dest"
}

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
  safe_copy "$SCRIPTS_DIR/wallai.sh" "$TARGET_BIN/wallai"
  safe_copy "$SCRIPTS_DIR/githelper.sh" "$TARGET_BIN/githelper"
else
  ln -sf "$SCRIPTS_DIR/wallai.sh" "$TARGET_BIN/wallai"
  ln -sf "$SCRIPTS_DIR/githelper.sh" "$TARGET_BIN/githelper"
fi

chmod 755 "$TARGET_BIN/wallai" "$TARGET_BIN/githelper"

if [ -f "$ALIASES_FILE" ]; then
  if [ "$copy" -eq 1 ]; then
    safe_copy "$ALIASES_FILE" "$HOME/.aliases"
  else
    ln -sf "$ALIASES_FILE" "$HOME/.aliases"
  fi
fi

if [ -d "$SCRIPT_DIR/shortcuts" ]; then
  mkdir -p "$HOME/.shortcuts"
  for sc in "$SCRIPT_DIR"/shortcuts/*.sh; do
    [ -f "$sc" ] || continue
    target="$HOME/.shortcuts/$(basename "$sc")"
    if [ "$copy" -eq 1 ]; then
      safe_copy "$sc" "$target"
    else
      ln -f "$sc" "$target"
    fi
    chmod 755 "$target"
  done
fi

echo "Installed wallai to $TARGET_BIN/wallai"
echo "Installed githelper to $TARGET_BIN/githelper"
