#!/data/data/com.termux/files/usr/bin/bash

apikey="0000000000"
# Dimensions must be <=576 to avoid extra kudos on Stable Horde
width="${HORDE_WIDTH:-512}"
height="${HORDE_HEIGHT:-512}"
save_dir="$HOME/pictures/generated-wallpapers"
mkdir -p "$save_dir"
filename="$(date +%Y%m%d-%H%M%S).png"
output="$save_dir/$filename"

echo "🎯 Fetching random prompt from Civitai..."

# 🎲 Step 1: Get a random tag
tag=$(curl -s "https://civitai.com/api/v1/tags?limit=200" \
  | jq -r '.items[].name' | shuf -n 1)
echo "🔖 Selected tag: $tag"

# 🧠 Step 2: Get a prompt from an image using that tag (NSFW allowed)
prompt=$(curl -s "https://civitai.com/api/v1/images?limit=100&nsfw=true&tag=$tag" \
  -H "Content-Type: application/json" \
  | jq -r '[.items[].meta.prompt] | map(select(. != null and . != "")) | .[]' \
  | shuf -n 1)

# 🛑 Fallback prompt
if [ -z "$prompt" ]; then
  echo "❌ No prompt found for tag $tag. Using fallback."
  prompt="a neon dreamscape filled with surreal creatures"
fi

echo "🎨 Final prompt: $prompt"

# ✨ Step 3: Generate image via Horde
response=$(curl -s -X POST "https://stablehorde.net/api/v2/generate/async" \
  -H "Content-Type: application/json" \
  -H "apikey: $apikey" \
  -H "Client-Agent: termux-horde-script:1.0:alex" \
  -d @- <<EOF
{
  "prompt": "$prompt",
  "params": {
    "width": $width,
    "height": $height,
    "steps": 20,
    "sampler_name": "k_euler_a",
    "cfg_scale": 7,
    "n": 1,
    "karras": true
  },
  "nsfw": true,
  "censor_nsfw": false
}
EOF
)
id=$(echo "$response" | jq -r '.id')

if [ "$id" = "null" ] || [ -z "$id" ]; then
  echo "❌ Failed to submit image generation job."
  exit 1
fi

echo "⏳ Submitted to Horde. ID: $id"

# 🔄 Poll for result
for i in $(seq 1 15); do
  echo "⏳ Checking status (attempt $i)..."
  status=$(curl -s "https://stablehorde.net/api/v2/generate/status/$id")
  done_flag=$(echo "$status" | jq -r '.done')
  if [ "$done_flag" = "true" ]; then
    echo "✅ Image ready!"
    break
  fi
  sleep 10
done

img_url=$(echo "$status" | jq -r '.generations[0].img')
if [ "$img_url" = "null" ] || [ -z "$img_url" ]; then
  echo "❌ No image URL received."
  exit 1
fi

curl -sL "$img_url" -o "$output"
termux-wallpaper -f "$output"
echo "🎉 Wallpaper set from prompt: $prompt"
echo "💾 Saved to: $output"
