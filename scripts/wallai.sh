#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

# wallai.sh - generate a wallpaper using Pollinations
#
# Usage: wallai.sh [-b [group]] [-d [mode]] [-f [group]] [-g [group]] [-h] \
#                  [-i [group]] [-k token] [-l] [-im model] [-pm model] [-tm model] \
#                  [-sm model] [-n "text"] [-p "prompt text"] [-r] [-t theme] [-v] \
#                  [-w] [-s style]
#   -b  browse generated wallpapers and optionally favorite one to the group
#   -d  discover a new theme/style (mode: theme, style or both)
#   -f  mark the generated wallpaper as a favorite in the optional group
#   -g  generate using config from the specified group
#   -h  show this help message
#   -i  pick theme and style inspired by past favorites from the optional group (defaults to "main")
#   -l  use the theme/style from the last image if not provided
#   -im model  Pollinations model for image generation (default "flux")
#   -pm model  Pollinations model for prompt generation (default "default")
#   -tm model  Pollinations model for theme discovery
#   -sm model  Pollinations model for style discovery
#   -n  custom negative prompt
#   -p  custom prompt text
#   -r  select a random model from the available list
#   -t  choose a theme
#   -v  verbose output for troubleshooting
#   -w  add weather, time and holiday context to the prompt
#   -s  pick a visual style or use a random one
#
# Dependencies: curl, jq, termux-wallpaper, optional exiftool for -f
# Output: saves the generated image to ~/pictures/generated-wallpapers and sets
#         the current wallpaper
# TAG: wallpaper
# TAG: ai

show_help() {
  cat <<'EOF'
Usage: wallai.sh [-b [group]] [-d [mode]] [-f [group]] [-g [group]] [-h] \
                 [-i [group]] [-k token] [-l] [-im model] [-pm model] [-tm model] \
                 [-sm model] [-n "text"] [-p "prompt text"] [-r] [-t theme] \
                 [-v] [-w] [-s style]

  -b [group]  browse generated wallpapers and optionally favorite one to the group
  -d [mode]   discover a new theme/style (mode: theme, style or both)
  -f [group]  mark the generated wallpaper as a favorite in the optional group
  -g [group]  generate using config from the specified group
  -h          show this help message
  -i [group]  pick theme and style inspired by past favorites from the optional group (defaults to "main")
  -k token    save Pollinations API token to the group used with -g (default main)
  -l          use the theme/style from the last image if not provided
  -im model   Pollinations model for image generation (default "flux")
  -pm model   Pollinations model for prompt generation (default "default")
  -tm model   Pollinations model for theme discovery
  -sm model   Pollinations model for style discovery
  -n text     custom negative prompt
  -p text     custom prompt text
  -r          select a random model from the available list
  -t theme    choose a theme
  -v          verbose output for troubleshooting
  -w          add weather, time and holiday context to the prompt
  -s style    pick a visual style or use a random one
EOF
}

# Check dependencies early so the script fails with a clear message
for cmd in curl jq termux-wallpaper; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "❌ Required command '$cmd' is not installed" >&2
    exit 1
  fi
done

# Parse options
prompt=""
theme=""
style=""
negative_prompt=""
# Image generation model
model=""
# Prompt generation model override
prompt_model_override=""
# Theme and style discovery model overrides
theme_model_override=""
style_model_override=""
random_model=false
favorite_wall=false
favorite_group="main"
gen_group="main"
discovery_mode=""
inspired_mode=false
inspired_group="main"
weather_flag=false
use_last=false
generation_opts=false
verbose=false
browse_gallery=false
browse_group="main"
new_token=""

# Handle multi-letter flags before getopts
args=()
while [ $# -gt 0 ]; do
  case "$1" in
    -im)
      [ $# -ge 2 ] || { echo "Missing argument for -im" >&2; exit 1; }
      model="$2"
      generation_opts=true
      shift 2
      ;;
    -pm)
      [ $# -ge 2 ] || { echo "Missing argument for -pm" >&2; exit 1; }
      prompt_model_override="$2"
      generation_opts=true
      shift 2
      ;;
    -tm)
      [ $# -ge 2 ] || { echo "Missing argument for -tm" >&2; exit 1; }
      theme_model_override="$2"
      generation_opts=true
      shift 2
      ;;
    -sm)
      [ $# -ge 2 ] || { echo "Missing argument for -sm" >&2; exit 1; }
      style_model_override="$2"
      generation_opts=true
      shift 2
      ;;
    -m)
      [ $# -ge 2 ] || { echo "Missing argument for -m" >&2; exit 1; }
      model="$2"
      generation_opts=true
      shift 2
      ;;
    *)
      args+=("$1")
      shift
      ;;
  esac
