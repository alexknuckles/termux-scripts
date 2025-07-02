#!/bin/bash
set -eu
if set -o | grep -q pipefail; then
  set -o pipefail
fi

cleanup_and_exit() {
  local code="${1:-0}"
  rm -f "$TMPFILE" "$TMPJSON" 2>/dev/null || true
  exit "$code"
}

trap 'cleanup_and_exit 1' INT TERM

TMPFILE=""
TMPJSON=""
reuse_group=""

# wallai.sh - generate a wallpaper using OpenAI-compatible APIs
#
# Usage: wallai.sh [-b [group]] [-d [mode]] [-f [group]] [-g [group]] [-h] \
#                  [-i [mode]] [-k token] [-l] [-im model] [-pm model] [-tm model] \
#                  [-sm model] [-n "text"] [-p "prompt text"] [-r] [-t tag] [-v] \
#                  [-w] [-s style] [-m mood] [-u mode] [-x [count]]
#   -b  browse generated wallpapers and optionally favorite one to the group
#   -d  discover a new tag/style (mode: tag, style or both)
#   -f  mark the generated wallpaper as a favorite in the optional group
#       (defaults to the -g group)
#   -x  force image generation after discovery (optional count for batch)
#   -g  generate using config from the specified group
#   -h  show this help message
#   -i  pick components inspired by favorites using mode pair|tag|style (default pair)
#   -u  reuse a previous wallpaper: latest, random or favorites
#   -m  specify a mood tone for the prompt
#   -l  use the tag/style from the last image if not provided
#   -im model  Image model to use
#   -pm model  Text model for prompt generation
#   -tm model  Text model for tag discovery
#   -sm model  Text model for style discovery
#   -n  custom negative prompt
#   -p  custom prompt text
#   -r  select a random model from the available list
#   -t  choose a tag
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
  local bold normal
  bold=$(tput bold 2>/dev/null || printf '')
  normal=$(tput sgr0 2>/dev/null || printf '')
  cat <<END
Usage: wallai.sh [options]

${bold}General Options:${normal}
  -h, --help         Show this help message
  -v                 Enable verbose mode
  -g <group>         Use or create a group config
  -k <token>         Save provider token to the group
  --describe-image <file>  Generate prompt from image caption

${bold}Prompt Customization:${normal}
  -p <prompt>        Use custom prompt
  -t <tag>           Choose tag manually
  -s <style>         Choose style manually
  -m <mood>          Set mood (optional, affects prompt tone)
  -n <text>          Custom negative prompt
  -w                 Add weather/time/holiday context
  -l                 Use tag/style from last image

${bold}Discovery & Inspiration:${normal}
  -d [mode]          Discover new tags/styles (tag, style, both)
  -i [tag|style|pair] Use inspired mode from favorites

${bold}Image Generation:${normal}
  -x [n]             Generate n images (default 1)
  -f [group]         Favorite the image after generation
  -r                 Select a random model
  -im <model>        Image generation model
  -pm <model>        Prompt generation model
  -tm <model>        Tag discovery model
  -sm <model>        Style discovery model

${bold}Wallpapering & History:${normal}
  -b [group]         Browse generated wallpapers
  -u <mode>          Use previous image (latest, favorites, random)
  --use group=name   Limit reuse to a specific group

Examples:
  wallai.sh -t dreamcore -m surreal -x 3 -f
  wallai.sh -u favorites -g sci-fi
  wallai.sh -i tag -d
  wallai.sh --describe-image picture.jpg
END
}
# Check dependencies early so the script fails with a clear message
for cmd in curl jq; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "❌ Required command '$cmd' is not installed" >&2
    cleanup_and_exit 1
  fi
done

# Check for termux-wallpaper but don't fail if missing (for testing on non-Termux systems)
has_termux_wallpaper=false
if command -v termux-wallpaper >/dev/null 2>&1; then
  has_termux_wallpaper=true
fi

# Parse options
prompt=""
tag=""
style=""
negative_prompt=""
mood=""
# Flags to record user-provided tag or style
tag_provided=false
style_provided=false
mood_provided=false
# Image generation model
model=""
# Prompt generation model override
prompt_model_override=""
# Tag and style discovery model overrides
tag_model_override=""
style_model_override=""
random_model=false
favorite_wall=false
favorite_group="main"
favorite_group_provided=false
gen_group="main"
gen_group_set=false
discovery_mode=""
inspired_mode=false
inspired_type="pair"
weather_flag=false
use_last=false
generation_opts=false
verbose=false
browse_gallery=false
browse_group="main"
new_token=""
reuse_mode=""
describe_image_file=""

# Inspired mode selections
top_tag=""
top_style=""
tag_weight=1.5
style_weight=1.3

batch_count=1

batch_tag_count=1
batch_style_count=1
discovery_arg=""
# Handle multi-letter flags before getopts
force_generate=false
args=()
while [ $# -gt 0 ]; do
  case "$1" in
    -im)
      [ $# -ge 2 ] || { echo "Missing argument for -im" >&2; cleanup_and_exit 1; }
      model="$2"
      generation_opts=true
      shift 2
      ;;
    -pm)
      [ $# -ge 2 ] || { echo "Missing argument for -pm" >&2; cleanup_and_exit 1; }
      prompt_model_override="$2"
      generation_opts=true
      shift 2
      ;;
    -tm)
      [ $# -ge 2 ] || { echo "Missing argument for -tm" >&2; cleanup_and_exit 1; }
      tag_model_override="$2"
      generation_opts=true
      shift 2
      ;;
    -sm)
      [ $# -ge 2 ] || { echo "Missing argument for -sm" >&2; cleanup_and_exit 1; }
      style_model_override="$2"
      generation_opts=true
      shift 2
      ;;
    --describe-image)
      [ $# -ge 2 ] || { echo "Missing argument for --describe-image" >&2; cleanup_and_exit 1; }
      describe_image_file="$2"
      shift 2
      ;;
    --use)
      [ $# -ge 2 ] || { echo "Missing argument for --use" >&2; cleanup_and_exit 1; }
      case "$2" in
        group=*)
          reuse_group="${2#group=}"
          shift 2
          ;;
        *)
          echo "Invalid argument for --use" >&2
          cleanup_and_exit 1
          ;;
      esac
      ;;
    *)
      args+=("$1")
      shift
      ;;
  esac
done
set -- "${args[@]}"

while getopts ":p:t:s:rn:f:g:d:i:k:wvlhbx:m:u:" opt; do
  case "$opt" in
    p)
      prompt="$OPTARG"
      generation_opts=true
      ;;
    t)
      tag="$OPTARG"
      generation_opts=true
      tag_provided=true
      ;;
    s)
      style="$OPTARG"
      generation_opts=true
      style_provided=true
      ;;
    m)
      mood="$OPTARG"
      mood_provided=true
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
      if [ -n "${OPTARG:-}" ] && [ "${OPTARG:0:1}" != "-" ]; then
        favorite_group="$OPTARG"
        favorite_group_provided=true
      else
        favorite_group_provided=false
        [ -n "${OPTARG:-}" ] && OPTIND=$((OPTIND - 1))
      fi
      ;;
    g)
      gen_group="$OPTARG"
      gen_group_set=true
      ;;
    k)
      new_token="$OPTARG"
      ;;
    d)
      if [ -n "${OPTARG:-}" ] && [ "${OPTARG:0:1}" != "-" ]; then
        discovery_arg="$OPTARG"
      else
        discovery_arg="both"
        [ -n "${OPTARG:-}" ] && OPTIND=$((OPTIND - 1))
      fi
      ;;
    i)
      inspired_mode=true
      if [ -n "${OPTARG:-}" ] && [ "${OPTARG:0:1}" != "-" ]; then
        inspired_type="$OPTARG"
      else
        inspired_type="pair"
        [ -n "${OPTARG:-}" ] && OPTIND=$((OPTIND - 1))
      fi
      ;;
    w)
      weather_flag=true
      ;;
    x)
      force_generate=true
      if [ -n "${OPTARG:-}" ] && [ "${OPTARG:0:1}" != "-" ]; then
        batch_count="$OPTARG"
      else
        batch_count=1
        [ -n "${OPTARG:-}" ] && OPTIND=$((OPTIND - 1))
      fi
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
    u)
      reuse_mode="$OPTARG"
      ;;
    h)
      show_help
      cleanup_and_exit 0
      ;;
    :)
      case "$OPTARG" in
        f)
          favorite_wall=true
          favorite_group_provided=false
          ;;
        g)
          gen_group="main"
          ;;
        d)
          discovery_mode="both"
          ;;
        i)
          inspired_mode=true
          inspired_type="pair"
          ;;
        b)
          browse_gallery=true
      browse_group="main"
      ;;
      x)
        force_generate=true
        batch_count=1
        ;;
      *)
          echo "Usage: wallai.sh [options] - see -h for help" >&2
          cleanup_and_exit 1
          ;;
      esac
      ;;
    *)
      echo "Usage: wallai.sh [options] - see -h for help" >&2
      cleanup_and_exit 1
      ;;
  esac
