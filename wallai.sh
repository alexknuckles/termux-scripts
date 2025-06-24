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
theme=""
model="flux"
random_model=false
while getopts ":p:t:m:r" opt; do
  case "$opt" in
    p)
      prompt="$OPTARG"
      ;;
    t)
      theme="$OPTARG"
      ;;
    m)
      model="$OPTARG"
      ;;
    r)
      random_model=true
      ;;
    *)
      echo "Usage: wallai.sh [-p \"prompt text\"] [-t theme] [-m model] [-r]" >&2
      exit 1
      ;;
  esac
done
shift $((OPTIND - 1))

# Validate selected model using the API list
mapfile -t models < <(
  curl -sL "https://image.pollinations.ai/models" | jq -r '.[]' 2>/dev/null
)
if [ "${#models[@]}" -eq 0 ]; then
  models=(flux turbo gptimage)
fi
if [ "$random_model" = true ]; then
  model=$(printf '%s\n' "${models[@]}" | shuf -n1)
fi
if ! printf '%s\n' "${models[@]}" | grep -qxF "$model"; then
  echo "Invalid model: $model" >&2
  echo "Valid models: ${models[*]}" >&2
  exit 1
fi

# wallai.sh - generate a wallpaper using Pollinations
#
# Usage: wallai.sh [-p "prompt text"] [-t theme] [-m model] [-r]
# Environment variables:
#   ALLOW_NSFW         Set to 'false' to disallow NSFW prompts (default 'true')
# Flags:
#   -p prompt text  Custom prompt instead of random theme
#   -t theme        Specify theme when fetching random prompt
#   -m model        Pollinations model (defaults to 'flux'). Supported models
#                   are fetched from the API (fallback: flux turbo gptimage)
#   -r              Pick a random model from the available list
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

params="model=$model"
if [ "$allow_nsfw" = false ]; then
  params="safe=true&$params"
fi


if [ -z "$prompt" ]; then
  echo "🎯 Fetching random prompt from Pollinations..."

  # 🎲 Step 1: Pick or use provided theme
  if [ -z "$theme" ]; then
    themes=("fantasy" "sci-fi" "cyberpunk" "steampunk" "surreal" "horror")
    theme=$(printf '%s\n' "${themes[@]}" | shuf -n1)
  fi
  echo "🔖 Selected theme: $theme"

  # 🧠 Step 2: Retrieve a text prompt for that theme
  # Ask the API for exactly 15 words and pass a random seed to vary results
  random_token=$(date +%s%N | sha256sum | head -c 8)
  prompt=$(curl -sL "https://text.pollinations.ai/Imagine+a+${theme}+picture+in+exactly+15+words?seed=${random_token}" || true)
  # Normalize whitespace and keep only the first 15 words
  prompt=$(printf '%s' "$prompt" | tr '\n' ' ' | sed 's/  */ /g; s/^ //; s/ $//')
  prompt=$(printf '%s\n' "$prompt" | awk '{for(i=1;i<=15 && i<=NF;i++){printf $i;if(i<15 && i<NF)printf " ";}}')

  # 🛑 Fallback prompt
  if [ -z "$prompt" ]; then
    echo "❌ Failed to fetch prompt. Using fallback."
    prompt="a neon dreamscape filled with surreal creatures"
  fi
fi

echo "🎨 Final prompt: $prompt"
echo "🛠 Using model: $model"

# ✨ Step 3: Generate image via Pollinations

generate_pollinations() {
  local out_file="$1"
  local encoded headers content_type err_msg
  encoded=$(printf '%s' "$prompt" | jq -sRr @uri)
  headers=$(mktemp)
  if ! curl -sL -D "$headers" "https://image.pollinations.ai/prompt/${encoded}?${params}" -o "$out_file"; then
    rm -f "$headers"
    return 1
  fi
  content_type=$(grep -i '^content-type:' "$headers" | tr -d '\r' | awk '{print $2}')
  rm -f "$headers"
  if printf '%s' "$content_type" | grep -qi 'application/json'; then
    err_msg=$(jq -r '.message // .error // "Unknown error"' <"$out_file" 2>/dev/null)
    echo "❌ Pollinations error: $err_msg" >&2
    return 1
  fi
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
