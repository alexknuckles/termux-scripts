#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

# Check dependencies early so the script fails with a clear message
for cmd in curl jq termux-wallpaper; do
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
# Dependencies: curl, jq, termux-wallpaper
# Output: saves the generated image under ~/pictures/generated-wallpapers
# TAG: wallpaper
# TAG: ai

save_dir="$HOME/pictures/generated-wallpapers"
mkdir -p "$save_dir"
filename="$(date +%Y%m%d-%H%M%S).png"
output="$save_dir/$filename"


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
  echo "🎯 Fetching random prompt from Pollinations..."

  # 🎲 Step 1: Pick a random theme
  themes=("fantasy" "sci-fi" "cyberpunk" "steampunk" "surreal" "horror")
  theme=$(printf '%s\n' "${themes[@]}" | shuf -n1)
  echo "🔖 Selected theme: $theme"

  # 🧠 Step 2: Retrieve a text prompt for that theme
  prompt=$(curl -sL "https://text.pollinations.ai/Imagine+a+${theme}+scene" || true)
  # Trim and shorten to keep prompts descriptive and concise
  prompt=$(printf '%s' "$prompt" | tr '\n' ' ' | sed 's/  */ /g; s/^ //; s/ $//')
  prompt=$(printf '%s\n' "$prompt" | awk '{for(i=1;i<=15 && i<=NF;i++){printf $i;if(i<15 && i<NF)printf " ";};if(NF>15)printf "..."}')

  # 🛑 Fallback prompt
  if [ -z "$prompt" ]; then
    echo "❌ Failed to fetch prompt. Using fallback."
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
