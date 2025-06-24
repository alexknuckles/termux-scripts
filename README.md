# Termux Scripts

A collection of small utilities for the Termux environment.

## wallai.sh

Generates an AI-based wallpaper using the free Pollinations API.

### Usage
```bash
wallai.sh
```

Environment variables:
- `ALLOW_NSFW` set to `false` to disallow NSFW prompts (defaults to `true`).

Dependencies: `curl`, `jq`, `termux-wallpaper`, `termux-vibrate`.
If any of these tools are missing the script exits with a clear error
message. Internet access is required for fetching prompts and generating
the image. The script plays a short vibration in the "shave and a haircut" pattern when finished.

### Installation
Run `./install.sh` to place the script in `$PREFIX/bin`.
