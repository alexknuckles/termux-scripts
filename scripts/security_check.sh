#!/usr/bin/env bash
set -euo pipefail

# security_check.sh - scan scripts for risky commands
#
# Usage: security_check.sh
# Dependencies: grep
# Output: lists any lines with potentially dangerous commands
# TAG: security

patterns='\brm -rf\b|\bdd if=\b|\bmv .* /'

found=0
for file in scripts/*.sh termux-scripts-shortcuts/*.sh; do
  while IFS= read -r line; do
    if printf '%s\n' "$line" | grep -Eq "$patterns"; then
      echo "${file}: $line"
      found=1
    fi
  done <"$file"
done

if [ "$found" -eq 0 ]; then
  echo "No risky patterns found"
fi
