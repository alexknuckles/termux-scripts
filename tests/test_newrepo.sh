#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

# Basic test for githelper newrepo
# Ensures an initial commit is created even when directory is empty

tmpdir=$(mktemp -d)
mkdir -p "$tmpdir/bin"

cat >"$tmpdir/bin/curl" <<'STUB'
#!/bin/sh
echo '{"completion":"stub"}'
STUB
chmod +x "$tmpdir/bin/curl"

PATH="$tmpdir/bin:$PATH" bash scripts/githelper.sh newrepo -d "$tmpdir/repo" -m "Test repo" -n

if git -C "$tmpdir/repo" rev-parse --verify HEAD >/dev/null 2>&1; then
  echo "PASS: initial commit created"
else
  echo "FAIL: no commit" >&2
  exit 1
fi

rm -rf "$tmpdir"
