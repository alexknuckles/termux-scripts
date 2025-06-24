#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

# Check dependencies early so the script fails with a clear message
for cmd in curl jq termux-wallpaper termux-vibrate; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "❌ Required command '$cmd' is not installed" >&2
    exit 1
  fi
done

# Parse options
prompt=""
while getopts ":p:" opt; do
  case "$opt" in
    p)
      prompt="$OPTARG"
      ;;
    *)
      echo "Usage: wallai.sh [-p \"prompt text\"]" >&2
      exit 1
      ;;
  esac
done
shift $((OPTIND - 1))

# wallai.sh - generate a wallpaper using Pollinations
#
# Usage: wallai.sh [-p "prompt text"]
# Environment variables:
#   ALLOW_NSFW         Set to 'false' to disallow NSFW prompts (default 'true')
#
# Dependencies: curl, jq, termux-wallpaper, termux-vibrate
# Output: saves the generated image under ~/pictures/generated-wallpapers
# TAG: wallpaper
# TAG: ai

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


if [ -z "$prompt" ]; then
  echo "🎯 Fetching random prompt from Civitai..."

  # 🎲 Step 1: Get a random tag
  tag=$(curl -s "https://civitai.com/api/v1/tags?limit=200" \
    | jq -r '.items[].name' | shuf -n 1 || true)
  echo "🔖 Selected tag: $tag"

  # 🧠 Step 2: Get a prompt from an image using that tag
  image_info=$(curl -s "https://civitai.com/api/v1/images?limit=100&nsfw=$allow_nsfw&tag=$tag" \
    -H "Content-Type: application/json" || true)
  encoded=$(echo "$image_info" | jq -r '[.items[] | {prompt: .meta.prompt, baseModel: .baseModel}] | map(select(.prompt != null and .prompt != "")) | .[] | @base64' | shuf -n 1 || true)
  if [ -n "$encoded" ]; then
    prompt=$(echo "$encoded" | base64 --decode | jq -r '.prompt')
    # baseModel field is ignored
  else
    echo "❌ No prompt found for tag $tag"
    prompt="a neon dreamscape filled with surreal creatures"
  fi

  # 🛑 Fallback prompt
  if [ -z "$prompt" ]; then
    echo "❌ No prompt found for tag $tag. Using fallback."
    prompt="a neon dreamscape filled with surreal creatures"
  fi
fi

echo "🎨 Final prompt: $prompt"

# ✨ Step 3: Generate image via Pollinations

generate_pollinations() {
  local out_file="$1"
  local encoded
  encoded=$(printf '%s' "$prompt" | jq -sRr @uri)
  curl -sL "https://image.pollinations.ai/prompt/${encoded}" -o "$out_file"
}

echo "⏳ Generating image via Pollinations..."
if ! generate_pollinations "$output"; then
  echo "❌ Failed to generate image via Pollinations" >&2
  exit 1
fi
img_source="Pollinations"

termux-wallpaper -f "$output"
echo "🎉 Wallpaper set from prompt: $prompt" "(source: $img_source)"
echo "💾 Saved to: $output"
shave_and_a_haircut
