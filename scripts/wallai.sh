#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

# wallai.sh - generate a wallpaper using Pollinations
#
# Usage: wallai.sh [-p "prompt text"] [-t theme] [-y style] [-m model] [-r] [-f] [-i] [-w] [-n "text"]
#   -p  custom prompt instead of random theme
#   -t  choose a theme when fetching the random prompt
#   -y  pick a visual style or use a random one
#   -m  Pollinations model (default "flux")
#   -r  select a random model from the available list
#   -f  mark the generated wallpaper as a favorite
#   -i  pick theme and style inspired by past favorites
#   -w  add weather, time and holiday context to the prompt
#   -n  custom negative prompt
#
# Dependencies: curl, jq, termux-wallpaper, optional exiftool for -f
# Output: saves the generated image to ~/pictures/generated-wallpapers and sets
#         the current wallpaper
# TAG: wallpaper
# TAG: ai

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
model="flux"
random_model=false
favorite_wall=false
inspired_mode=false
weather_flag=false
generation_opts=false
while getopts ":p:t:m:y:rn:fiw" opt; do
  case "$opt" in
    p)
      prompt="$OPTARG"
      generation_opts=true
      ;;
    t)
      theme="$OPTARG"
      generation_opts=true
      ;;
    m)
      model="$OPTARG"
      generation_opts=true
      ;;
    y)
      style="$OPTARG"
      generation_opts=true
      ;;
    r)
      random_model=true
      generation_opts=true
      ;;
    f)
      favorite_wall=true
      ;;
    i)
      inspired_mode=true
      ;;
    w)
      weather_flag=true
      ;;
    n)
      negative_prompt="$OPTARG"
      generation_opts=true
      ;;
    *)
      echo "Usage: wallai.sh [-p \"prompt text\"] [-t theme] [-y style] [-m model] [-r] [-f] [-i] [-w] [-n \"text\"]" >&2
      exit 1
      ;;
  esac
done
shift $((OPTIND - 1))

# Default negative prompt if not provided
if [ -z "$negative_prompt" ]; then
  negative_prompt="blurry, low quality, deformed, disfigured, out of frame, low contrast, bad anatomy"
fi

# Directory where generated wallpapers live and log path
save_dir="$HOME/pictures/generated-wallpapers"
mkdir -p "$save_dir"
log_file="$save_dir/wallai.log"

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
  local dest_dir="$HOME/pictures/favorites"
  local log="$dest_dir/favorites.jsonl"
  mkdir -p "$dest_dir"
  local dest="$dest_dir/$(basename "$file")"
  cp "$file" "$dest"
  exiftool -overwrite_original -Comment="$comment" "$dest" >/dev/null
  jq -n --arg prompt "$comment" --arg theme "$theme" --arg style "$style" \
        --arg model "$model" --arg seed "$seed" --arg ts "$ts" \
        --arg filename "$(basename "$dest")" \
        '{prompt:$prompt, theme:$theme, style:$style, model:$model, seed:$seed, timestamp:$ts, filename:$filename}' >> "$log"
  echo "⭐ Added to favorites: $dest"
}

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
  printf "\r"
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
  last_prompt=$(printf '%s' "$last_entry" | cut -d'|' -f3-)
  ts=$(printf '%s' "$last_file" | cut -d'_' -f1)
  theme_slug=$(printf '%s' "$last_file" | cut -d'_' -f2)
  style_slug=$(printf '%s' "$last_file" | cut -d'_' -f3 | sed 's/\..*//')
  last_theme=$(printf '%s' "$theme_slug" | sed 's/-/ /g')
  last_style=$(printf '%s' "$style_slug" | sed 's/-/ /g')
  favorite_image "$save_dir/$last_file" "$last_prompt (seed: $last_seed)" "$last_theme" "$last_style" "unknown" "$last_seed" "$ts"
  exit 0
fi

# Inspired mode selects theme and style based on past favorites
if [ "$inspired_mode" = true ]; then
  fav_file="$HOME/pictures/favorites/favorites.jsonl"
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

