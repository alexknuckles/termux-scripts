#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

# Check dependencies early so the script fails with a clear message
for cmd in curl jq termux-wallpaper termux-vibrate; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "❌ Required command '$cmd' is not installed" >&2
    exit 1
  fi
done

# wallai.sh - generate a wallpaper using Stable Horde
#
# Usage: wallai.sh
# Environment variables:
#   HORDE_WIDTH       Desired image width (<=576)
#   HORDE_HEIGHT      Desired image height (<=576)
#   HORDE_MAX_CHECKS   Number of times to poll for completion (default 60)
#   HORDE_STEPS        Diffusion steps for Stable Horde (default 40)
#   HORDE_SAMPLER      Sampler name for Horde (default 'k_euler')
#   ALLOW_NSFW         Set to 'false' to disallow NSFW prompts (default 'true')
#   HORDE_ONLY         Set to 'true' to disable Pollinations
#
# Dependencies: curl, jq, termux-wallpaper, termux-vibrate
# Output: saves the generated image under ~/pictures/generated-wallpapers
# TAG: wallpaper
# TAG: ai

apikey="${HORDE_API_KEY:-0000000000}"
# Dimensions must be <=576 to avoid extra kudos on Stable Horde
width="${HORDE_WIDTH:-512}"
height="${HORDE_HEIGHT:-512}"
horde_steps="${HORDE_STEPS:-40}"
horde_sampler="${HORDE_SAMPLER:-k_euler}"
horde_only_raw="${HORDE_ONLY:-false}"
case "$(printf '%s' "$horde_only_raw" | tr '[:upper:]' '[:lower:]')" in
  1|true|yes)
    horde_only=true
    ;;
  *)
    horde_only=false
    ;;
esac
save_dir="$HOME/pictures/generated-wallpapers"
mkdir -p "$save_dir"
filename="$(date +%Y%m%d-%H%M%S).png"
output="$save_dir/$filename"

# Short vibration pattern using Termux API
shave_and_a_haircut() {
  local short=70
  local long=150
  termux-vibrate -d "$short"; sleep 0.07
  termux-vibrate -d "$short"; sleep 0.07
  termux-vibrate -d "$short"; sleep 0.07
  termux-vibrate -d "$short"; sleep 0.07
  termux-vibrate -d "$short"; sleep 0.07
  termux-vibrate -d "$long";  sleep 0.07
  termux-vibrate -d "$long"
}

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

# Grab list of models available on Stable Horde
horde_models=$(curl -s "https://stablehorde.net/api/v2/status/models" | jq -r '.[].name' || true)

# Known base models available on Stable Horde
default_models=$'SDXL 1.0\nSD 1.5\nSD 2.1 768\n'
# Read newline separated models into an array without requiring a NUL terminator
mapfile -t horde_base_models <<<"${HORDE_BASE_MODELS:-$default_models}"

echo "🎯 Fetching random prompt from Civitai..."

# 🎲 Step 1: Get a random tag
tag=$(curl -s "https://civitai.com/api/v1/tags?limit=200" \
  | jq -r '.items[].name' | shuf -n 1 || true)
echo "🔖 Selected tag: $tag"

# Pick a fallback base model in case the image lacks one
base_model=$(printf '%s\n' "${horde_base_models[@]}" | shuf -n 1)

# 🧠 Step 2: Get a prompt and base model from an image using that tag
image_info=$(curl -s "https://civitai.com/api/v1/images?limit=100&nsfw=$allow_nsfw&tag=$tag" \
  -H "Content-Type: application/json" || true)
encoded=$(echo "$image_info" | jq -r '[.items[] | {prompt: .meta.prompt, baseModel: .baseModel}] | map(select(.prompt != null and .prompt != "")) | .[] | @base64' | shuf -n 1 || true)
if [ -n "$encoded" ]; then
  prompt=$(echo "$encoded" | base64 --decode | jq -r '.prompt')
  bm_tmp=$(echo "$encoded" | base64 --decode | jq -r '.baseModel')
  if [ -n "$bm_tmp" ] && [ "$bm_tmp" != "null" ]; then
    base_model="$bm_tmp"
    echo "📦 Image base model: $base_model"
  else
    echo "📦 Using fallback base model: $base_model"
  fi
else
  echo "❌ No prompt found for tag $tag"
  prompt="a neon dreamscape filled with surreal creatures"
  echo "📦 Using fallback base model: $base_model"
