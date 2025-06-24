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
#   USE_REPLICATE      Set to 'true' to use Replicate instead of Horde
#   REPLICATE_TOKEN    API token for Replicate
#   REPLICATE_VERSION  Model version ID (defaults to SDXL latest)
#
# Dependencies: curl, jq, termux-wallpaper, termux-vibrate
# Output: saves the generated image under ~/pictures/generated-wallpapers
# TAG: wallpaper
# TAG: ai

apikey="${HORDE_API_KEY:-0000000000}"
# Dimensions must be <=576 to avoid extra kudos on Stable Horde
width="${HORDE_WIDTH:-512}"
height="${HORDE_HEIGHT:-512}"
replicate_token="${REPLICATE_TOKEN:-}"
replicate_version="${REPLICATE_VERSION:-7762fd07cf82c948538e41f63f77d685e02b063e37e496e96eefd46c929f9bdc}"
horde_steps="${HORDE_STEPS:-40}"
horde_sampler="${HORDE_SAMPLER:-k_euler}"
replicate_steps="${REPLICATE_STEPS:-50}"
replicate_scheduler="${REPLICATE_SCHEDULER:-K_EULER}"
replicate_guidance="${REPLICATE_GUIDANCE:-7.5}"
use_replicate_raw="${USE_REPLICATE:-false}"
case "$(printf '%s' "$use_replicate_raw" | tr '[:upper:]' '[:lower:]')" in
  1|true|yes)
    use_replicate=true
    ;;
  *)
    use_replicate=false
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

# ✨ Step 3: Generate image via Horde or Replicate
if [ "$use_replicate" = true ]; then
  if [ -z "$replicate_token" ]; then
    echo "❌ REPLICATE_TOKEN is required when USE_REPLICATE is true" >&2
    exit 1
  fi
  response=$(curl -s -X POST "https://api.replicate.com/v1/predictions" \
    -H "Authorization: Token $replicate_token" \
    -H "Content-Type: application/json" \
    -d @- <<EOF
  {
    "version": "$replicate_version",
    "input": {
      "prompt": $escaped_prompt,
      "width": $width,
      "height": $height,
      "num_inference_steps": $replicate_steps,
      "scheduler": "$replicate_scheduler",
      "guidance_scale": $replicate_guidance,
      "num_outputs": 1,
      "disable_safety_checker": $([ "$allow_nsfw" = true ] && echo true || echo false)
    }
  }
EOF
  )
  id=$(echo "$response" | jq -r '.id')
  if [ "$id" = "null" ] || [ -z "$id" ]; then
    echo "❌ Failed to submit image generation job." >&2
    exit 1
  fi
  echo "⏳ Submitted to Replicate. ID: $id"
  max_attempts="${HORDE_MAX_CHECKS:-60}"
  attempt=1
  while true; do
    echo "⏳ Checking status (attempt $attempt)..."
    status=$(curl -s -H "Authorization: Token $replicate_token" "https://api.replicate.com/v1/predictions/$id")
    state=$(echo "$status" | jq -r '.status')
    if [ "$state" = "succeeded" ]; then
      echo "✅ Image ready!"
      break
    elif [ "$state" = "failed" ] || [ "$state" = "canceled" ]; then
      echo "❌ Generation failed with status: $state" >&2
      echo "$status" | jq -r '.error // empty' >&2
      exit 1
    fi
    if [ "$attempt" -ge "$max_attempts" ]; then
      echo "❌ Timed out waiting for image after $max_attempts attempts." >&2
      exit 1
    fi
    attempt=$((attempt + 1))
    sleep 10
  done
  img_url=$(echo "$status" | jq -r '.output[0]')
else
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
  if [ "$id" = "null" ] || [ -z "$id" ]; then
    echo "❌ Failed to submit image generation job." >&2
    exit 1
  fi
  echo "⏳ Submitted to Horde. ID: $id"
  max_attempts="${HORDE_MAX_CHECKS:-60}"
  attempt=1
  while true; do
    echo "⏳ Checking status (attempt $attempt)..."
    status=$(curl -s "https://stablehorde.net/api/v2/generate/status/$id")
    done_flag=$(echo "$status" | jq -r '.done')
    if [ "$done_flag" = "true" ]; then
      echo "✅ Image ready!"
      break
    fi
    if [ "$attempt" -ge "$max_attempts" ]; then
      echo "❌ Timed out waiting for image after $max_attempts attempts." >&2
      exit 1
    fi
    attempt=$((attempt + 1))
    sleep 10
  done
  img_url=$(echo "$status" | jq -r '.generations[0].img')
fi

if [ "$img_url" = "null" ] || [ -z "$img_url" ]; then
  echo "❌ No image URL received." >&2
  exit 1
fi

curl -sL "$img_url" -o "$output"
termux-wallpaper -f "$output"
echo "🎉 Wallpaper set from prompt: $prompt"
echo "💾 Saved to: $output"
shave_and_a_haircut