done
set -- "${args[@]}"

while getopts ":p:t:s:rn:f:g:d:i:k:wvlhb:" opt; do
  case "$opt" in
    p)
      prompt="$OPTARG"
      generation_opts=true
      ;;
    t)
      theme="$OPTARG"
      generation_opts=true
      ;;
    s)
      style="$OPTARG"
      generation_opts=true
      ;;
    b)
      browse_gallery=true
      browse_group="$OPTARG"
      ;;
    r)
      random_model=true
      generation_opts=true
      ;;
    f)
      favorite_wall=true
      favorite_group="$OPTARG"
      ;;
    g)
      gen_group="$OPTARG"
      ;;
    k)
      new_token="$OPTARG"
      ;;
    d)
      if [ -n "${OPTARG:-}" ] && [ "${OPTARG:0:1}" != "-" ]; then
        discovery_mode="$OPTARG"
      else
        discovery_mode="both"
        [ -n "${OPTARG:-}" ] && OPTIND=$((OPTIND - 1))
      fi
      ;;
    i)
      inspired_mode=true
      if [ -n "${OPTARG:-}" ] && [ "${OPTARG:0:1}" != "-" ]; then
        inspired_group="$OPTARG"
      else
        inspired_group="main"
        [ -n "${OPTARG:-}" ] && OPTIND=$((OPTIND - 1))
      fi
      ;;
    w)
      weather_flag=true
      ;;
    l)
      use_last=true
      generation_opts=true
      ;;
    n)
      negative_prompt="$OPTARG"
      generation_opts=true
      ;;
    v)
      verbose=true
      ;;
    h)
      show_help
      exit 0
      ;;
    :)
      case "$OPTARG" in
        f)
          favorite_wall=true
          favorite_group="main"
          ;;
        g)
          gen_group="main"
          ;;
        d)
          discovery_mode="both"
          ;;
        i)
          inspired_mode=true
          inspired_group="main"
          ;;
        b)
          browse_gallery=true
          browse_group="main"
          ;;
        *)
          echo "Usage: wallai.sh [-b [group]] [-d [mode]] [-f [group]] [-g [group]] [-h] [-i [group]] [-k token] [-l] [-im model] [-pm model] [-tm model] [-sm model] [-n \"text\"] [-p \"prompt text\"] [-r] [-t theme] [-v] [-w] [-s style]" >&2
          exit 1
          ;;
      esac
      ;;
    *)
      echo "Usage: wallai.sh [-b [group]] [-d [mode]] [-f [group]] [-g [group]] [-h] [-i [group]] [-k token] [-l] [-im model] [-pm model] [-tm model] [-sm model] [-n \"text\"] [-p \"prompt text\"] [-r] [-t theme] [-v] [-w] [-s style]" >&2
      exit 1
      ;;
  esac
done
shift $((OPTIND - 1))

# Default negative prompt if not provided
if [ -z "$negative_prompt" ]; then
  negative_prompt="blurry, low quality, deformed, disfigured, out of frame, low contrast, bad anatomy"
fi

# Load configuration and bootstrap defaults if needed
config_file="$HOME/.wallai/config.yml"
if [ ! -f "$config_file" ]; then
  mkdir -p "$(dirname "$config_file")"
  cat >"$config_file" <<'EOF'
groups:
  main:
    pollinations_token: ""
    image_model: flux
    prompt_model: default
    path: ~/pictures/favorites/main
    nsfw: false
    allow_prompt_fetch: true
    themes:
      - dreamcore
      - mystical forest
      - cosmic horror
      - ethereal landscape
      - retrofuturism
      - alien architecture
      - cyberpunk metropolis
    styles:
      - unreal engine
      - cinematic lighting
      - octane render
      - hyperrealism
      - volumetric lighting
      - high detail
      - 4k concept art
EOF
fi

config_json=$(CFG="$config_file" python3 - <<'PY'
import os,sys,json
import yaml
with open(os.environ['CFG']) as f:
    data = yaml.safe_load(f) or {}
json.dump(data, sys.stdout)
PY
)

# Pollinations token from config
pollinations_token=$(printf '%s' "$config_json" | jq -r --arg g "$gen_group" '.groups[$g].pollinations_token // ""')

