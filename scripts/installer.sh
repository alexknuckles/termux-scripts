#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

# installer.sh - install or remove Termux Scripts
#
# Usage: installer.sh [-r] [-u]
#   -r  Install latest release from GitHub instead of local files
#   -u  Uninstall all files installed by a previous run

ROOT_DIR="$(cd "$(dirname "$0")"/.. && pwd)"
SCRIPTS_DIR="$ROOT_DIR/scripts"
ALIASES_FILE="$ROOT_DIR/aliases/termux-scripts.aliases"
SHORTCUTS_DIR="$ROOT_DIR/termux-scripts-shortcuts"
REPO_URL="https://github.com/alexknuckles/termux-scripts"
DEFAULT_VERSION="0.4"
VERSION="$DEFAULT_VERSION"
INSTALL_DIR="$HOME/bin/termux-scripts"
VERSION_FILE="$INSTALL_DIR/.version"

copy_newer() {
  local src="$1" dest="$2"
  if [ -e "$dest" ] && [ "$src" -ef "$dest" ]; then
    echo "Replacing link $dest with new copy of $src" >&2
    rm -f "$dest"
  fi
  if [ ! -e "$dest" ] || [ "$src" -nt "$dest" ]; then
    cp -f "$src" "$dest"
    echo "Copied $src -> $dest" >&2
  else
    echo "$dest is up to date" >&2
  fi
}

remote=0
uninstall=0
while getopts ":ru" opt; do
  case "$opt" in
    r)
      remote=1
      ;;
    u)
      uninstall=1
      ;;
    *)
      echo "Usage: $(basename "$0") [-r] [-u]" >&2
      exit 1
      ;;
  esac
done
shift $((OPTIND - 1))

if [ "$uninstall" -eq 1 ]; then
  rm -rf "$INSTALL_DIR"
  rm -f "$VERSION_FILE"
  rm -f "$HOME/.aliases.d/$(basename "$ALIASES_FILE")"
  for rc in "$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.profile"; do
    if [ -f "$rc" ]; then
      # shellcheck disable=SC2016
      sed -i '/if \[ -d "\$HOME\/\.aliases\.d" \]; then/,/fi/d' "$rc"
    fi
  done
  rm -rf "$HOME/.shortcuts/termux-scripts"
  echo "Uninstallation complete"
  exec bash
fi

if [ "$remote" -eq 1 ]; then
  tag=$(curl -sL "https://api.github.com/repos/alexknuckles/termux-scripts/releases/latest" | jq -r .tag_name)
  [ -n "$tag" ] || tag=main
  tmpdir=$(mktemp -d)
  curl -sL "$REPO_URL/archive/$tag.tar.gz" | tar -xz --strip-components=1 -C "$tmpdir"
  ROOT_DIR="$tmpdir"
  SCRIPTS_DIR="$ROOT_DIR/scripts"
  ALIASES_FILE="$ROOT_DIR/aliases/termux-scripts.aliases"
  SHORTCUTS_DIR="$ROOT_DIR/termux-scripts-shortcuts"
fi

# Use git commit hash as the version when available so pulling new commits
# triggers an update even without a new release
if [ -d "$ROOT_DIR/.git" ]; then
  VERSION=$(git -C "$ROOT_DIR" rev-parse --short HEAD)
fi

if [ "$remote" -eq 0 ] && \
   [ -f "$VERSION_FILE" ] && [ "$(cat "$VERSION_FILE")" = "$VERSION" ]; then
  echo "Termux scripts already installed"
  exit 0
fi

# Check for required dependencies and offer to install them if missing
deps=(curl jq git termux-wallpaper exiftool)
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

TARGET_BIN="$INSTALL_DIR"
mkdir -p "$TARGET_BIN"
for script in "$SCRIPTS_DIR"/*.sh; do
  [ -f "$script" ] || continue
  name="$(basename "$script" .sh)"
  dest="$TARGET_BIN/$name"
  copy_newer "$script" "$dest"
  chmod 755 "$dest"
done

if [ -f "$ALIASES_FILE" ]; then
  dest_dir="$HOME/.aliases.d"
  mkdir -p "$dest_dir"
  alias_target="$dest_dir/$(basename "$ALIASES_FILE")"
  copy_newer "$ALIASES_FILE" "$alias_target"

  shell_rc=""
  for rc in "$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.profile"; do
    if [ -f "$rc" ]; then
      shell_rc="$rc"
      break
    fi
  done
  if [ -n "$shell_rc" ] && ! grep -Fq '.aliases.d/' "$shell_rc"; then
    cat >>"$shell_rc" <<'EOF'
if [ -d "$HOME/.aliases.d" ]; then
  for f in "$HOME"/.aliases.d/*.aliases; do
    [ -r "$f" ] && . "$f"
  done
fi
EOF
  fi
  # Load aliases for this session
  # shellcheck source=/dev/null
  . "$alias_target"
fi

bash_rc="$HOME/.bashrc"
if [ ! -f "$bash_rc" ]; then
  touch "$bash_rc"
fi
if ! grep -Fq "$HOME/bin/termux-scripts" "$bash_rc"; then
  echo "export PATH=\"$INSTALL_DIR:\$PATH\"" >> "$bash_rc"
  # Apply changes to current session
  # shellcheck source=/dev/null
  . "$bash_rc"
fi

# Make new commands available immediately
export PATH="$INSTALL_DIR:$PATH"

if [ -d "$SHORTCUTS_DIR" ]; then
  dest="$HOME/.shortcuts/termux-scripts"
  mkdir -p "$dest"
  for sc in "$SHORTCUTS_DIR"/*.sh; do
    [ -f "$sc" ] || continue
    target="$dest/$(basename "$sc")"
    copy_newer "$sc" "$target"
    chmod 755 "$target"
  done
fi

echo "Scripts installed to $TARGET_BIN"
echo "$VERSION" > "$VERSION_FILE"
