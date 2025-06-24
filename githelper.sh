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
  local project_name
  project_name=$(basename "$dir")
  local readme
  readme=$(curl -sL "https://text.pollinations.ai/Imagine+a+short+README+for+$project_name+project+in+markdown" || true)
  if [ -z "$readme" ]; then
    readme="# $project_name"
  fi
  printf '%s\n' "$readme" > README.md
  local agents
  agents=$(curl -sL "https://text.pollinations.ai/Imagine+a+short+AGENTS.md+spec+for+$project_name" || true)
  if [ -n "$agents" ]; then
    printf '%s\n' "$agents" > agents.md
  fi
  git add README.md agents.md 2>/dev/null || git add README.md
  git commit -m "Add AI-generated README and agents"
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