# Update token in config if -k was provided
if [ -n "$new_token" ]; then
  pollinations_token="$new_token"
  python3 - "$config_file" "$gen_group" "$pollinations_token" <<'PY'
import sys, yaml, os
cfg, group, token = sys.argv[1:]
data = {}
if os.path.exists(cfg):
    with open(cfg) as f:
        data = yaml.safe_load(f) or {}
grp = data.setdefault('groups', {}).setdefault(group, {})
grp['pollinations_token'] = token
with open(cfg, 'w') as f:
    yaml.safe_dump(data, f, sort_keys=False)
PY
  config_json=$(printf '%s' "$config_json" | jq --arg g "$gen_group" --arg t "$pollinations_token" '
    (.groups[$g] //= {}) |
    .groups[$g].pollinations_token=$t
  ')
fi

# Use Pollinations token for authenticated requests if available
curl_auth=()
[ -n "$pollinations_token" ] && curl_auth=(-H "Authorization: Bearer $pollinations_token")

# Helper to fetch values from config JSON
cfg() {
  printf '%s' "$config_json" | jq -r --arg g "$1" "$2" 2>/dev/null
}

# Generation group settings
# shellcheck disable=SC2016
gen_path=$(cfg "$gen_group" '.groups[$g].path // empty')
[ -z "$gen_path" ] && gen_path="$HOME/pictures/favorites/$gen_group"
gen_path=$(eval printf '%s' "$gen_path")
# shellcheck disable=SC2016
gen_nsfw=$(cfg "$gen_group" '.groups[$g].nsfw // false')
# shellcheck disable=SC2016
gen_prompt_model=$(cfg "$gen_group" '.groups[$g].prompt_model // "default"')
# shellcheck disable=SC2016
gen_theme_model=$(cfg "$gen_group" '.groups[$g].theme_model // empty')
# shellcheck disable=SC2016
gen_style_model=$(cfg "$gen_group" '.groups[$g].style_model // empty')
# shellcheck disable=SC2016
gen_image_model=$(cfg "$gen_group" '.groups[$g].image_model // "flux"')
# shellcheck disable=SC2016
gen_allow_prompt_fetch=$(cfg "$gen_group" '.groups[$g].allow_prompt_fetch // true')
# shellcheck disable=SC2016
mapfile -t gen_themes < <(cfg "$gen_group" '.groups[$g].themes[]?')
# shellcheck disable=SC2016
mapfile -t gen_styles < <(cfg "$gen_group" '.groups[$g].styles[]?')

# Favorite group path
# shellcheck disable=SC2016
fav_path=$(cfg "$favorite_group" '.groups[$g].path // empty')
[ -z "$fav_path" ] && fav_path="$HOME/pictures/favorites/$favorite_group"
fav_path=$(eval printf '%s' "$fav_path")

# Inspired group path for -i
# shellcheck disable=SC2016
insp_path=$(cfg "$inspired_group" '.groups[$g].path // empty')
[ -z "$insp_path" ] && insp_path="$HOME/pictures/favorites/$inspired_group"
insp_path=$(eval printf '%s' "$insp_path")

# Apply config defaults if flags were not provided
[ -z "$model" ] && model="$gen_image_model"
[ -n "$prompt_model_override" ] && gen_prompt_model="$prompt_model_override"
theme_model="${theme_model_override:-${gen_theme_model:-$gen_prompt_model}}"
style_model="${style_model_override:-${gen_style_model:-$gen_prompt_model}}"

# Discover new theme or style via Pollinations
discover_item() {
  local kind="$1" query result dseed
  if [ "$gen_allow_prompt_fetch" != true ]; then
    return
  fi
  case "$kind" in
    theme) query="Imagine a theme in two words. Respond with only two words." ;;
    style) query="Imagine an art style in two words. Respond with only two words." ;;
    *) return ;;
  esac
  dseed=$(random_seed)
  encoded=$(printf '%s' "$query" | jq -sRr @uri)
  local m="$gen_prompt_model"
  case "$kind" in
    theme) m="$theme_model" ;;
    style) m="$style_model" ;;
  esac
  local url="https://text.pollinations.ai/prompt/${encoded}?seed=${dseed}&model=${m}"
  case "$kind" in
    theme) theme_seed="$dseed" ;;
    style) style_seed="$dseed" ;;
  esac
  [ "$verbose" = true ] && echo "🔍 Pollinations URL: $url" >&2
  # Verbose output goes to stderr to avoid affecting variable assignments
  result=$(curl -sL "${curl_auth[@]}" "$url" || true)
  [ "$verbose" = true ] && echo "🔍 Response: $result" >&2
  result=$(printf '%s' "$result" | tr '\n' ' ' | sed 's/  */ /g; s/^ //; s/ $//')
  if [ -n "$result" ]; then
    printf '%s' "$result" | awk '{print $1, $2}'
  fi
}

