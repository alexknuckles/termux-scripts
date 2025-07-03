#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

# setup_refresh.sh - download resources needed for offline use
#
# Usage: setup_refresh.sh
# Dependencies: curl
# Output: saves files under static/cache for later use
# TAG: setup

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
RESOURCE_LIST="$ROOT_DIR/static/setup-resources.txt"
CACHE_DIR="$ROOT_DIR/static/cache"

mkdir -p "$CACHE_DIR"

if [ ! -f "$RESOURCE_LIST" ]; then
  echo "Resource list not found: $RESOURCE_LIST" >&2
  exit 1
fi

while IFS= read -r line || [ -n "$line" ]; do
  # skip blank lines and comments
  [ -z "$line" ] && continue
  case "$line" in
    \#*) continue ;;
  esac
  url="$(printf '%s' "$line" | awk '{print $1}')"
  dest="$(printf '%s' "$line" | awk '{print $2}')"
  if [ -z "$url" ] || [ -z "$dest" ]; then
    echo "Invalid entry in $RESOURCE_LIST: $line" >&2
    continue
  fi
  echo "Fetching $url -> $CACHE_DIR/$dest"
  if ! curl -fsSL "$url" -o "$CACHE_DIR/$dest"; then
    echo "Failed to download $url" >&2
  fi

done < "$RESOURCE_LIST"

printf '\nSaved resources to %s\n' "$CACHE_DIR"