done
shift $((OPTIND - 1))

# Extract weights from tag or style arguments if provided as name:weight
if [ "$tag_provided" = true ] && [[ "$tag" == *:* ]]; then
  weight_part="${tag##*:}"
  if printf '%s' "$weight_part" | grep -Eq '^[0-9]+(\.[0-9]+)?$'; then
    tag="${tag%:*}"
    tag_weight="$weight_part"
  fi
fi

if [ "$style_provided" = true ] && [[ "$style" == *:* ]]; then
  weight_part="${style##*:}"
  if printf '%s' "$weight_part" | grep -Eq '^[0-9]+(\.[0-9]+)?$'; then
    style="${style%:*}"
    style_weight="$weight_part"
  fi
fi

# Image argument handling
if [ -z "$describe_image_file" ] && [ $# -eq 1 ] && [ -f "$1" ]; then
  case "$1" in
    *.jpg|*.jpeg|*.png|*.webp|*.gif) describe_image_file="$1"; shift ;;
  esac
fi
# Parse discovery argument
if [ -n "$discovery_arg" ]; then
  case "$discovery_arg" in
    tag:*) discovery_mode="tag"; batch_tag_count=${discovery_arg#tag:} ;;
    style:*) discovery_mode="style"; batch_style_count=${discovery_arg#style:} ;;
    both:*) discovery_mode="both"; batch_tag_count=${discovery_arg#both:}; batch_style_count=$batch_tag_count ;;
    [0-9]*) discovery_mode="both"; batch_tag_count=$discovery_arg; batch_style_count=$discovery_arg ;;
    tag|style|both) discovery_mode="$discovery_arg" ;;
    *)
      echo "❌ Invalid discovery mode: $discovery_arg" >&2
      echo "Valid modes are: tag, style, or both" >&2
      cleanup_and_exit 1
      ;;
  esac
fi

# Adjust groups for favorites
if [ "$favorite_wall" = true ]; then
  if [ "$generation_opts" = false ] && [ "$gen_group_set" = false ]; then
    if [ "$favorite_group_provided" = true ]; then
      gen_group="$favorite_group"
    else
      favorite_group="main"
      gen_group="main"
    fi
  else
    [ "$favorite_group_provided" = false ] && favorite_group="$gen_group"
  fi
fi

# Default negative prompt if not provided
if [ -z "$negative_prompt" ]; then
  negative_prompt="blurry, low quality, deformed, disfigured, out of frame, low contrast, bad anatomy"
fi

# Load configuration and bootstrap defaults if needed
config_file="$HOME/.wallai/config.yml"
config_dir="$(dirname "$config_file")"
if [ ! -f "$config_file" ]; then
  mkdir -p "$config_dir"
  cat >"$config_file" <<'EOF'
api_providers:
  pollinations:
    base:
      text: ""
      image: "https://image.pollinations.ai"
    api_key: ""
    models:
      text: []
      image: ["flux", "flux-realism", "flux-anime", "flux-3d", "any-dark", "turbo"]
  openai:
    base:
      text: "https://api.openai.com/v1"
      image: "https://api.openai.com/v1"
    api_key: "your_openai_key"
    models:
      text: ["gpt-4o", "gpt-4o-mini", "gpt-3.5-turbo"]
      image: ["dall-e-3", "dall-e-2"]
  openrouter:
    base:
      text: "https://openrouter.ai/api/v1"
      image: "https://openrouter.ai/api/v1"
    api_key: ""
    models:
      text: ["mistralai/mistral-7b-instruct:free", "huggingface/meta-llama/llama-3.2-3b-instruct:free", "microsoft/phi-3-mini-128k-instruct:free", "qwen/qwen-2-7b-instruct:free", "google/gemma-2-9b-it:free", "meta-llama/llama-3.1-8b-instruct:free", "openchat/openchat-7b:free", "gryphe/mythomist-7b:free", "undi95/toppy-m-7b:free", "koboldai/psyfighter-13b-2:free"]
      image: []
defaults:
  image_model:
    provider: pollinations
    name: flux
  prompt_model:
    provider: openrouter
    name: mistralai/mistral-7b-instruct:free
  tag_model:
    provider: openrouter
    name: mistralai/mistral-7b-instruct:free
  style_model:
    provider: openrouter
    name: mistralai/mistral-7b-instruct:free
groups:
  main:
    image_model: flux
    prompt_model:
      base: mistralai/mistral-7b-instruct:free
      tag_model: mistralai/mistral-7b-instruct:free
      style_model: mistralai/mistral-7b-instruct:free
    favorites_path: ~/pictures/favorites/main
    generations_path: ~/pictures/generated-wallpapers/main
    nsfw: false
    tags: ["dreamcore", "mystical forest", "cosmic horror", "ethereal landscape", "retrofuturism", "alien architecture", "cyberpunk metropolis"]
    styles: ["unreal engine", "cinematic lighting", "octane render", "hyperrealism", "volumetric lighting", "high detail", "4k concept art"]
    moods: ["happy", "sad", "mysterious", "energetic", "peaceful"]
EOF
fi

# Cache config validation to avoid repeated Python calls
config_cache="$config_dir/.config_cache"
config_mtime=$(stat -c %Y "$config_file" 2>/dev/null || echo 0)
cache_valid=false
if [ -f "$config_cache" ]; then
  cached_mtime=$(cat "$config_cache" 2>/dev/null || echo 0)
  [ "$config_mtime" = "$cached_mtime" ] && cache_valid=true
fi

if [ "$cache_valid" = false ]; then
  # Validate YAML syntax with better error handling
  validation_error=$(python3 - "$config_file" 2>&1 <<'PY' || echo "VALIDATION_FAILED"
import sys, yaml
try:
    with open(sys.argv[1]) as f:
        yaml.safe_load(f)
except Exception as e:
    print(f"YAML Error: {e}", file=sys.stderr)
    sys.exit(1)
PY
)
  if [ "$validation_error" = "VALIDATION_FAILED" ] || echo "$validation_error" | grep -q "YAML Error:"; then
    echo "❌ Invalid config.yml format. Please check YAML syntax or run yamllint." >&2
    [ "$verbose" = true ] && echo "$validation_error" >&2
    cleanup_and_exit 1
  fi
  echo "$config_mtime" > "$config_cache"
fi

# Load provider defaults for new groups
config_json=$(CFG="$config_file" python3 - <<'PY'
import os,sys,json
import yaml
with open(os.environ['CFG']) as f:
    data = yaml.safe_load(f) or {}
json.dump(data, sys.stdout)
PY
)
default_text_model=$(printf '%s' "$config_json" | jq -r '.defaults.models.text')
default_image_model=$(printf '%s' "$config_json" | jq -r '.defaults.models.image')

# Ensure the selected generation group exists with default settings
ensure_group() {
  local group="$1"
  python3 - "$config_file" "$group" <<'PY'
import sys, yaml, os
cfg, group = sys.argv[1:3]
data = {}
if os.path.exists(cfg):
    with open(cfg) as f:
        data = yaml.safe_load(f) or {}
groups = data.setdefault('groups', {})
new = group not in groups
grp = groups.setdefault(group, {})

def def_env(key, default=None):
    val = os.environ.get(key)
    return val if val else default

defaults = {
    'provider_token': '',
    'image_model': def_env('DEF_IMAGE_MODEL', 'flux'),
    'prompt_model': {
        'base': def_env('DEF_PROMPT_MODEL', 'mistral'),
        'tag_model': def_env('DEF_TAG_MODEL') or def_env('DEF_PROMPT_MODEL', 'mistral'),
        'style_model': def_env('DEF_STYLE_MODEL') or def_env('DEF_PROMPT_MODEL', 'mistral'),
    },
    'favorites_path': f'~/pictures/favorites/{group}',
    'generations_path': f'~/pictures/generated-wallpapers/{group}',
    'nsfw': False if group == 'main' else True,
    'tags': [def_env('DEF_TAG')] if new and def_env('DEF_TAG') else [
        'dreamcore', 'mystical forest', 'cosmic horror',
        'ethereal landscape', 'retrofuturism', 'alien architecture',
        'cyberpunk metropolis'
    ],
    'styles': [def_env('DEF_STYLE')] if new and def_env('DEF_STYLE') else [
        'unreal engine', 'cinematic lighting', 'octane render',
        'hyperrealism', 'volumetric lighting', 'high detail',
        '4k concept art'
    ],
    'moods': []
}

updated = False
if new:
    for k, v in defaults.items():
        grp[k] = v
        updated = True
else:
    for k, v in defaults.items():
        if k not in grp:
            grp[k] = v
            updated = True

if updated:
    with open(cfg, 'w') as f:
        yaml.safe_dump(data, f, sort_keys=False)
print('1' if new else '0')
PY
}