# Append a discovered item to the group's config list if missing
append_config_item() {
  local list="$1" item="$2"
  tmp=$(mktemp)
  jq --arg g "$gen_group" --arg i "$item" --arg l "$list" '
    (.groups[$g][$l] //= []) as $arr
    | if ($arr | index($i)) then . else .groups[$g][$l] += [$i] end' "$config_file" > "$tmp" && mv "$tmp" "$config_file"
}

# Directory where generated wallpapers live and log path
save_dir="$HOME/pictures/generated-wallpapers"
mkdir -p "$save_dir"
log_file="$save_dir/wallai.log"

# Generate a short random seed
random_seed() {
  od -vN4 -An -tx4 /dev/urandom | tr -d ' \n'
}

# Browse existing wallpapers and optionally favorite them

# Seed for image generation and prompt fetch
seed=$(random_seed)
prompt_seed=""
theme_seed=""
style_seed=""

# Apply theme/style from the last generated image if -l is used
if [ "$use_last" = true ]; then
  last_entry=$(tail -n1 "$log_file" 2>/dev/null || true)
  if [ -z "$last_entry" ]; then
    echo "❌ No wallpaper has been generated yet" >&2
    exit 1
  fi
  last_file=$(printf '%s' "$last_entry" | cut -d'|' -f1)
  theme_slug=$(printf '%s' "$last_file" | cut -d'_' -f2)
  style_slug=$(printf '%s' "$last_file" | cut -d'_' -f3 | sed 's/\..*//')
  last_theme=$(printf '%s' "$theme_slug" | sed 's/-/ /g')
  last_style=$(printf '%s' "$style_slug" | sed 's/-/ /g')
  [ -z "$theme" ] && theme="$last_theme"
  [ -z "$style" ] && style="$last_style"
fi

# Convert strings like "Cyberpunk Metropolis" to "cyberpunk-metropolis"
slugify() {
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | \
    sed 's/[^a-z0-9]/-/g; s/--*/-/g; s/^-//; s/-$//'
}

# Function to favorite the most recent wallpaper with metadata using exiftool
favorite_image() {
  command -v exiftool >/dev/null 2>&1 || {
    echo "❌ exiftool is required for -f" >&2
    return 1
  }
  local file="$1" comment="$2" theme="$3" style="$4" model="$5" seed="$6" ts="$7"
  local group_path="$8"
  local dest_dir="$group_path"
  local log="$dest_dir/favorites.jsonl"
  mkdir -p "$dest_dir"
  local dest
  dest="$dest_dir/$(basename "$file")"
  cp "$file" "$dest"
  exiftool -overwrite_original -Comment="$comment" "$dest" >/dev/null
  jq -n --arg prompt "$comment" --arg theme "$theme" --arg style "$style" \
        --arg model "$model" --arg seed "$seed" --arg ts "$ts" \
        --arg filename "$(basename "$dest")" \
        '{prompt:$prompt, theme:$theme, style:$style, model:$model, seed:$seed, timestamp:$ts, filename:$filename}' >> "$log"
  echo "⭐ Added to favorites: $dest"
}

# Browse existing wallpapers and optionally favorite them
# shellcheck disable=SC2317
browse_gallery() {
  local fav_group="$1" list result sel decision group_list gsel gsel_val
  for cmd in termux-dialog termux-open jq; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      echo "❌ Required command '$cmd' is not installed" >&2
      return 1
    fi
  done
  cd "$save_dir" 2>/dev/null || { echo "❌ No generated wallpapers found" >&2; return 1; }
  mapfile -t images < <(ls -t -- *.jpg *.png 2>/dev/null || true)
  [ "${#images[@]}" -gt 0 ] || { echo "❌ No images found" >&2; return 1; }
  list=$(IFS=','; printf '%s' "${images[*]}")
  result=$(termux-dialog -l "$list" -t "Select wallpaper" 2>/dev/null | tail -n1 || true)
  if ! sel=$(printf '%s' "$result" | jq -e -r '.text' 2>/dev/null); then
    echo "❌ Invalid JSON from termux-dialog" >&2
    return 1
  fi
  [ -n "$sel" ] || return 0
  termux-open "$save_dir/$sel"
  result=$(termux-dialog -l "yes,no" -t "Add to favorites?" 2>/dev/null | tail -n1 || true)
  decision=$(printf '%s' "$result" | jq -r '.text')
  [ "$decision" = "yes" ] || return 0
  if [ -f "$config_file" ]; then
    mapfile -t groups < <(CFG="$config_file" python3 - <<'PY'
import os,yaml
with open(os.environ['CFG']) as f:
    data=yaml.safe_load(f) or {}
print('\n'.join((data.get('groups') or {}).keys()))
PY
    )
  else
    groups=(main)
  fi
  [ "${#groups[@]}" -gt 0 ] || groups=(main)
  if [ "$fav_group" = "main" ] && [ "${#groups[@]}" -gt 1 ]; then
    group_list=$(IFS=','; printf '%s' "${groups[*]}")
    gsel=$(termux-dialog -l "$group_list" -t "Select favorites group" 2>/dev/null | tail -n1 || true)
    gsel_val=$(printf '%s' "$gsel" | jq -r '.text')
    [ -n "$gsel_val" ] && fav_group="$gsel_val"
  fi
  local dest_path="$HOME/pictures/favorites/$fav_group"
  if [ -f "$config_file" ]; then
    cfg_path=$(CFG="$config_file" G="$fav_group" python3 - <<'PY'
import os,yaml
with open(os.environ['CFG']) as f:
    data=yaml.safe_load(f) or {}
g=os.environ['G']
print(os.path.expanduser(data.get('groups', {}).get(g, {}).get('path','')))
PY
    )
    [ -n "$cfg_path" ] && dest_path="$cfg_path"
  fi
  entry=$(grep "^$sel|" "$log_file" 2>/dev/null || true)
  if [ -n "$entry" ]; then
    seed=$(printf '%s' "$entry" | cut -d'|' -f2)
    prompt=$(printf '%s' "$entry" | cut -d'|' -f3)
    theme=$(printf '%s' "$sel" | cut -d'_' -f2 | sed 's/-/ /g')
    style=$(printf '%s' "$sel" | cut -d'_' -f3 | sed 's/\..*//' | sed 's/-/ /g')
    ts=$(printf '%s' "$sel" | cut -d'_' -f1)
    favorite_image "$save_dir/$sel" "$prompt (seed: $seed)" "$theme" "$style" "unknown" "$seed" "$ts" "$dest_path"
  else
    mkdir -p "$dest_path"
    cp "$save_dir/$sel" "$dest_path/" && echo "⭐ Added to favorites: $dest_path/$sel"
  fi
}

# Open gallery if requested
if [ "$browse_gallery" = true ]; then
  browse_gallery "$browse_group"
  exit 0
fi

# Spinner that cycles through emojis while a command runs
spinner() {
  local pid=$1
  local emojis=("🎨" "🧠" "✨" "🖼️" "🌀")
  local i=0
  tput civis 2>/dev/null || true
  while kill -0 "$pid" 2>/dev/null; do
    printf "\r%s Generating image..." "${emojis[i]}"
    i=$(( (i + 1) % ${#emojis[@]} ))
    sleep 0.5
  done
  tput cnorm 2>/dev/null || true
  printf "\r\033[K\n"
}

# If called only with -f, favorite the last generated wallpaper and exit early
if [ "$favorite_wall" = true ] && [ "$generation_opts" = false ]; then
  last_entry=$(tail -n1 "$log_file" 2>/dev/null || true)
  if [ -z "$last_entry" ]; then
    echo "❌ No wallpaper has been generated yet" >&2
    exit 1
  fi
  last_file=$(printf '%s' "$last_entry" | cut -d'|' -f1)
  last_seed=$(printf '%s' "$last_entry" | cut -d'|' -f2)
  last_prompt=$(printf '%s' "$last_entry" | cut -d'|' -f3)
  ts=$(printf '%s' "$last_file" | cut -d'_' -f1)
  theme_slug=$(printf '%s' "$last_file" | cut -d'_' -f2)
  style_slug=$(printf '%s' "$last_file" | cut -d'_' -f3 | sed 's/\..*//')
  last_theme=$(printf '%s' "$theme_slug" | sed 's/-/ /g')
  last_style=$(printf '%s' "$style_slug" | sed 's/-/ /g')
  favorite_image "$save_dir/$last_file" "$last_prompt (seed: $last_seed)" "$last_theme" "$last_style" "unknown" "$last_seed" "$ts" "$fav_path"
  exit 0
fi

# Inspired mode selects theme and style based on past favorites
if [ "$inspired_mode" = true ]; then
  fav_file="$insp_path/favorites.jsonl"
  if [ -f "$fav_file" ]; then
    if [ -z "$theme" ]; then
      theme=$(jq -r '.theme' "$fav_file" | shuf -n1 || true)
    fi
    if [ -z "$style" ]; then
      style=$(jq -r '.style' "$fav_file" | shuf -n1 || true)
    fi
    echo "🧠 Inspired by favorites:"
    [ -n "$theme" ] && echo "🔖 Theme: $theme"
    [ -n "$style" ] && echo "🎨 Style: $style"
  fi
fi

# Discovery mode for new themes or styles
discovered_theme=""
discovered_style=""
if [ -n "$discovery_mode" ]; then
  if [ "$discovery_mode" = "both" ] || [ "$discovery_mode" = "theme" ]; then
    new=$(discover_item theme)
    if [ -n "$new" ]; then
      theme="$new"
      discovered_theme="$new"
      echo "🆕 Discovered theme: $theme"
    fi
  fi
  if [ "$discovery_mode" = "both" ] || [ "$discovery_mode" = "style" ]; then
    new=$(discover_item style)
    if [ -n "$new" ]; then
      style="$new"
      discovered_style="$new"
      echo "🆕 Discovered style: $style"
    fi
  fi
fi

# Validate selected model using the API list
models_json=$(curl -sL "${curl_auth[@]}" "https://image.pollinations.ai/models" || true)
if ! mapfile -t models < <(printf '%s' "$models_json" | jq -r '.[]' 2>/dev/null); then
  models=(flux turbo gptimage)
fi
if [ "$random_model" = true ]; then
  # Exclude models that require paid tiers or produce low quality
  mapfile -t candidates < <(printf '%s\n' "${models[@]}" | grep -vE '^(gptimage|turbo)$')
  [ "${#candidates[@]}" -gt 0 ] || candidates=(flux)
  model=$(printf '%s\n' "${candidates[@]}" | shuf -n1)
fi
if ! printf '%s\n' "${models[@]}" | grep -qxF "$model"; then
  echo "Invalid model: $model" >&2
  echo "Valid models: ${models[*]}" >&2
  exit 1
fi

# wallai.sh - generate a wallpaper using Pollinations
#
# Usage: wallai.sh [-b [group]] [-p "prompt text"] [-t theme] [-s style] [-im model] [-pm model] [-tm model] [-sm model] [-r] [-f]
#                  [-g group] [-d mode] [-i group] [-k token] [-w] [-l] [-n "text"] [-v] [-h]
# Environment variables:
#   ALLOW_NSFW         Set to 'false' to disallow NSFW prompts (default 'true')
# Flags:
#   -p prompt text  Custom prompt text
#   -t theme        Specify theme
#   -s style        Pick a visual style or use a random one
#   -im model       Pollinations model for image generation (default 'flux')
#   -pm model       Pollinations model for prompt generation (default 'default')
#   -tm model       Pollinations model for theme discovery
#   -sm model       Pollinations model for style discovery
#   -r              Pick a random model from the available list
#   -b [group]      Browse generated wallpapers and optionally favorite one
#   -f              Mark the latest generated wallpaper as a favorite
#   -g group        Generate using config from the specified group
#   -d mode         Discover a new theme/style (theme, style or both)
#   -i group        Choose theme and style inspired by favorites from the specified group (defaults to "main")
#   -k token        Save Pollinations API token to the config
#   -w              Add weather, time and seasonal context
#   -l              Use theme and/or style from the last image
#   -n text         Override the default negative prompt
#   -v              Enable verbose output
#   -h              Show help and exit
#
# Dependencies: curl, jq, termux-wallpaper, optional exiftool for -f
# Output: saves the generated image under ~/pictures/generated-wallpapers
# TAG: wallpaper
# TAG: ai

save_dir="$HOME/pictures/generated-wallpapers"
mkdir -p "$save_dir"
timestamp="$(date +%Y%m%d-%H%M%S)"
tmp_output="$save_dir/${timestamp}.img"


# Whether to allow NSFW prompts and generations
nsfw_raw="${ALLOW_NSFW:-true}"
case "$(printf '%s' "$nsfw_raw" | tr '[:upper:]' '[:lower:]')" in
  1|true|yes)
    allow_nsfw=true
    ;;
  *)
    allow_nsfw=false
    ;;
esac

# Group config overrides NSFW policy
if [ "$gen_nsfw" = true ]; then
  allow_nsfw=true
fi

params="nologo=true&enhance=true&private=true&seed=${seed}&model=${model}"
if [ "$allow_nsfw" = false ]; then
  params="safe=true&${params}"
fi


fetch_prompt() {
  [ "$gen_allow_prompt_fetch" != true ] && return 1
  local attempt=1 encoded url
  encoded=$(printf '%s' "Generate a high quality wallpaper prompt about $theme in exactly 15 words. Respond with exactly 15 words." | jq -sRr @uri)
  prompt_seed=""
  while [ "$attempt" -le 3 ]; do
    prompt_seed=$(random_seed)
    url="https://text.pollinations.ai/prompt/${encoded}?seed=${prompt_seed}&model=${gen_prompt_model}"
    [ "$verbose" = true ] && echo "🔍 Prompt URL: $url"
    prompt=$(curl -sL "${curl_auth[@]}" "$url" || true)
    [ "$verbose" = true ] && echo "🔍 Attempt $attempt response: $prompt"
    prompt=$(printf '%s' "$prompt" | tr '\n' ' ' | sed 's/  */ /g; s/^ //; s/ $//')
    prompt=$(printf '%s\n' "$prompt" | awk '{for(i=1;i<=15 && i<=NF;i++){printf $i;if(i<15 && i<NF)printf " ";}}')
    [ -n "$prompt" ] && return 0
    attempt=$((attempt + 1))
    sleep 1
  done
  return 1
}

if [ -z "$prompt" ]; then
  echo "🎯 Fetching random prompt from Pollinations..."

  # 🎲 Step 1: Pick or use provided theme
  if [ -z "$theme" ]; then
    if [ "${#gen_themes[@]}" -gt 0 ]; then
      theme=$(printf '%s\n' "${gen_themes[@]}" | shuf -n1)
    else
      themes=(
        "dreamcore" "mystical forest" "cosmic horror" "ethereal landscape"
        "retrofuturism" "alien architecture" "cyberpunk metropolis"
      )
      theme=$(printf '%s\n' "${themes[@]}" | shuf -n1)
    fi
  fi
  echo "🔖 Selected theme: $theme"

  # 🧠 Step 2: Retrieve a text prompt for that theme with retries
  if ! fetch_prompt; then
    echo "❌ Failed to fetch prompt after retries. Using fallback."
    fallback_prompts=(
      "surreal dreamscape with neon colors"
      "futuristic city skyline at dusk"
      "ancient ruins shrouded in mist"
      "mystical forest glowing softly"
      "retro wave grid horizon with stars"
      "lush alien jungle under twin moons"
      "calm desert landscape under stars"
    )
    prompt=$(printf '%s\n' "${fallback_prompts[@]}" | shuf -n1)
  fi
fi

# Pick a style if none was provided
if [ -z "$style" ]; then
  if [ "${#gen_styles[@]}" -gt 0 ]; then
    style=$(printf '%s\n' "${gen_styles[@]}" | shuf -n1)
  else
    styles=(
      "unreal engine" "cinematic lighting" "octane render" "hyperrealism" \
      "volumetric lighting" "high detail" "4k concept art"
    )
    style=$(printf '%s\n' "${styles[@]}" | shuf -n1)
  fi
fi
echo "🖌 Selected style: $style"

# Build the final prompt with theme and style weights and negative text
if [ -n "$theme" ]; then
  prompt="(${theme}:1.5) $prompt"
fi
prompt="$prompt (${style}:1.3) [negative prompt: $negative_prompt]"

# Add weather-aware context if requested
if [ "$weather_flag" = true ]; then
  weather="$(curl -sL "https://wttr.in/?format=%C" | tr '\n' ' ' | tr '[:upper:]' '[:lower:]' | sed 's/  */ /g')"
  [ -z "$weather" ] && weather="clear"
  hour=$(date +%H)
  if [ "$hour" -ge 5 ] && [ "$hour" -lt 12 ]; then
    tod="morning"
  elif [ "$hour" -ge 12 ] && [ "$hour" -lt 17 ]; then
    tod="afternoon"
  elif [ "$hour" -ge 17 ] && [ "$hour" -lt 21 ]; then
    tod="evening"
  else
    tod="night"
  fi
  month=$(date +%m)
  case "$month" in
    12|01|02) season="winter" ;;
    03|04|05) season="spring" ;;
    06|07|08) season="summer" ;;
    *) season="autumn" ;;
  esac
  holiday=""
  today=$(date +%m-%d)
  case "$today" in
    12-25) holiday="christmas" ;;
    10-31) holiday="halloween" ;;
    07-04) holiday="independence day" ;;
    01-01) holiday="new year" ;;
    02-14) holiday="valentines day" ;;
    12-31) holiday="new years eve" ;;
  esac
  env_parts=("(${weather} weather:1.2)" "(${tod}:1.2)" "(${season}:1.2)")
  [ -n "$holiday" ] && env_parts+=("(${holiday}:1.2)")
  env_text=$(printf ', %s' "${env_parts[@]}")
  env_text=${env_text#, }
  prompt="$prompt, $env_text"
fi

# Ensure we always have a value for the generated content type
generated_content_type=""

echo "🎨 Final prompt: $prompt"
echo "🛠 Using model: $model"

# ✨ Step 3: Generate image via Pollinations

generate_pollinations() {
  local out_file="$1" type_file="$2"
  local encoded headers err_msg
  encoded=$(printf '%s' "$prompt" | jq -sRr @uri)
  headers=$(mktemp)
  local url="https://image.pollinations.ai/prompt/${encoded}?${params}"
  [ "$verbose" = true ] && echo "🔍 Image URL: $url"
  if ! curl -sL "${curl_auth[@]}" -D "$headers" "$url" -o "$out_file"; then
    rm -f "$headers"
    return 1
  fi
  generated_content_type=$(grep -i '^content-type:' "$headers" | tr -d '\r' | awk '{print $2}')
  [ "$verbose" = true ] && echo "🔍 Content-Type: $generated_content_type"
  printf '%s' "$generated_content_type" >"$type_file"
  rm -f "$headers"
  if printf '%s' "$generated_content_type" | grep -qi 'application/json'; then
    err_msg=$(jq -r '.message // .error // "Unknown error"' <"$out_file" 2>/dev/null)
    echo "❌ Pollinations error: $err_msg" >&2
    return 1
  fi
}

ctype_file=$(mktemp)
attempt=1
while true; do
  generate_pollinations "$tmp_output" "$ctype_file" &
  gen_pid=$!
  spinner "$gen_pid" &
  spin_pid=$!
  wait "$gen_pid"
  status=$?
  kill "$spin_pid" 2>/dev/null || true
  wait "$spin_pid" 2>/dev/null || true
  printf '\n'
  if [ "$status" -eq 0 ]; then
    generated_content_type=$(cat "$ctype_file" 2>/dev/null || true)
    file_type=$(file -b --mime-type "$tmp_output" 2>/dev/null || true)
    [ "$verbose" = true ] && echo "🔍 File type: $file_type"
    if printf '%s' "$generated_content_type" | grep -qi '^image/' && \
       printf '%s' "$file_type" | grep -qi '^image/'; then
      break
    fi
    echo "❌ Invalid image file!" >&2
    status=1
  fi
  if [ "$status" -eq 0 ]; then
    break
  fi
  if [ "$attempt" -ge 3 ]; then
    echo "❌ Failed to generate image via Pollinations" >&2
    exit 1
  fi
  attempt=$((attempt + 1))
  echo "⚠️  Retrying image generation ($attempt/3)..."
done
echo "✅ Image generated successfully"
img_source="Pollinations"

generated_content_type=$(cat "$ctype_file" 2>/dev/null || true)
rm -f "$ctype_file"

case "$generated_content_type" in
  image/png)
    ext="png"
    ;;
  image/jpeg|image/jpg)
    ext="jpg"
    ;;
  *)
    ext="png"
    ;;
esac
theme_slug=$(slugify "${theme:-custom}")
style_slug=$(slugify "$style")
filename="${timestamp}_${theme_slug}_${style_slug}.${ext}"
output="$save_dir/$filename"
mv "$tmp_output" "$output"

termux-wallpaper -f "$output"
echo "🎉 Wallpaper set from prompt: $prompt" "(source: $img_source)"
echo "💾 Saved to: $output"

# Log filename, seeds and prompt for later reference
echo "$filename|$seed|$prompt|$prompt_seed|$theme_seed|$style_seed" >> "$log_file"

# Favorite the wallpaper immediately if -f was passed alongside generation options
[ "$favorite_wall" = true ] && {
  favorite_image "$output" "$prompt" "$theme" "$style" "$model" "$seed" "$timestamp" "$fav_path"
  [ -n "$discovered_theme" ] && append_config_item "themes" "$discovered_theme"
  [ -n "$discovered_style" ] && append_config_item "styles" "$discovered_style"
}

exit 0
