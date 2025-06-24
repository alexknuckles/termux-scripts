#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

# githelper.sh - simple helper for common git tasks
#
# Usage: githelper.sh <command> [args]
# Commands:
#   pull-all               Update all git repositories under $GIT_ROOT (default ~/git)
#   status                 Show git status of current repository
#   push                   Push current branch to origin
#   clone <url> [dest]     Clone repository (uses gh if available)
#   init                   Initialize repo in current directory with first commit
#   revert-last            Revert the most recent commit in current repository
#   clone-mine [user]      Clone all repositories from GitHub user (requires gh)
#
# Dependencies: git, optional gh
# Output: command specific
# TAG: git

GIT_ROOT="${GIT_ROOT:-$HOME/git}"

pull_all() {
  local repo
  for repo in "$GIT_ROOT"/*/.git; do
    repo="${repo%/\.git}"
    [ -d "$repo" ] || continue
    echo "\u279c Updating $repo"
    if git -C "$repo" pull --ff-only; then
      echo "\u2705 Updated $repo"
    else
      echo "\u274c Failed to update $repo" >&2
    fi
  done
}

status_repo() {
  git status --short
}

push_repo() {
  git push
}

clone_repo() {
  local url="$1"
  local dest="${2:-}"
  if command -v gh >/dev/null 2>&1; then
    gh repo clone "$url" "$dest"
  else
    git clone "$url" "$dest"
  fi
}

init_here() {
  if [ -d .git ]; then
    echo "Repository already initialized" >&2
    return
  fi
  git init
  git add -A
  git commit -m "Initial commit"
}

revert_last() {
  git revert --no-edit HEAD
}

clone_mine() {
  if ! command -v gh >/dev/null 2>&1; then
    echo "gh is required for clone-mine" >&2
    exit 1
  fi
  local user="${1:-$(gh api user --jq .login)}"
  mkdir -p "$GIT_ROOT"
  gh repo list "$user" --limit 1000 --json sshUrl,name \
    | jq -r '.[] | "\(.sshUrl) \(.name)"' \
    | while read -r url name; do
        if [ -d "$GIT_ROOT/$name/.git" ]; then
          echo "✔ $name already exists"
        else
          echo "➕ Cloning $name"
          clone_repo "$url" "$GIT_ROOT/$name"
        fi
      done
}

new_repo() {
  local dir="$1"
  if [ -z "$dir" ]; then
    echo "Usage: githelper.sh newrepo <directory>" >&2
    return 1
  fi

  mkdir -p "$dir"
  cd "$dir"
  git init
  git add -A
  git commit -m "Initial commit"

  local project_name
  project_name=$(basename "$dir")
  if command -v gh >/dev/null 2>&1; then
    gh repo create "$project_name" --source=. --public --remote=origin --push || true
  fi

  local file_list
  file_list=$(find . -type f ! -path '*/.*' \
    ! -iname '*.png' ! -iname '*.jpg' ! -iname '*.jpeg' ! -iname '*.gif' \
    ! -iname '*.bmp' ! -iname '*.svg' ! -iname '*.webp' ! -iname '*.ico' \
    -print0 | xargs -0 grep -Il '' | sed 's|^./||' | tr '\n' ' ')
  file_list=$(printf '%s' "$file_list" | sed 's/  */ /g; s/ $//')

  local prompt encoded readme agents
  prompt="Create a professional README.md for a software project that includes: $file_list. Include a project description, features, and usage."
  encoded=$(printf '%s' "$prompt" | jq -sRr @uri)
  readme=$(curl -sL "https://text.pollinations.ai/prompt/${encoded}" | jq -r '.completion' || true)
  [ -n "$readme" ] || readme="# $project_name"
  printf '%s\n' "$readme" > README.md

  prompt="Create an agents.md file for a project with these files: $file_list. Define Docs agent, Code agent, Build agent, and Test agent. List their roles and goals."
  encoded=$(printf '%s' "$prompt" | jq -sRr @uri)
  agents=$(curl -sL "https://text.pollinations.ai/prompt/${encoded}" | jq -r '.completion' || true)
  [ -n "$agents" ] && printf '%s\n' "$agents" > agents.md

  local author year
  author=$(git config user.name)
  year=$(date +%Y)
  cat > LICENSE <<EOF
GPL-3.0 License

Copyright (C) $year $author

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <https://www.gnu.org/licenses/gpl-3.0.html>.
EOF

  git add README.md agents.md LICENSE 2>/dev/null || git add README.md LICENSE
  git commit -m "Add generated README, agents, and license"
  if git remote | grep -q origin; then
    git push -u origin main || git push -u origin master
  fi
}

cmd="${1:-}"
case "$cmd" in
  pull-all)
    pull_all
    ;;
  status)
    status_repo
    ;;
  push)
    push_repo
    ;;
  clone)
    shift
    if [ "$#" -lt 1 ]; then
      echo "Usage: githelper.sh clone <url> [dest]" >&2
      exit 1
    fi
    clone_repo "$@"
    ;;
  init)
    init_here
    ;;
  revert-last)
    revert_last
    ;;
  clone-mine)
    shift
    clone_mine "$@"
    ;;
  newrepo)
    shift
    new_repo "$@"
    ;;
  *)
    echo "Usage: githelper.sh <pull-all|status|push|clone|init|revert-last|clone-mine|newrepo>" >&2
    exit 1
    ;;
esac