fi

# Pick a model on Horde that matches the base model, if available
model=$(echo "$horde_models" | grep -iF "$base_model" | head -n 1)
if [ -n "$model" ]; then
  echo "🌟 Using Horde model: $model (from base: $base_model)"
  model_field="\"models\": [\"$model\"],"
else
  echo "⚠️ Model '$base_model' not found on Horde."
  model_field=""
fi

# 🛑 Fallback prompt
if [ -z "$prompt" ]; then
  echo "❌ No prompt found for tag $tag. Using fallback."
  prompt="a neon dreamscape filled with surreal creatures"
fi

echo "🎨 Final prompt: $prompt"

# Escape any characters in the prompt that could break JSON
escaped_prompt=$(printf '%s' "$prompt" | jq -Rs .)

# ✨ Step 3: Generate image via Stable Horde and Pollinations

generate_horde() {
  local out_file="$1"
  local response id status done_flag img_url max_attempts attempt
  response=$(curl -s -X POST "https://stablehorde.net/api/v2/generate/async" \
    -H "Content-Type: application/json" \
    -H "apikey: $apikey" \
    -H "Client-Agent: termux-horde-script:1.0:alex" \
    -d @- <<EOF
  {
    "prompt": $escaped_prompt,
    ${model_field}
    "params": {
      "width": $width,
      "height": $height,
      "steps": $horde_steps,
      "sampler_name": "$horde_sampler",
      "cfg_scale": 7,
      "n": 1,
      "karras": true
    },
    "nsfw": $allow_nsfw,
    "censor_nsfw": false
  }
EOF
  )
  id=$(echo "$response" | jq -r '.id')
  [ "$id" = "null" ] && return 1
  max_attempts="${HORDE_MAX_CHECKS:-60}"
  attempt=1
  while true; do
    status=$(curl -s "https://stablehorde.net/api/v2/generate/status/$id")
    done_flag=$(echo "$status" | jq -r '.done')
    if [ "$done_flag" = "true" ]; then
      break
    fi
    if [ "$attempt" -ge "$max_attempts" ]; then
      return 1
    fi
    attempt=$((attempt + 1))
    sleep 10
  done
  img_url=$(echo "$status" | jq -r '.generations[0].img')
  [ "$img_url" = "null" ] && return 1
  curl -sL "$img_url" -o "$out_file"
}

generate_pollinations() {
  local out_file="$1"
  local encoded
  encoded=$(printf '%s' "$prompt" | jq -sRr @uri)
  curl -sL "https://image.pollinations.ai/prompt/${encoded}" -o "$out_file"
}

if [ "$horde_only" = true ]; then
  echo "⏳ Generating image via Stable Horde..."
  if ! generate_horde "$output"; then
    echo "❌ Failed to generate image via Stable Horde" >&2
    exit 1
  fi
  img_source="Stable Horde"
else
  pollinations_tmp=$(mktemp)
  horde_tmp=$(mktemp)
  echo "⏳ Generating images via Pollinations and Stable Horde..."
  generate_pollinations "$pollinations_tmp" &
  pid_p=$!
  generate_horde "$horde_tmp" &
  pid_h=$!
  winner=""
  while true; do
    if [ -s "$pollinations_tmp" ]; then
      winner="pollinations"
      kill "$pid_h" 2>/dev/null || true
      wait "$pid_h" 2>/dev/null || true
      break
    fi
    if [ -s "$horde_tmp" ]; then
      winner="horde"
      kill "$pid_p" 2>/dev/null || true
      wait "$pid_p" 2>/dev/null || true
      break
    fi
    if ! kill -0 "$pid_p" 2>/dev/null && ! kill -0 "$pid_h" 2>/dev/null; then
      break
    fi
    sleep 1
  done
  if [ "$winner" = "pollinations" ]; then
    mv "$pollinations_tmp" "$output"
    img_source="Pollinations"
  elif [ "$winner" = "horde" ]; then
    mv "$horde_tmp" "$output"
    img_source="Stable Horde"
  else
    echo "❌ Both Pollinations and Horde failed." >&2
    exit 1
  fi
fi

termux-wallpaper -f "$output"
echo "🎉 Wallpaper set from prompt: $prompt" "(source: $img_source)"
echo "💾 Saved to: $output"
shave_and_a_haircut