DEF_IMAGE_MODEL="${model:-$default_image_model}"
DEF_PROMPT_MODEL="${prompt_model_override:-$default_text_model}"
DEF_TAG_MODEL="${tag_model_override:-$default_text_model}"
DEF_STYLE_MODEL="${style_model_override:-$default_text_model}"
[ "$tag_provided" = true ] && DEF_TAG="$tag" || DEF_TAG=""
[ "$style_provided" = true ] && DEF_STYLE="$style" || DEF_STYLE=""
DEF_IMAGE_MODEL="$DEF_IMAGE_MODEL" \
DEF_PROMPT_MODEL="$DEF_PROMPT_MODEL" \
DEF_TAG_MODEL="$DEF_TAG_MODEL" \
DEF_STYLE_MODEL="$DEF_STYLE_MODEL" \
DEF_TAG="$DEF_TAG" \
DEF_STYLE="$DEF_STYLE" \
group_created=$(ensure_group "$gen_group")

set_config_value() {
  local group="$1" key="$2" value="$3"
  python3 - "$config_file" "$group" "$key" "$value" <<'PY'
import sys, yaml, os
cfg, group, key, value = sys.argv[1:]
data = {}
if os.path.exists(cfg):
    with open(cfg) as f:
        data = yaml.safe_load(f) or {}
grp = data.setdefault('groups', {}).setdefault(group, {})
d = grp
parts = key.split('.')
for p in parts[:-1]:
    d = d.setdefault(p, {})
d[parts[-1]] = value
with open(cfg, 'w') as f:
    yaml.safe_dump(data, f, sort_keys=False)
PY
}

if [ "$group_created" = "1" ]; then
  [ -n "$tag_model_override" ] && \
    set_config_value "$gen_group" "prompt_model.tag_model" "$tag_model_override"
  [ -n "$style_model_override" ] && \
    set_config_value "$gen_group" "prompt_model.style_model" "$style_model_override"
  [ -n "$prompt_model_override" ] && \
    set_config_value "$gen_group" "prompt_model.base" "$prompt_model_override"
fi

# Cache parsed config JSON to avoid repeated YAML parsing
config_json_cache="$config_dir/.config_json_cache"
if [ "$cache_valid" = false ] || [ ! -f "$config_json_cache" ]; then
  config_json=$(CFG="$config_file" python3 - <<'PY'
import os,sys,json
import yaml
with open(os.environ['CFG']) as f:
    data = yaml.safe_load(f) or {}
json.dump(data, sys.stdout)
PY
)
  printf '%s' "$config_json" > "$config_json_cache"
else
  config_json=$(cat "$config_json_cache")
fi

# Global API provider defaults
text_provider=$(printf '%s' "$config_json" | jq -r '.defaults.prompt_model.provider // "pollinations"')
image_provider=$(printf '%s' "$config_json" | jq -r '.defaults.image_model.provider // "pollinations"')
text_api_base=$(printf '%s' "$config_json" | jq -r --arg p "$text_provider" '.api_providers[$p].base.text // .api_providers[$p].text_base // .api_providers[$p].base // empty')
image_api_base=$(printf '%s' "$config_json" | jq -r --arg p "$image_provider" '.api_providers[$p].base.image // .api_providers[$p].image_base // .api_providers[$p].base // empty')
api_key_text=$(printf '%s' "$config_json" | jq -r --arg p "$text_provider" '.api_providers[$p].api_key // empty')
api_key_image=$(printf '%s' "$config_json" | jq -r --arg p "$image_provider" '.api_providers[$p].api_key // empty')
openai_text_model=$(printf '%s' "$config_json" | jq -r '.defaults.prompt_model.name // .defaults.prompt_model // "qwen2.5-72b-instruct"')
openai_image_model=$(printf '%s' "$config_json" | jq -r '.defaults.image_model.name // .defaults.image_model // "flux"')
provider="$text_provider"

mapfile -t provider_text_models < <(printf '%s' "$config_json" | jq -r --arg p "$text_provider" '.api_providers[$p].models.text[]?')
mapfile -t provider_image_models < <(printf '%s' "$config_json" | jq -r --arg p "$image_provider" '.api_providers[$p].models.image[]?')

valid_text=false
valid_image=false
if printf '%s' "$config_json" | jq -e --arg p "$text_provider" --arg m "$openai_text_model" '.api_providers[$p].models.text | index($m)' >/dev/null; then
  valid_text=true
fi
if printf '%s' "$config_json" | jq -e --arg p "$image_provider" --arg m "$openai_image_model" '.api_providers[$p].models.image | index($m)' >/dev/null; then
  valid_image=true
fi

if [ -z "$text_api_base" ] || [ -z "$image_api_base" ] || [ "$valid_text" = false ] || [ "$valid_image" = false ]; then
  echo "❌ Invalid provider or default models in config" >&2
  cleanup_and_exit 1
fi

auth_header_text=()
[ -n "$api_key_text" ] && [ "$api_key_text" != "your_openai_key" ] && [ "$api_key_text" != "your_openrouter_key" ] && auth_header_text=(-H "Authorization: Bearer $api_key_text")
auth_header_image=()
[ -n "$api_key_image" ] && [ "$api_key_image" != "your_openai_key" ] && [ "$api_key_image" != "your_openrouter_key" ] && auth_header_image=(-H "Authorization: Bearer $api_key_image")

# Optional provider token for the current group
provider_token=$(printf '%s' "$config_json" | jq -r --arg g "$gen_group" '.groups[$g].provider_token // ""')

# Update token in config if -k was provided
if [ -n "$new_token" ]; then
  provider_token="$new_token"
  python3 - "$config_file" "$gen_group" "$provider_token" <<'PY'
import sys, yaml, os
cfg, group, token = sys.argv[1:]
data = {}
if os.path.exists(cfg):
    with open(cfg) as f:
        data = yaml.safe_load(f) or {}
grp = data.setdefault('groups', {}).setdefault(group, {})
grp['provider_token'] = token
with open(cfg, 'w') as f:
    yaml.safe_dump(data, f, sort_keys=False)
