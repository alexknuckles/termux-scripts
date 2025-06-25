#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

# githelper.sh - simple helper for common git tasks
#
# Usage: githelper.sh <command> [args]
# Commands:
#   pull-all               Update all git repositories under $GIT_ROOT (default ~/git)
#   status                 Show git status of current repository
#   pull                   Pull latest changes for current repository
#   push                   Push current branch to origin
#   push-all [-c]          Push all repos under $GIT_ROOT to their main branches
#   clone -u url [-d dest] Clone repository (uses gh if available)
#   init                   Initialize repo in current directory with first commit
#   revert-last            Revert the most recent commit in current repository
#   clone-mine [-u user]   Clone all repositories from GitHub user (requires gh)
#   newrepo [-d dir] [-n] [-m description]  Create repo with AI-generated README and agents
#   set-next [-r]       Create the next release tag (default prerelease 'testing')
#   set-next-all [-r]   Run set-next for every repo under $GIT_ROOT
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

pull_repo() {
  git pull --ff-only
}

push_repo() {
  git add .
  if ! git diff --cached --quiet; then
    git commit -m "gpush-ed"
  fi
  git push origin main
}

push_all() {
  local repo
  for repo in "$GIT_ROOT"/*/.git; do
    repo="${repo%/\.git}"
    [ -d "$repo" ] || continue
    echo "\u279c Pushing $repo"
    git -C "$repo" add .
    if ! git -C "$repo" diff --cached --quiet; then
      git -C "$repo" commit -m "gpush-ed"
    fi
    if git -C "$repo" push origin main; then
      echo "\u2705 Pushed $repo"
    else
      echo "\u274c Failed to push $repo" >&2
    fi
  done
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

clone_cmd() {
  local url="" dest=""
  local OPTIND=1 opt
  while getopts ":u:d:" opt; do
    case "$opt" in
      u)
        url="$OPTARG"
        ;;
      d)
        dest="$OPTARG"
        ;;
      *)
        echo "Usage: githelper.sh clone -u url [-d dest]" >&2
        return 1
        ;;
    esac
  done
  shift $((OPTIND - 1))
  if [ -z "$url" ]; then
    echo "Usage: githelper.sh clone -u url [-d dest]" >&2
    return 1
  fi
  clone_repo "$url" "$dest"
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
  if ! gh auth status >/dev/null 2>&1; then
    echo "No GitHub authentication found. Launching gh auth login..." >&2
    gh auth login
  fi

  local user=""
  local OPTIND=1 opt
  while getopts ":u:" opt; do
    case "$opt" in
      u)
        user="$OPTARG"
        ;;
      *)
        echo "Usage: githelper.sh clone-mine [-u user]" >&2
        return 1
        ;;
    esac
  done
  shift $((OPTIND - 1))

  user="${user:-$(gh api user --jq .login)}"
  if [ -z "$user" ]; then
    echo "Unable to determine GitHub user" >&2
    return 1
  fi

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
  local dir="."
  local scan=1
  local desc=""
  local OPTIND=1 opt
  while getopts ":d:m:n" opt; do
    case "$opt" in
      d)
        dir="$OPTARG"
        ;;
      m)
        desc="$OPTARG"
        ;;
      n)
        scan=0
        ;;
      *)
        echo "Usage: githelper newrepo [-d dir] [-n] [-m description]" >&2
        return 1
        ;;
    esac
  done
  shift $((OPTIND - 1))

  mkdir -p "$dir"
  cd "$dir"
  git init
  git add -A
  if git diff --cached --quiet 2>/dev/null; then
    git commit --allow-empty -m "Initial commit"
  else
    git commit -m "Initial commit"
  fi

  local project_name
  project_name=$(basename "$dir")
  if command -v gh >/dev/null 2>&1; then
    gh repo create "$project_name" --source=. --public --remote=origin --push || true
  fi

  local file_list="" prompt encoded readme agents
  if [ "$scan" -eq 1 ] || [ -z "$desc" ]; then
    file_list=$(find . -type f ! -path '*/.*' \
      ! -iname '*.png' ! -iname '*.jpg' ! -iname '*.jpeg' ! -iname '*.gif' \
      ! -iname '*.bmp' ! -iname '*.svg' ! -iname '*.webp' ! -iname '*.ico' \
      -print0 | xargs -0 grep -Il '' | sed 's|^./||' | tr '\n' ' ')
    file_list=$(printf '%s' "$file_list" | sed 's/  */ /g; s/ $//')
  fi

  if [ -n "$desc" ] && [ "$scan" -eq 0 ]; then
    prompt="Create a professional README.md for a software project named $project_name. $desc Include usage instructions."
  elif [ -n "$desc" ] && [ "$scan" -eq 1 ]; then
    prompt="Create a professional README.md for a software project named $project_name that includes files: $file_list. The project is described as: $desc. Include usage instructions."
  else
    prompt="Create a professional README.md for a software project that includes: $file_list. Include a project description, features, and usage."
  fi
  encoded=$(printf '%s' "$prompt" | jq -sRr @uri)
  local response
  response=$(curl -sL "https://text.pollinations.ai/prompt/${encoded}" || true)
  if printf '%s' "$response" | jq -e . >/dev/null 2>&1; then
    readme=$(printf '%s' "$response" | jq -r '.completion')
  else
    readme="$response"
  fi
  [ -n "$readme" ] || readme="# $project_name"
  printf '%s\n' "$readme" > README.md

  if [ -n "$desc" ] && [ "$scan" -eq 0 ]; then
    prompt="Create an agents.md file for a project described as: $desc. Define Docs agent, Code agent, Build agent, and Test agent. List their roles and goals."
  elif [ -n "$desc" ] && [ "$scan" -eq 1 ]; then
    prompt="Create an agents.md file for a project described as: $desc with files: $file_list. Define Docs agent, Code agent, Build agent, and Test agent. List their roles and goals."
  else
    prompt="Create an agents.md file for a project with these files: $file_list. Define Docs agent, Code agent, Build agent, and Test agent. List their roles and goals."
  fi
  encoded=$(printf '%s' "$prompt" | jq -sRr @uri)
  response=$(curl -sL "https://text.pollinations.ai/prompt/${encoded}" || true)
  if printf '%s' "$response" | jq -e . >/dev/null 2>&1; then
    agents=$(printf '%s' "$response" | jq -r '.completion')
  else
    agents="$response"
  fi
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

set_next_release() {
  local release=0 tag="" desc last next prerelease flag
  while getopts ":r" opt; do
    case "$opt" in
      r)
        release=1
        ;;
      *)
        echo "Usage: githelper set-next [-r]" >&2
        return 1
        ;;
    esac
  done
  shift $((OPTIND - 1))
  if command -v gh >/dev/null 2>&1; then
    if ! gh auth status >/dev/null 2>&1; then
      echo "No GitHub authentication found. Launching gh auth login..." >&2
      gh auth login
    fi
    gh auth setup-git >/dev/null 2>&1 || true
  fi
  if [ "$release" -eq 1 ]; then
    if git rev-parse testing >/dev/null 2>&1; then
      git tag -d testing
      git push -d origin testing || true
      if command -v gh >/dev/null 2>&1; then
        gh release delete -y testing >/dev/null 2>&1 || true
      fi
    fi
    last=$(git tag -l 'v*' | sort -V | tail -n 1)
    if [ -n "$last" ]; then
      next=$(echo "${last#v}" | awk -F. '{if(NF==1){printf "%d",$1+1}else if(NF==2){printf "%d.%d",$1,$2+1}else{printf "%d.%d.%d",$1,$2,$3+1}}')
    else
      next="0.1"
    fi
    tag="v$next"
    prerelease=""
  else
    tag="testing"
    prerelease="--prerelease"
  fi
  git tag -f "$tag"
  git push -f origin "$tag" || true
  if command -v gh >/dev/null 2>&1; then
    if [ "$release" -eq 1 ]; then
      last=$(git tag -l 'v*' | sort -V | tail -n 1)
    else
      last=$(git tag --sort=-creatordate | grep -v "^$tag$" | head -n 1)
    fi
    if [ -n "$last" ]; then
      desc=$(git log "$last"..HEAD --pretty='format:- %s' | head -n 20)
    else
      desc=$(git log --pretty='format:- %s' | head -n 20)
    fi
    flag="$prerelease"
    if gh release view "$tag" >/dev/null 2>&1; then
      gh release edit "$tag" -n "$desc" -t "${tag^} Release" $flag || true
    else
      gh release create "$tag" -n "$desc" -t "${tag^} Release" $flag || true
    fi
  fi
}

set_next_all() {
  local release=0 repo opt
  while getopts ":r" opt; do
    case "$opt" in
      r)
        release=1
        ;;
      *)
        echo "Usage: githelper set-next-all [-r]" >&2
        return 1
        ;;
    esac
  done
  shift $((OPTIND - 1))
  local args=()
  [ "$release" -eq 1 ] && args+=( -r )
  for repo in "$GIT_ROOT"/*/.git; do
    repo="${repo%/\.git}"
    [ -d "$repo" ] || continue
    (cd "$repo" && set_next_release "${args[@]}")
  done
}

cmd="${1:-}"
case "$cmd" in
  pull-all)
    pull_all
    ;;
  push-all)
    shift
    push_all "$@"
    ;;
  status)
    status_repo
    ;;
  pull)
    pull_repo
    ;;
  push)
    push_repo
    ;;
  clone)
    shift
    clone_cmd "$@"
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
  set-next)
    shift
    set_next_release "$@"
    ;;
  set-next-all)
    shift
    set_next_all "$@"
    ;;
  *)
    echo "Usage: githelper.sh <pull-all|push-all|status|pull|push|clone|init|revert-last|clone-mine|newrepo|set-next|set-next-all>" >&2
    exit 1
    ;;
esac
