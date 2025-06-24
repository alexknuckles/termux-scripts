# Termux Scripts

A collection of small utilities for the Termux environment.

## wallai.sh

Generates an AI-based wallpaper using the free Pollinations API.

### Usage
```bash
wallai.sh [-p "prompt text"]
```

Environment variables:
- `ALLOW_NSFW` set to `false` to disallow NSFW prompts (defaults to `true`).

Flags:
- `-p` Specify your own prompt instead of fetching a random one.

If no prompt is provided, the script retrieves a themed scene from the
Pollinations text API using a random genre such as fantasy or cyberpunk.
Fetched text is cleaned up so the final prompt is concise and descriptive.

Dependencies: `curl`, `jq`, `termux-wallpaper`.
If any of these tools are missing the script exits with a clear error
message. Internet access is required for fetching prompts and generating
the image.

### Installation
Run `./install.sh` to place the script in `$PREFIX/bin`.