PY
  config_json=$(printf '%s' "$config_json" | jq --arg g "$gen_group" --arg t "$provider_token" '
    (.groups[$g] //= {}) |
    .groups[$g].provider_token=$t
  ')
fi

# Use provider token only if available for the current group
curl_auth_text=("${auth_header_text[@]}")
curl_auth_image=("${auth_header_image[@]}")
if [ -n "$provider_token" ]; then
  curl_auth_text+=(-H "Authorization: Bearer $provider_token")
  curl_auth_image+=(-H "Authorization: Bearer $provider_token")
  echo "🔑 Using provider token for group: $gen_group"
fi

# If an image is provided for description, fetch a caption prompt
if [ -n "$describe_image_file" ]; then
  [ -f "$describe_image_file" ] || { echo "❌ Image file not found: $describe_image_file" >&2; cleanup_and_exit 1; }
  mime_type=$(file -b --mime-type "$describe_image_file" 2>/dev/null || echo "image/png")
  img_b64=$(base64 -w0 "$describe_image_file" 2>/dev/null)
  data_url="data:${mime_type};base64,${img_b64}"
  payload=$(jq -n --arg model "$openai_text_model" --arg url "$data_url" '{model:$model,messages:[{role:"user",content:[{type:"text",content:"Describe this image in a short wallpaper prompt"},{type:"image_url",image_url:{url:$url}}]}]}')
  caption=$(curl -sL "${curl_auth_text[@]}" -H "Content-Type: application/json" -d "$payload" "$text_api_base/chat/completions" | jq -r '.choices[0].message.content' 2>/dev/null)
  if [ -z "$caption" ]; then
    echo "❌ Failed to describe image" >&2
    cleanup_and_exit 1
  fi
  prompt="$caption"
  generation_opts=true
fi

# Cache frequently used config values to avoid repeated jq calls
declare -A config_cache_values

cfg() {
  local key="$1|$2"
  if [ -z "${config_cache_values[$key]:-}" ]; then
    config_cache_values[$key]=$(printf '%s' "$config_json" | jq -r --arg g "$1" "$2" 2>/dev/null)
  fi
  printf '%s' "${config_cache_values[$key]}"
}

# Batch fetch all generation group settings in one jq call for efficiency
group_config=$(printf '%s' "$config_json" | jq -r --arg g "$gen_group" '
  .groups[$g] as $grp |
  {
    gen_path: ($grp.generations_path // ""),
    fav_path: ($grp.favorites_path // $grp.path // ""),
    nsfw: ($grp.nsfw // false),
    prompt_model: ($grp.prompt_model.base // $grp.prompt_model // "mistral"),
    tag_model: ($grp.prompt_model.tag_model // $grp.tag_model // ""),
    style_model: ($grp.prompt_model.style_model // $grp.style_model // ""),
    image_model: ($grp.image_model // "flux"),
    tags: [$grp.tags[]? | if type=="string" then . else keys[0] end],
    tag_weights: [$grp.tags[]? | if type=="string" then 1.5 else .[keys[0]] end],
    styles: [$grp.styles[]? | if type=="string" then . else keys[0] end],
    style_weights: [$grp.styles[]? | if type=="string" then 1.3 else .[keys[0]] end],
    moods: [$grp.moods[]?]
  }
' 2>/dev/null)

gen_gen_path=$(printf '%s' "$group_config" | jq -r '.gen_path')
[ -z "$gen_gen_path" ] && gen_gen_path="$HOME/pictures/generated-wallpapers/$gen_group"
gen_gen_path=$(eval printf '%s' "$gen_gen_path")

gen_fav_path=$(printf '%s' "$group_config" | jq -r '.fav_path')
[ -z "$gen_fav_path" ] && gen_fav_path="$HOME/pictures/favorites/$gen_group"
gen_fav_path=$(eval printf '%s' "$gen_fav_path")

gen_nsfw=$(printf '%s' "$group_config" | jq -r '.nsfw')
gen_prompt_model=$(printf '%s' "$group_config" | jq -r '.prompt_model')
gen_tag_model=$(printf '%s' "$group_config" | jq -r '.tag_model')
gen_style_model=$(printf '%s' "$group_config" | jq -r '.style_model')
gen_image_model=$(printf '%s' "$group_config" | jq -r '.image_model')
mapfile -t gen_tags < <(printf '%s' "$group_config" | jq -r '.tags[]?')
mapfile -t gen_tag_weights < <(printf '%s' "$group_config" | jq -r '.tag_weights[]?')
mapfile -t gen_styles < <(printf '%s' "$group_config" | jq -r '.styles[]?')
mapfile -t gen_style_weights < <(printf '%s' "$group_config" | jq -r '.style_weights[]?')
mapfile -t gen_moods < <(printf '%s' "$group_config" | jq -r '.moods[]?')

# Batch fetch favorite and inspired paths
if [ "$favorite_group" != "$gen_group" ]; then
  fav_path=$(printf '%s' "$config_json" | jq -r --arg g "$favorite_group" '.groups[$g].favorites_path // .groups[$g].path // ""')
  [ -z "$fav_path" ] && fav_path="$HOME/pictures/favorites/$favorite_group"
  fav_path=$(eval printf '%s' "$fav_path")
else
  fav_path="$gen_fav_path"
fi

insp_path="$gen_fav_path"

# Apply config defaults if flags were not provided
[ -z "$model" ] && model="${gen_image_model:-$openai_image_model}"
[ -n "$prompt_model_override" ] && gen_prompt_model="$prompt_model_override"
tag_model="${tag_model_override:-${gen_tag_model:-$gen_prompt_model}}"
style_model="${style_model_override:-${gen_style_model:-$gen_prompt_model}}"

# Append a discovered item to the group's config list if missing
append_config_item() {
  local group="$1" list="$2" item="$3"
  python3 - "$config_file" "$group" "$list" "$item" <<'PY'
import sys, yaml, os
cfg, group, list_name, item = sys.argv[1:]
data = {}
if os.path.exists(cfg):
    with open(cfg) as f:
        data = yaml.safe_load(f) or {}
grp = data.setdefault('groups', {}).setdefault(group, {})
lst = grp.setdefault(list_name, [])
item_lower = item.lower()

def norm(x):
    if isinstance(x, str):
        return x.lower()
    if isinstance(x, dict) and x:
        return next(iter(x)).lower()
    return str(x).lower()

if item_lower not in [norm(i) for i in lst]:
    lst.append(item)
    with open(cfg, 'w') as f:
        yaml.safe_dump(data, f, sort_keys=False)
PY
}

# Overwrite the group's list with a single item
set_config_list() {
  local group="$1" list="$2" item="$3"
  python3 - "$config_file" "$group" "$list" "$item" <<'PY'
import sys, yaml, os
cfg, group, list_name, item = sys.argv[1:]
data = {}
if os.path.exists(cfg):
    with open(cfg) as f:
        data = yaml.safe_load(f) or {}
grp = data.setdefault('groups', {}).setdefault(group, {})
grp[list_name] = [item]
with open(cfg, 'w') as f:
  yaml.safe_dump(data, f, sort_keys=False)
PY
}

# Set a nested value in the group's config
# Add user provided tag and style to config
[ "$tag_provided" = true ] && append_config_item "$gen_group" "tags" "$tag"
[ "$style_provided" = true ] && append_config_item "$gen_group" "styles" "$style"
[ "$mood_provided" = true ] && append_config_item "$gen_group" "moods" "$mood"

# Discover new tag or style via API
discover_item() {
  local kind="$1" count="${2:-1}" query result dseed m url item lower_item exists list
  if [ "$count" -gt 1 ]; then
    case "$kind" in
      tag)
        query="Give me ${count} unique wallpaper tags, each 1 to 3 words, in a comma-separated list."
        ;;
      style)
        query="Give me ${count} unique art styles for digital wallpapers, each 1 to 3 words, in a comma-separated list."
        ;;
      *)
        return
        ;;
    esac
  else
    case "$kind" in
      tag)
        if [ -n "$top_tag" ]; then
          [ "$verbose" = true ] && echo "🎯 Influencing discovery using top tag: $top_tag" >&2
          query="Give me a two-word tag similar to: $top_tag. Respond with one new two-word tag."
        else
          list=$(printf '%s, ' "${gen_tags[@]}" | sed 's/, $//')
          query="Imagine a two-word tag not including any of: ${list}. Respond with exactly two words."
        fi
        ;;
      style)
        if [ -n "$top_style" ]; then
          [ "$verbose" = true ] && echo "🎨 Influencing discovery using top style: $top_style" >&2
          query="Give me a two-word art style similar to: $top_style. Respond with one new two-word style."
        else
          list=$(printf '%s, ' "${gen_styles[@]}" | sed 's/, $//')
          query="Imagine a two-word art style not including any of: ${list}. Respond with exactly two words."
        fi
        ;;
      *)
        return
        ;;
    esac
  fi
  payload=$(jq -n --arg model "$openai_text_model" --arg prompt "$query" '{model:$model,messages:[{role:"user",content:$prompt}]}')
  [ "$verbose" = true ] && echo "🔍 Discover via $provider" >&2
  result=$(curl -sL "${curl_auth_text[@]}" -H "Content-Type: application/json" -d "$payload" "$text_api_base/chat/completions" | jq -r '.choices[0].message.content // empty' 2>/dev/null)
  [ "$verbose" = true ] && echo "🔍 Response: $result" >&2
  
  # Check if result is null, empty, or just whitespace
  if [ -z "$result" ] || [ "$result" = "null" ] || [ -z "$(printf '%s' "$result" | tr -d '[:space:]')" ]; then
    [ "$verbose" = true ] && echo "❌ API returned null/empty response, using fallback" >&2
    # Use fallback discovery based on existing items
    case "$kind" in
      tag)
        fallback_tags=("liminal space" "vaporwave" "dark academia" "cottagecore" "weirdcore" "backrooms" "synthwave" "steampunk" "biopunk" "solarpunk")
        ;;
      style)
        fallback_styles=("matte painting" "digital art" "oil painting" "watercolor" "pencil sketch" "vector art" "pixel art" "low poly" "isometric" "minimalist")
        ;;
    esac
    if [ "$kind" = "tag" ]; then
      printf '%s\n' "${fallback_tags[@]}" | shuf -n"${count:-1}"
    else
      printf '%s\n' "${fallback_styles[@]}" | shuf -n"${count:-1}"
    fi
    return
  fi
  
  result=$(printf '%s' "$result" | tr '\n' ' ' | sed 's/  */ /g; s/^ //; s/ $//')
  if [ "$count" -gt 1 ]; then
    printf '%s' "$result" | tr ',' '\n' | sed 's/^ *//; s/ *$//' | tr '[:upper:]' '[:lower:]' |
      awk 'NF>=1 && NF<=3' | sed 's/  */ /g' | while read -r item; do
        exists=false
        if [ "$kind" = "tag" ]; then
          for i in "${gen_tags[@]}"; do
            if [ "$(printf '%s' "$i" | tr "[:upper:]" "[:lower:]")" = "$item" ]; then
              exists=true
              break
            fi
          done
        else
          for i in "${gen_styles[@]}"; do
            if [ "$(printf '%s' "$i" | tr "[:upper:]" "[:lower:]")" = "$item" ]; then
              exists=true
              break
            fi
          done
        fi
        [ "$exists" = false ] && echo "$item"
      done | awk '!seen[$0]++'
  else
    if [ -n "$result" ]; then
      item=$(printf '%s' "$result" | awk '{print $1, $2}')
      lower_item=$(printf '%s' "$item" | tr '[:upper:]' '[:lower:]')
      exists=false
      if [ "$kind" = "tag" ]; then
        for i in "${gen_tags[@]}"; do
          if [ "$(printf '%s' "$i" | tr '[:upper:]' '[:lower:]')" = "$lower_item" ]; then
            exists=true
            break
          fi
        done
      else
        for i in "${gen_styles[@]}"; do
          if [ "$(printf '%s' "$i" | tr '[:upper:]' '[:lower:]')" = "$lower_item" ]; then
            exists=true
            break
          fi
        done
      fi
      [ "$exists" = false ] && printf '%s\n' "$item"
    fi
  fi
}


# Directory where generated wallpapers live and log path
save_dir="$gen_gen_path"
mkdir -p "$save_dir"
log_file="$save_dir/wallai.log"
# Global log that records wallpapers across all groups
main_log="$HOME/.wallai/wallai.log"
mkdir -p "$(dirname "$main_log")"

# Generate a short random seed - cache /dev/urandom reads
random_seed() {
  if [ -z "${_random_cache:-}" ]; then
    _random_cache=$(od -vN16 -An -tx4 /dev/urandom | tr -d ' \n')
    _random_pos=0
  fi
  if [ "$_random_pos" -ge 32 ] || [ "$_random_pos" -ge "${#_random_cache}" ]; then
    _random_cache=$(od -vN16 -An -tx4 /dev/urandom | tr -d ' \n')
    _random_pos=0
  fi
  # Ensure we don't exceed string bounds
  cache_len="${#_random_cache}"
  if [ "$cache_len" -gt 0 ] && [ $((_random_pos + 8)) -le "$cache_len" ]; then
    # Use cut to extract substring more reliably
    end_pos=$((_random_pos + 8))
    if [ "$end_pos" -le "$cache_len" ]; then
      printf '%s' "$_random_cache" | cut -c$((_random_pos + 1))-"$end_pos"
      _random_pos="$end_pos"
    else
      # Fallback to direct random generation
      od -vN4 -An -tx4 /dev/urandom | tr -d ' \n'
    fi
  else
    # Fallback to direct random generation
    od -vN4 -An -tx4 /dev/urandom | tr -d ' \n'
  fi
}

# Browse existing wallpapers and optionally favorite them

# Seed for image generation and prompt fetch
seed=$(random_seed)
prompt_seed=""
tag_seed=""
style_seed=""

if [ "$mood_provided" = true ] && [ "$verbose" = true ]; then
  echo "😌 Using mood: $mood"
fi

# Apply tag/style from the last generated image if -l is used
if [ "$use_last" = true ]; then
  last_entry=$(tail -n1 "$main_log" 2>/dev/null || true)
  if [ -z "$last_entry" ]; then
    echo "❌ No wallpaper has been generated yet" >&2
    cleanup_and_exit 1
  fi
  fields=$(printf '%s' "$last_entry" | awk -F'|' '{print NF}')
  if [ "$fields" -ge 7 ]; then
    last_file=$(printf '%s' "$last_entry" | cut -d'|' -f2)
  else
    last_file=$(printf '%s' "$last_entry" | cut -d'|' -f1)
  fi
  tag_slug=$(printf '%s' "$last_file" | cut -d'_' -f2)
  style_slug=$(printf '%s' "$last_file" | cut -d'_' -f3 | sed 's/\..*//')
  last_tag=$(printf '%s' "$tag_slug" | sed 's/-/ /g')
  last_style=$(printf '%s' "$style_slug" | sed 's/-/ /g')
  [ -z "$tag" ] && tag="$last_tag"
  [ -z "$style" ] && style="$last_style"
fi

# Convert strings like "Cyberpunk Metropolis" to "cyberpunk-metropolis"
# Cache slugified results to avoid repeated processing
declare -A slug_cache
slugify() {
  if [ -z "${slug_cache[$1]:-}" ]; then
    slug_cache[$1]=$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | \
      sed 's/[^a-z0-9]/-/g; s/--*/-/g; s/^-//; s/-$//')
  fi
  printf '%s' "${slug_cache[$1]}"
}

# Clamp a weight to the range 1.1-2.0
clamp_weight() {
  awk -v w="$1" 'BEGIN{w+=0; if(w<1.1)w=1.1; if(w>2.0)w=2.0; printf "%.1f", w}'
}

# Find the weight for a tag from config or return default
find_tag_weight() {
  local name="$1" default="${2:-1.5}" i
  for i in "${!gen_tags[@]}"; do
    if [ "${gen_tags[i]}" = "$name" ]; then
      printf '%s' "${gen_tag_weights[i]}"
      return
    fi
  done
  printf '%s' "$default"
}

# Find the weight for a style from config or return default
find_style_weight() {
  local name="$1" default="${2:-1.3}" i
  for i in "${!gen_styles[@]}"; do
    if [ "${gen_styles[i]}" = "$name" ]; then
      printf '%s' "${gen_style_weights[i]}"
      return
    fi
  done
  printf '%s' "$default"
}

# Function to favorite the most recent wallpaper with metadata using exiftool
favorite_image() {
  command -v exiftool >/dev/null 2>&1 || {
    echo "❌ exiftool is required for -f" >&2
    return 1
  }
  local file="$1" comment="$2" tag="$3" style="$4" mood="$5" model="$6" seed="$7" ts="$8" group_path="$9" group_name="${10}"
  local dest_dir="$group_path"
  local log="$dest_dir/favorites.jsonl"
  mkdir -p "$dest_dir"
  local dest
  dest="$dest_dir/$(basename "$file")"
  cp "$file" "$dest"
  exiftool -overwrite_original -Comment="$comment" "$dest" >/dev/null
  jq -n --arg prompt "$comment" --arg tag "$tag" --arg style "$style" \
        --arg mood "$mood" --arg model "$model" --arg seed "$seed" --arg ts "$ts" \
        --arg filename "$(basename "$dest")" \
        '{prompt:$prompt, tag:$tag, style:$style, mood:$mood, model:$model, seed:$seed, timestamp:$ts, filename:$filename}' >> "$log"
  echo "⭐ Added to favorites: $dest"
  append_config_item "$group_name" "tags" "$tag"
  append_config_item "$group_name" "styles" "$style"
  [ -n "$mood" ] && append_config_item "$group_name" "moods" "$mood"
}

# Browse existing wallpapers and optionally favorite them
# shellcheck disable=SC2317
browse_gallery() {
  local fav_group="$1" list result sel decision group_list gsel gsel_val
  for cmd in jq; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      echo "❌ Required command '$cmd' is not installed" >&2
      return 1
    fi
  done
  
  # Check for termux-specific commands but don't fail if missing
  has_termux_dialog=false
  has_termux_open=false
  if command -v termux-dialog >/dev/null 2>&1; then
    has_termux_dialog=true
  fi
  if command -v termux-open >/dev/null 2>&1; then
    has_termux_open=true
  fi
  
  if [ "$has_termux_dialog" = false ] || [ "$has_termux_open" = false ]; then
    echo "❌ Browse gallery requires termux-dialog and termux-open (Termux environment)" >&2
    return 1
  fi
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
grp=data.get('groups', {}).get(g, {})
print(os.path.expanduser(grp.get('favorites_path', grp.get('path',''))))
PY
    )
    [ -n "$cfg_path" ] && dest_path="$cfg_path"
  fi
  entry=$(grep "^$sel|" "$log_file" 2>/dev/null || true)
  if [ -n "$entry" ]; then
    seed=$(printf '%s' "$entry" | cut -d'|' -f2)
    prompt=$(printf '%s' "$entry" | cut -d'|' -f3)
    tag=$(printf '%s' "$sel" | cut -d'_' -f2 | sed 's/-/ /g')
    style=$(printf '%s' "$sel" | cut -d'_' -f3 | sed 's/\..*//' | sed 's/-/ /g')
    ts=$(printf '%s' "$sel" | cut -d'_' -f1)
    favorite_image "$save_dir/$sel" "$prompt (seed: $seed)" "$tag" "$style" "" "unknown" "$seed" "$ts" "$dest_path" "$fav_group"
  else
    mkdir -p "$dest_path"
    cp "$save_dir/$sel" "$dest_path/" && echo "⭐ Added to favorites: $dest_path/$sel"
  fi
}