# Validate selected model using the API list
mapfile -t models < <(
  curl -sL "https://image.pollinations.ai/models" | jq -r '.[]' 2>/dev/null
)
if [ "${#models[@]}" -eq 0 ]; then
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
# Usage: wallai.sh [-p "prompt text"] [-t theme] [-y style] [-m model] [-r] [-f] [-i] [-w]
# Environment variables:
#   ALLOW_NSFW         Set to 'false' to disallow NSFW prompts (default 'true')
# Flags:
#   -p prompt text  Custom prompt instead of random theme
#   -t theme        Specify theme when fetching random prompt
#   -y style        Pick a visual style or use a random one
#   -m model        Pollinations model (defaults to 'flux'). Supported models
#                   are fetched from the API (fallback: flux turbo gptimage)
#   -r              Pick a random model from the available list
#   -f              Mark the latest generated wallpaper as a favorite
#   -i              Choose theme and style inspired by favorites
#   -w              Add weather, time and seasonal context
#
# Dependencies: curl, jq, termux-wallpaper, optional exiftool for -f
# Output: saves the generated image under ~/pictures/generated-wallpapers
# TAG: wallpaper
# TAG: ai

save_dir="$HOME/pictures/generated-wallpapers"
mkdir -p "$save_dir"
timestamp="$(date +%Y%m%d-%H%M%S)"
tmp_output="$save_dir/${timestamp}.img"
seed=$(date +%s%N | sha256sum | head -c 8)


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

params="nologo=true&enhance=true&private=true&seed=${seed}&model=${model}"
if [ "$allow_nsfw" = false ]; then
  params="safe=true&${params}"
fi


if [ -z "$prompt" ]; then
  echo "🎯 Fetching random prompt from Pollinations..."

  # 🎲 Step 1: Pick or use provided theme
  if [ -z "$theme" ]; then
    themes=(
      "dreamcore" "mystical forest" "cosmic horror" "ethereal landscape"
      "retrofuturism" "alien architecture" "cyberpunk metropolis"
    )
    theme=$(printf '%s\n' "${themes[@]}" | shuf -n1)
  fi
  echo "🔖 Selected theme: $theme"

  # 🧠 Step 2: Retrieve a text prompt for that theme
  # Ask the API for exactly 15 words and pass a seed so results are repeatable
  prompt=$(curl -sL "https://text.pollinations.ai/Imagine+a+${theme}+picture+in+exactly+15+words?seed=${seed}" || true)
  # Normalize whitespace and keep only the first 15 words
  prompt=$(printf '%s' "$prompt" | tr '\n' ' ' | sed 's/  */ /g; s/^ //; s/ $//')
  prompt=$(printf '%s\n' "$prompt" | awk '{for(i=1;i<=15 && i<=NF;i++){printf $i;if(i<15 && i<NF)printf " ";}}')

  # 🛑 Fallback prompt
  if [ -z "$prompt" ]; then
    echo "❌ Failed to fetch prompt. Using fallback."
    prompt="a neon dreamscape filled with surreal creatures"
  fi
fi

# Pick a style if none was provided
if [ -z "$style" ]; then
  styles=(
    "unreal engine" "cinematic lighting" "octane render" "hyperrealism" \
    "volumetric lighting" "high detail" "4k concept art"
  )
  style=$(printf '%s\n' "${styles[@]}" | shuf -n1)
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

echo "🎨 Final prompt: $prompt"
echo "🛠 Using model: $model"

# ✨ Step 3: Generate image via Pollinations

generate_pollinations() {
  local out_file="$1"
  local encoded headers err_msg
  encoded=$(printf '%s' "$prompt" | jq -sRr @uri)
  headers=$(mktemp)
  if ! curl -sL -D "$headers" "https://image.pollinations.ai/prompt/${encoded}?${params}" -o "$out_file"; then
    rm -f "$headers"
    return 1
  fi
  generated_content_type=$(grep -i '^content-type:' "$headers" | tr -d '\r' | awk '{print $2}')
  rm -f "$headers"
  if printf '%s' "$generated_content_type" | grep -qi 'application/json'; then
    err_msg=$(jq -r '.message // .error // "Unknown error"' <"$out_file" 2>/dev/null)
    echo "❌ Pollinations error: $err_msg" >&2
    return 1
  fi
}

echo "🎨 Generating image..."
generate_pollinations "$tmp_output" &
gen_pid=$!
spinner "$gen_pid" &
spin_pid=$!
wait "$gen_pid"
status=$?
kill "$spin_pid" 2>/dev/null || true
wait "$spin_pid" 2>/dev/null || true
if [ "$status" -ne 0 ]; then
  echo "❌ Failed to generate image via Pollinations" >&2
  exit 1
fi
echo "✅ Image generated successfully"
img_source="Pollinations"

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

# Log filename, seed and prompt for later reference
echo "$filename|$seed|$prompt" >> "$log_file"

# Favorite the wallpaper immediately if -f was passed alongside generation options
[ "$favorite_wall" = true ] && favorite_image "$output" "$prompt" "$theme" "$style" "$model" "$seed" "$timestamp"

exit 0
