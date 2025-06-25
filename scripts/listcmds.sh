#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

# listcmds.sh - display available Termux Scripts aliases, commands and functions
#
# Usage: listcmds.sh
# Dependencies: none
# Output: prints lists of aliases, scripts and githelper functions
# TAG: utility

script_dir="$(cd "$(dirname "$0")" && pwd)"
# Prefer installed alias file, fall back to repo copy
alias_file="$HOME/.aliases.d/termux-scripts.aliases"
[ -f "$alias_file" ] || alias_file="$script_dir/../aliases/termux-scripts.aliases"

echo "== Aliases =="
grep '^alias ' "$alias_file" | cut -d '=' -f1 | sed 's/^alias //' | sort

echo
"== Commands =="
for f in "$script_dir"/*.sh; do
  [ -f "$f" ] || continue
  basename "${f%.sh}"
done | sort

echo
"== githelper functions =="
if [ -f "$script_dir/githelper.sh" ]; then
  grep -E '^[a-zA-Z_][a-zA-Z0-9_]*\(\)' "$script_dir/githelper.sh" \
    | awk -F '(' '{print $1}' \
    | grep -v '^_' \
    | sort -u
fi