# Open gallery if requested
if [ "$browse_gallery" = true ]; then
  browse_gallery "$browse_group"
  cleanup_and_exit 0
fi

# Spinner that cycles through emojis while a command runs
spinner() {
  local pid=$1 msg="${2:-Generating image}"
  local emojis=("🎨" "🧠" "✨" "🖼️" "🌀")
  local i=0
  tput civis 2>/dev/null || true
  while kill -0 "$pid" 2>/dev/null; do
    printf "\r%s %s..." "${emojis[i]}" "$msg"
    i=$(( (i + 1) % ${#emojis[@]} ))
    sleep 0.5
  done
  tput cnorm 2>/dev/null || true
  printf "\r\033[K\n"
}

# Spinner that tracks multiple PIDs
spinner_multi() {
  local msg="$1"
  shift
  local pids=("$@")
  local emojis=("🎨" "🧠" "✨" "🖼️" "🌀")
  local i=0
  tput civis 2>/dev/null || true
  while :; do
    local running=false
    for pid in "${pids[@]}"; do
      if kill -0 "$pid" 2>/dev/null; then
        running=true
        break
      fi
    done
    [ "$running" = false ] && break
    printf "\r%s %s..." "${emojis[i]}" "$msg"
    i=$(( (i + 1) % ${#emojis[@]} ))
    sleep 0.5
  done
  tput cnorm 2>/dev/null || true
  printf "\r\033[K\n"
}

# If called only with -f, favorite the last generated wallpaper and exit early
if [ "$favorite_wall" = true ] && [ "$generation_opts" = false ] && [ "$gen_group_set" = false ]; then
  last_entry=$(tail -n1 "$main_log" 2>/dev/null || true)
  if [ -z "$last_entry" ]; then
    echo "❌ No wallpaper has been generated yet" >&2
    cleanup_and_exit 1
  fi
  fields=$(printf '%s' "$last_entry" | awk -F'|' '{print NF}')
  if [ "$fields" -ge 7 ]; then
    last_group=$(printf '%s' "$last_entry" | cut -d'|' -f1)
    last_file=$(printf '%s' "$last_entry" | cut -d'|' -f2)
    last_seed=$(printf '%s' "$last_entry" | cut -d'|' -f3)
    last_prompt=$(printf '%s' "$last_entry" | cut -d'|' -f4)
  else
    last_group="main"
    last_file=$(printf '%s' "$last_entry" | cut -d'|' -f1)
    last_seed=$(printf '%s' "$last_entry" | cut -d'|' -f2)
    last_prompt=$(printf '%s' "$last_entry" | cut -d'|' -f3)
  fi
  last_gen_path=$(cfg "$last_group" '.groups[$g].generations_path // empty')
  [ -z "$last_gen_path" ] && last_gen_path="$HOME/pictures/generated-wallpapers/$last_group"
  last_gen_path=$(eval printf '%s' "$last_gen_path")
  ts=$(printf '%s' "$last_file" | cut -d'_' -f1)
  tag_slug=$(printf '%s' "$last_file" | cut -d'_' -f2)
  style_slug=$(printf '%s' "$last_file" | cut -d'_' -f3 | sed 's/\..*//')
  last_tag=$(printf '%s' "$tag_slug" | sed 's/-/ /g')
  last_style=$(printf '%s' "$style_slug" | sed 's/-/ /g')
  favorite_image "$last_gen_path/$last_file" "$last_prompt (seed: $last_seed)" "$last_tag" "$last_style" "" "unknown" "$last_seed" "$ts" "$fav_path" "$favorite_group"
  cleanup_and_exit 0
fi

# Reuse a previous wallpaper and exit early
if [ -n "$reuse_mode" ]; then
  case "$reuse_mode" in
    latest|random|favorites) ;;
    *) echo "Invalid reuse mode: $reuse_mode" >&2; cleanup_and_exit 1 ;;
  esac
  file=""
  source_desc="$reuse_mode"
  target_group="$gen_group"
  [ -n "$reuse_group" ] && target_group="$reuse_group"
  if [ "$reuse_mode" = "favorites" ]; then
    fav_path=$(cfg "$target_group" '.groups[$g].favorites_path // .groups[$g].path // empty')
    [ -z "$fav_path" ] && fav_path="$HOME/pictures/favorites/$target_group"
    fav_path=$(eval printf '%s' "$fav_path")
    file=$(find "$fav_path" -type f \( -name '*.jpg' -o -name '*.png' -o -name '*.jpeg' \) 2>/dev/null | shuf -n1)
    [ -n "$file" ] || { echo "❌ No favorites found" >&2; cleanup_and_exit 1; }
  else
    if [ "$reuse_mode" = "latest" ]; then
      if [ "$target_group" = "main" ]; then
        entry=$(tail -n1 "$main_log" 2>/dev/null || true)
      else
        entry=$(grep "^$target_group|" "$main_log" | tail -n1)
      fi
    else
      if [ "$target_group" = "main" ]; then
        entry=$(shuf -n1 "$main_log" 2>/dev/null || true)
      else
        entry=$(grep "^$target_group|" "$main_log" | shuf -n1)
      fi
    fi
    [ -n "$entry" ] || { echo "❌ No wallpaper found" >&2; cleanup_and_exit 1; }
    fields=$(printf '%s' "$entry" | awk -F'|' '{print NF}')
    if [ "$fields" -ge 7 ]; then
      group=$(printf '%s' "$entry" | cut -d'|' -f1)
      fname=$(printf '%s' "$entry" | cut -d'|' -f2)
    else
      group="main"
      fname=$(printf '%s' "$entry" | cut -d'|' -f1)
    fi
    path=$(cfg "$group" '.groups[$g].generations_path // empty')
    [ -z "$path" ] && path="$HOME/pictures/generated-wallpapers/$group"
    path=$(eval printf '%s' "$path")
    file="$path/$fname"
  fi
  if [ "$has_termux_wallpaper" = true ]; then
    termux-wallpaper -f "$file"
    echo "🎉 Reused wallpaper: $(basename "$file") (source: $source_desc, group: $target_group)"
  else
    echo "🎉 Would reuse wallpaper: $(basename "$file") (source: $source_desc, group: $target_group)"
    echo "ℹ️  termux-wallpaper not available - wallpaper not set automatically"
  fi
  cleanup_and_exit 0
fi

# Inspired mode selects tag and style based on past favorites
if [ "$inspired_mode" = true ]; then
  fav_file="$insp_path/favorites.jsonl"
  if [ -f "$fav_file" ]; then
    IFS=$'\n' read -r top_tag tag_weight top_style style_weight < <(
      python3 - "$fav_file" "$inspired_type" <<'PY'
import sys, json, random
file, mode = sys.argv[1:3]
pairs, tcounts, scounts = {}, {}, {}
with open(file) as f:
    for line in f:
        try:
            j = json.loads(line)
        except Exception:
            continue
        t = j.get('tag')
        s = j.get('style')
        if t:
            tcounts[t] = tcounts.get(t, 0) + 1
        if s:
            scounts[s] = scounts.get(s, 0) + 1
        if t and s:
            pairs[(t, s)] = pairs.get((t, s), 0) + 1

def choose(counts):
    items = list(counts.keys())
    weights = [counts[i] for i in items]
    return random.choices(items, weights=weights)[0]

def weight(item, counts):
    if not counts:
        return 1.1
    mx = max(counts.values())
    freq = counts.get(item, 0)
    w = 1.1 + (freq / mx) * (2.0 - 1.1)
    return round(max(1.1, min(2.0, w)), 1)

tag = style = None
if mode == 'pair' and pairs:
    tag, style = choose(pairs)
elif mode == 'tag' and tcounts:
    tag = choose(tcounts)
elif mode == 'style' and scounts:
    style = choose(scounts)

tw = weight(tag, tcounts) if tag else ''
sw = weight(style, scounts) if style else ''
print(tag or '')
print(tw)
print(style or '')
print(sw)
PY
    )
    tag_weight=${tag_weight:-1.5}
    style_weight=${style_weight:-1.3}
    [ -n "$tag" ] || tag="$top_tag"
    [ -n "$style" ] || style="$top_style"
    echo "🧠 Inspired by favorites (mode: $inspired_type)"
    [ -n "$top_tag" ] && printf '🔖 Tag: %s (weight: %s)\n' "$top_tag" "$tag_weight"
    [ -n "$top_style" ] && printf '🎨 Style: %s (weight: %s)\n' "$top_style" "$style_weight"
    if [ "$mood_provided" = false ]; then
      mood=$(jq -r --arg tag "$tag" --arg style "$style" --arg mode "$inspired_type" '
        select(.mood) |
        if $mode=="pair" then select(.tag==$tag and .style==$style)
        elif $mode=="tag" then select(.tag==$tag)
        elif $mode=="style" then select(.style==$style)
        else empty end |
        .mood' "$fav_file" 2>/dev/null | sort | uniq -c | sort -nr | head -n1 | awk '{print $2}')
      if [ -z "$mood" ] && [ "${#gen_moods[@]}" -gt 0 ]; then
        mood=$(printf '%s\n' "${gen_moods[@]}" | shuf -n1)
      fi
      [ -n "$mood" ] && echo "😌 Mood inferred: $mood"
    fi
  fi
fi

# Discovery mode for new tags or styles
discovered_tags=()
discovered_styles=()
if [ -n "$discovery_mode" ]; then
  tmpd=$(mktemp -d)
  pids=()
  if [ "$discovery_mode" = "both" ] || [ "$discovery_mode" = "tag" ]; then
    discover_item tag "$batch_tag_count" >"$tmpd/tag" &
    pids+=("$!")
  fi
  if [ "$discovery_mode" = "both" ] || [ "$discovery_mode" = "style" ]; then
    discover_item style "$batch_style_count" >"$tmpd/style" &
    pids+=("$!")
  fi
  case "$discovery_mode" in
    both) desc="tag & style" ;;
    tag) desc="tag" ;;
    style) desc="style" ;;
  esac
  spinner_multi "Discovering $desc" "${pids[@]}" &
  spin_pid=$!
  for pid in "${pids[@]}"; do
    wait "$pid"
  done
  wait "$spin_pid" 2>/dev/null || true
  if [ -f "$tmpd/tag" ]; then
    mapfile -t discovered_tags <"$tmpd/tag"
  fi
  if [ -f "$tmpd/style" ]; then
    mapfile -t discovered_styles <"$tmpd/style"
  fi
  msg=""
  if [ "${#discovered_tags[@]}" -gt 0 ]; then
    msg="tags: ${discovered_tags[*]} (model: $tag_model)"
  fi
  if [ "${#discovered_styles[@]}" -gt 0 ]; then
    [ -n "$msg" ] && msg="$msg | "
    msg="${msg}styles: ${discovered_styles[*]} (model: $style_model)"
  fi
  [ -n "$msg" ] && echo "🆕 Discovered $msg"
  for t in "${discovered_tags[@]}"; do
    append_config_item "$gen_group" "tags" "$t"
  done
  for s in "${discovered_styles[@]}"; do
    append_config_item "$gen_group" "styles" "$s"
  done
  if [ "$force_generate" != true ]; then
    echo "✅ Discovery complete. No image generated (use -x to generate)"
    rm -rf "$tmpd"
    cleanup_and_exit 0
  fi
  rm -rf "$tmpd"
fi

# If a new group was created and discovery supplied items, replace defaults
if [ "$group_created" = "1" ]; then
  if [ "${#discovered_tags[@]}" -gt 0 ] && [ "$tag_provided" = false ]; then
    set_config_list "$gen_group" "tags" "${discovered_tags[0]}"
  fi
  if [ "${#discovered_styles[@]}" -gt 0 ] && [ "$style_provided" = false ]; then
    set_config_list "$gen_group" "styles" "${discovered_styles[0]}"
  fi
fi
if [ -n "$discovery_mode" ] && [ "$force_generate" = true ]; then
  if [ -z "$tag" ] && [ "${#discovered_tags[@]}" -gt 0 ]; then
    tag=$(printf '%s\n' "${discovered_tags[@]}" | shuf -n1)
  fi
  if [ -z "$style" ] && [ "${#discovered_styles[@]}" -gt 0 ]; then
    style=$(printf '%s\n' "${discovered_styles[@]}" | shuf -n1)
  fi
  if [ -z "$tag" ] && [ "${#gen_tags[@]}" -gt 0 ]; then
    tag=$(printf '%s\n' "${gen_tags[@]}" | shuf -n1)
  fi
  if [ -z "$style" ] && [ "${#gen_styles[@]}" -gt 0 ]; then
    style=$(printf '%s\n' "${gen_styles[@]}" | shuf -n1)
  fi
  { [ -n "$tag" ] && [ -n "$style" ]; } || { echo "❌ Missing tag or style for generation" >&2; cleanup_and_exit 1; }
fi
# Select image models from provider config
models=("${provider_image_models[@]}")
if [ "$random_model" = true ]; then
  model=$(printf '%s\n' "${models[@]}" | shuf -n1)
  echo "🎲 Randomly selected model: $model"
fi
if [ -z "$model" ]; then
  model="$openai_image_model"
fi
if ! printf '%s\n' "${models[@]}" | grep -qxF "$model"; then
  echo "Invalid model: $model" >&2
  echo "Valid models: ${models[*]}" >&2
  cleanup_and_exit 1
fi

# wallai.sh - generate a wallpaper using OpenAI-compatible APIs
#
# Usage: wallai.sh [-b [group]] [-p "prompt text"] [-t tag] [-s style] [-im model] [-pm model] [-tm model] [-sm model] [-r] [-f] [-x [count]]
#                  [-g group] [-d mode] [-i group] [-k token] [-w] [-l] [-n "text"] [-v] [-h]
# Environment variables:
#   ALLOW_NSFW         Set to 'false' to disallow NSFW prompts (default 'true')
# Flags:
#   -p prompt text  Custom prompt text
#   -t tag        Specify tag
#   -s style        Pick a visual style or use a random one
#   -im model       Image model for generation
#   -pm model       Text model for prompt generation
#   -tm model       Text model for tag discovery
#   -sm model       Text model for style discovery
#   -r              Pick a random model from the available list
#   -b [group]      Browse generated wallpapers and optionally favorite one
#   -f              Mark the latest generated wallpaper as a favorite
#   -g group        Generate using config from the specified group
#   -d mode         Discover a new tag/style (tag, style or both)
#   -i group        Choose tag and style inspired by favorites from the specified group (defaults to "main")
#   -k token        Save provider token to the config
#   -w              Add weather, time and seasonal context
#   -l              Use tag and/or style from the last image
#   -n text         Override the default negative prompt
#   -v              Enable verbose output
#   -h              Show help and exit
#
# Dependencies: curl, jq, termux-wallpaper, optional exiftool for -f
# Output: saves the generated image under ~/pictures/generated-wallpapers
# TAG: wallpaper
# TAG: ai

save_dir="$gen_gen_path"
mkdir -p "$save_dir"
timestamp="$(date +%Y%m%d-%H%M%S)"
tmp_output="$save_dir/${timestamp}.img"
TMPFILE="$tmp_output"


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




fetch_prompt() {
  local query payload response
  if [ -n "$mood" ]; then
    query="Describe a $tag wallpaper scene in a $mood mood tone in exactly 15 words. Respond with only those 15 words."
  else
    query="Describe a $tag wallpaper scene in exactly 15 words. Respond with only those 15 words."
  fi
  prompt_seed=$(random_seed)
  payload=$(jq -n --arg model "$openai_text_model" --arg prompt "$query" '{model:$model,messages:[{role:"user",content:$prompt}]}')
  [ "$verbose" = true ] && echo "🔍 Requesting prompt via $provider" >&2
  response=$(curl -sL "${curl_auth_text[@]}" -H "Content-Type: application/json" -d "$payload" "$text_api_base/chat/completions" || true)
  prompt=$(printf '%s' "$response" | jq -r '.choices[0].message.content // empty' 2>/dev/null)
  [ "$verbose" = true ] && echo "🔍 Response: $prompt" >&2
  
  # Check if prompt is null, empty, or just whitespace
  if [ -z "$prompt" ] || [ "$prompt" = "null" ] || [ -z "$(printf '%s' "$prompt" | tr -d '[:space:]')" ]; then
    return 1
  fi
  
  prompt=$(printf '%s' "$prompt" | tr '\n' ' ' | sed 's/  */ /g; s/^ //; s/ $//')
  prompt=$(printf '%s' "$prompt" | sed -E 's/^[Cc]reate a wallpaper of (a )?//')
  prompt=$(printf '%s\n' "$prompt" | awk '{for(i=1;i<=15 && i<=NF;i++){printf $i;if(i<15 && i<NF)printf " ";}}')
  [ -n "$prompt" ] && [ "$prompt" != "null" ]
}

if [ -z "$prompt" ]; then
  echo "🎯 Fetching random prompt from $provider (model: $openai_text_model)..."

  # 🎲 Step 1: Pick or use provided tag
  if [ -z "$tag" ]; then
    if [ "${#gen_tags[@]}" -gt 0 ]; then
      tag=$(printf '%s\n' "${gen_tags[@]}" | shuf -n1)
    else
      tags=(
        "dreamcore" "mystical forest" "cosmic horror" "ethereal landscape"
        "retrofuturism" "alien architecture" "cyberpunk metropolis"
      )
      tag=$(printf '%s\n' "${tags[@]}" | shuf -n1)
    fi
  fi
  if [ "${#discovered_tags[@]}" -eq 0 ]; then
    echo "🔖 Selected tag: $tag"
  fi

  # 🧠 Step 2: Retrieve a text prompt for that tag
  if ! fetch_prompt; then
    echo "❌ Failed to fetch prompt. Using fallback."
    # Create tag-specific fallback prompts
    case "$tag" in
      "cosmic horror")
        fallback_prompts=(
          "eldritch tentacles emerging from dark cosmic void with ancient symbols"
          "massive alien entity looming over twisted reality with glowing eyes"
          "otherworldly geometry defying physics in deep space nightmare"
          "ancient cosmic beings awakening from eternal slumber in darkness"
        )
        ;;
      "dreamcore")
        fallback_prompts=(
          "surreal floating islands with impossible architecture and soft lighting"
          "endless corridors with shifting walls and ethereal atmosphere"
          "liminal spaces between reality and dreams with pastel colors"
          "nostalgic childhood memories manifested in surreal dreamlike landscape"
        )
        ;;
      "cyberpunk metropolis")
        fallback_prompts=(
          "neon-lit skyscrapers towering over rain-soaked streets with holograms"
          "futuristic city with flying cars and massive digital billboards"
          "dark alleyways illuminated by colorful neon signs and steam"
          "high-tech urban landscape with chrome and glass architecture"
        )
        ;;
      *)
        fallback_prompts=(
          "surreal dreamscape with neon colors and floating elements"
          "futuristic city skyline at dusk with glowing lights"
          "ancient ruins shrouded in mist and mystery"
          "mystical forest glowing softly with magical energy"
          "retro wave grid horizon with stars and synthwave aesthetic"
          "lush alien jungle under twin moons and strange flora"
          "calm desert landscape under stars with sand dunes"
        )
        ;;
    esac
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
if [ "${#discovered_styles[@]}" -eq 0 ]; then
  echo "🖌 Selected style: $style"
