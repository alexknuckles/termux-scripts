#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

# installer.sh - install or remove Termux Scripts
#
# Usage: installer.sh [-r] [-g] [-u]
#   -r  Install latest release from GitHub instead of local files
#   -g  After installing, clone the repository to ~/git/termux-scripts
#   -u  Uninstall all files installed by a previous run

ROOT_DIR="$(cd "$(dirname "$0")"/.. && pwd)"
SCRIPTS_DIR="$ROOT_DIR/scripts"
ALIASES_FILE="$ROOT_DIR/aliases/termux-scripts.aliases"
SHORTCUTS_DIR="$ROOT_DIR/termux-scripts-shortcuts"
REPO_URL="https://github.com/alexknuckles/termux-scripts"
VERSION="0.4"
INSTALL_DIR="$HOME/bin/termux-scripts"
VERSION_FILE="$INSTALL_DIR/.version"

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

remote=0
clone_repo=0
uninstall=0
while getopts ":rgu" opt; do
  case "$opt" in
    r)
      remote=1
      ;;
    g)
      clone_repo=1
      ;;
    u)
      uninstall=1
      ;;
    *)
      echo "Usage: $(basename "$0") [-r] [-g] [-u]" >&2
      exit 1
      ;;
  esac
done
shift $((OPTIND - 1))

if [ "$uninstall" -eq 1 ]; then
  rm -f "$PREFIX/bin/wallai" "$PREFIX/bin/githelper" \
        "$HOME/bin/wallai" "$HOME/bin/githelper"
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
  rm -rf "$HOME/git/termux-scripts"
  echo "Uninstallation complete"
  exec bash
fi

if [ "$clone_repo" -eq 1 ]; then
  mkdir -p "$HOME/git"
  if [ -d "$HOME/git/termux-scripts/.git" ]; then
    git -C "$HOME/git/termux-scripts" pull --ff-only || true
  else
    git clone "$REPO_URL" "$HOME/git/termux-scripts"
  fi
  ROOT_DIR="$HOME/git/termux-scripts"
  SCRIPTS_DIR="$ROOT_DIR/scripts"
  ALIASES_FILE="$ROOT_DIR/aliases/termux-scripts.aliases"
  SHORTCUTS_DIR="$ROOT_DIR/termux-scripts-shortcuts"
elif [ "$remote" -eq 1 ]; then
  tag=$(curl -sL "https://api.github.com/repos/alexknuckles/termux-scripts/releases/latest" | jq -r .tag_name)
  [ -n "$tag" ] || tag=main
  tmpdir=$(mktemp -d)
  curl -sL "$REPO_URL/archive/$tag.tar.gz" | tar -xz --strip-components=1 -C "$tmpdir"
  ROOT_DIR="$tmpdir"
  SCRIPTS_DIR="$ROOT_DIR/scripts"
  ALIASES_FILE="$ROOT_DIR/aliases/termux-scripts.aliases"
  SHORTCUTS_DIR="$ROOT_DIR/termux-scripts-shortcuts"
fi

if [ "$remote" -eq 0 ] && [ "$clone_repo" -eq 0 ] && \
   [ -f "$VERSION_FILE" ] && [ "$(cat "$VERSION_FILE")" = "$VERSION" ]; then
  echo "Termux scripts version $VERSION already installed"
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
safe_copy "$SCRIPTS_DIR/wallai.sh" "$TARGET_BIN/wallai"
safe_copy "$SCRIPTS_DIR/walsave.sh" "$TARGET_BIN/walsave"
safe_copy "$SCRIPTS_DIR/githelper.sh" "$TARGET_BIN/githelper"

chmod 755 "$TARGET_BIN/wallai" "$TARGET_BIN/walsave" "$TARGET_BIN/githelper"

if [ -f "$ALIASES_FILE" ]; then
  dest_dir="$HOME/.aliases.d"
  mkdir -p "$dest_dir"
  alias_target="$dest_dir/$(basename "$ALIASES_FILE")"
  safe_copy "$ALIASES_FILE" "$alias_target"

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
  . "$alias_target"
fi

bash_rc="$HOME/.bashrc"
if [ ! -f "$bash_rc" ]; then
  touch "$bash_rc"
fi
if ! grep -Fq "$HOME/bin/termux-scripts" "$bash_rc"; then
  echo "export PATH=\"$INSTALL_DIR:\$PATH\"" >> "$bash_rc"
  # Apply changes to current session
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
    safe_copy "$sc" "$target"
    chmod 755 "$target"
  done
fi

echo "Installed wallai to $TARGET_BIN/wallai"
echo "Installed walsave to $TARGET_BIN/walsave"
echo "Installed githelper to $TARGET_BIN/githelper"
echo "$VERSION" > "$VERSION_FILE"

if [ "$clone_repo" -eq 1 ]; then
  echo "Repository cloned to $HOME/git/termux-scripts"
fi
