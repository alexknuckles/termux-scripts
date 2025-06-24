#!/data/data/com.termux/files/usr/bin/bash

apikey="0000000000"
# Dimensions must be <=576 to avoid extra kudos on Stable Horde
width="${HORDE_WIDTH:-512}"
height="${HORDE_HEIGHT:-512}"
save_dir="$HOME/pictures/generated-wallpapers"
mkdir -p "$save_dir"
filename="$(date +%Y%m%d-%H%M%S).png"
output="$save_dir/$filename"

# Grab list of models available on Stable Horde
horde_models=$(curl -s "https://stablehorde.net/api/v2/status/models" | jq -r '.[].name')

echo "🎯 Fetching random prompt from Civitai..."

# 🎲 Step 1: Get a random tag
tag=$(curl -s "https://civitai.com/api/v1/tags?limit=200" \
  | jq -r '.items[].name' | shuf -n 1)
echo "🔖 Selected tag: $tag"

# 🧠 Step 2: Get a prompt and model from an image using that tag (NSFW allowed)
image_info=$(curl -s "https://civitai.com/api/v1/images?limit=100&nsfw=true&tag=$tag" \
  -H "Content-Type: application/json")
encoded=$(echo "$image_info" | jq -r '[.items[] | {prompt: .meta.prompt, baseModel: .baseModel}] | map(select(.prompt != null and .prompt != "")) | .[] | @base64' | shuf -n 1)
prompt=$(echo "$encoded" | base64 --decode | jq -r '.prompt')
base_model=$(echo "$encoded" | base64 --decode | jq -r '.baseModel')

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

# ✨ Step 3: Generate image via Horde
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