fi

# Determine weights from config if not set by inspiration
if [ "$tag_weight" = "1.5" ]; then
  tag_weight=$(find_tag_weight "$tag")
fi
if [ "$style_weight" = "1.3" ]; then
  style_weight=$(find_style_weight "$style")
fi
tag_weight=$(clamp_weight "$tag_weight")
style_weight=$(clamp_weight "$style_weight")

# Build the final prompt with tag and style weights and negative text
base_prompt="$prompt"
prompt="(${tag}:${tag_weight}) $base_prompt (${style}:${style_weight}) [negative prompt: $negative_prompt]"

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

# Auto-retry if prompt is empty or null
if [ -z "$(printf '%s' "$prompt" | tr -d '[:space:]')" ] || [ "$prompt" = "null" ]; then
  echo "⚠️ Retrying prompt generation..."
  if fetch_prompt; then
    base_prompt="$prompt"
    prompt="(${tag}:${tag_weight}) $base_prompt (${style}:${style_weight}) [negative prompt: $negative_prompt]"
    if [ "$weather_flag" = true ]; then
      env_text=$(printf ', %s' "${env_parts[@]}")
      env_text=${env_text#, }
      prompt="$prompt, $env_text"
    fi
  else
    echo "❌ Retry failed. Using tag-based fallback."
    case "$tag" in
      "cosmic horror") base_prompt="eldritch tentacles emerging from dark cosmic void with ancient symbols" ;;
      "dreamcore") base_prompt="surreal floating islands with impossible architecture and soft lighting" ;;
      "cyberpunk metropolis") base_prompt="neon-lit skyscrapers towering over rain-soaked streets with holograms" ;;
      "mystical forest") base_prompt="enchanted woodland with glowing mushrooms and ethereal mist" ;;
      "retrofuturism") base_prompt="retro-futuristic cityscape with chrome buildings and flying vehicles" ;;
      "alien architecture") base_prompt="otherworldly structures with impossible geometry and alien materials" ;;
      "ethereal landscape") base_prompt="dreamlike terrain with floating rocks and soft luminous atmosphere" ;;
      *) base_prompt="surreal dreamscape with vibrant colors and fantastical elements" ;;
    esac
    prompt="(${tag}:${tag_weight}) $base_prompt (${style}:${style_weight}) [negative prompt: $negative_prompt]"
    if [ "$weather_flag" = true ]; then
      env_text=$(printf ', %s' "${env_parts[@]}")
      env_text=${env_text#, }
      prompt="$prompt, $env_text"
    fi
  fi
fi
if [ -z "$(printf '%s' "$prompt" | tr -d '[:space:]')" ] || [ "$prompt" = "null" ]; then
  echo "❌ Prompt could not be generated. Check your config or arguments." >&2
  cleanup_and_exit 1
fi

# Ensure we always have a value for the generated content type
generated_content_type=""

echo "🎨 Final prompt: $prompt"
echo "🛠 Using model: $model"

# ✨ Step 3: Generate image via $provider

generate_image() {
  local out_file="$1" type_file="$2" url
  if [ "$image_provider" = "pollinations" ]; then
    local encoded headers
    encoded=$(printf '%s' "$prompt" | jq -sRr @uri)
    headers=$(mktemp)
    local url_full="${image_api_base}/prompt/${encoded}?nologo=true&enhance=true&model=${model}&seed=${seed}"
    [ "$allow_nsfw" = false ] && url_full="${url_full}&safe=true"
    [ "$verbose" = true ] && echo "🔍 Image URL: $url_full" >&2
    if ! curl -sL "${curl_auth_image[@]}" -D "$headers" "$url_full" -o "$out_file"; then
      rm -f "$headers"
      return 1
    fi
    file_type=$(grep -i '^content-type:' "$headers" | tr -d '\r' | awk '{print $2}')
    printf '%s' "$file_type" >"$type_file"
    rm -f "$headers"
  else
    local payload
    payload=$(jq -n --arg model "$model" --arg prompt "$prompt" '{model:$model,prompt:$prompt}')
    [ "$verbose" = true ] && echo "🔍 Requesting image via $provider" >&2
    url=$(curl -sL "${curl_auth_image[@]}" -H "Content-Type: application/json" -d "$payload" "$image_api_base/images/generations" | jq -r '.data[0].url' 2>/dev/null)
    [ -n "$url" ] || return 1
    curl -sL "$url" -o "$out_file"
    file_type=$(file -b --mime-type "$out_file" 2>/dev/null || true)
    printf '%s' "$file_type" >"$type_file"
  fi
}

last_output=""
last_timestamp=""
last_seed=""
for ((i=1;i<=batch_count;i++)); do
  [ "$verbose" = true ] && [ "$batch_count" -gt 1 ] && \
    echo "🖼 Generating image $i of $batch_count..."
  seed=$(random_seed)
  timestamp="$(date +%Y%m%d-%H%M%S)"
  tmp_output="$save_dir/${timestamp}.img"
  TMPFILE="$tmp_output"

  ctype_file=$(mktemp)
  TMPJSON="$ctype_file"
  provider="$image_provider"
  generate_image "$tmp_output" "$ctype_file" &
  gen_pid=$!
  spinner "$gen_pid" "Generating image" &
  spin_pid=$!
  wait "$gen_pid"
  status=$?
  wait "$spin_pid" 2>/dev/null || true
  printf '\n'
  if [ "$status" -ne 0 ]; then
    echo "❌ Failed to generate image via $provider" >&2
    cleanup_and_exit 1
  fi
  generated_content_type=$(cat "$ctype_file" 2>/dev/null || true)
  file_type=$(file -b --mime-type "$tmp_output" 2>/dev/null || true)
  [ "$verbose" = true ] && echo "🔍 File type: $file_type"
  if ! printf '%s' "$generated_content_type" | grep -qi '^image/' || \
     ! printf '%s' "$file_type" | grep -qi '^image/'; then
    echo "❌ Invalid image file!" >&2
    cleanup_and_exit 1
  fi
  echo "✅ Image generated successfully"
  img_source="$provider"

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
  tag_slug=$(slugify "${tag:-custom}")
  style_slug=$(slugify "$style")
  filename="${timestamp}_${tag_slug}_${style_slug}.${ext}"
  output="$save_dir/$filename"
  mv "$tmp_output" "$output"
  TMPFILE=""
  TMPJSON=""
  echo "💾 Saved to: $output"

  entry="$gen_group|$filename|$seed|$prompt|$prompt_seed|$tag_seed|$style_seed"
  echo "$entry" >> "$log_file"
  echo "$entry" >> "$main_log"

  last_output="$output"
  last_timestamp="$timestamp"
  last_seed="$seed"
done

if [ "$has_termux_wallpaper" = true ]; then
  termux-wallpaper -f "$last_output"
  echo "🎉 Wallpaper set from prompt: $prompt" "(source: $img_source)"
else
  echo "🎉 Image generated: $last_output"
  echo "📝 Prompt: $prompt (source: $img_source)"
  echo "ℹ️  termux-wallpaper not available - wallpaper not set automatically"
fi

[ "$favorite_wall" = true ] && {
  favorite_image "$last_output" "$prompt" "$tag" "$style" "$mood" "$model" "$last_seed" "$last_timestamp" "$fav_path" "$favorite_group"
  for t in "${discovered_tags[@]}"; do
    append_config_item "$gen_group" "tags" "$t"
  done
  for s in "${discovered_styles[@]}"; do
    append_config_item "$gen_group" "styles" "$s"
  done
}

cleanup_and_exit 0
