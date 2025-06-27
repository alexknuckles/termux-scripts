#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

# walfave-group-shortcut.sh - choose a favorites group and archive the current wallpaper
# TAG: shortcut

config_file="$HOME/.wallai/config.yml"

# Default to main if config missing
if [ -f "$config_file" ]; then
  mapfile -t groups < <(CFG="$config_file" python3 - <<'PY'
import os, yaml
with open(os.environ['CFG']) as f:
    data = yaml.safe_load(f) or {}
print('\n'.join((data.get('groups') or {}).keys()))
PY
  )
else
  groups=(main)
fi

[ "${#groups[@]}" -gt 0 ] || groups=(main)
list=$(IFS=','; printf '%s' "${groups[*]}")

if ! command -v termux-dialog >/dev/null 2>&1; then
  echo "termux-dialog is required" >&2
  exit 1
fi

result=$(termux-dialog -l "$list" -t "Select favorites group" || true)
selection=$(printf '%s' "$result" | jq -r '.text')

[ -n "$selection" ] || exit 0

exec "$HOME/bin/termux-scripts/wallai" -f "$selection" "$@"
