# Termux Scripts

A collection of small utilities for the Termux environment.

## wallai.sh

Generates an AI-based wallpaper using Stable Horde and sets it as your Termux wallpaper.

### Usage
```bash
wallai.sh
```

Environment variables:
- `HORDE_WIDTH` and `HORDE_HEIGHT` for image dimensions (<=576).
- `HORDE_MAX_CHECKS` to control how many times the script polls for completion.
- `HORDE_BASE_MODELS` optional newline-separated list of base models used as
  fallbacks when the selected image lacks one (defaults include `SDXL 1.0`,
  `SD 1.5`, `SD 2.1 768`).

Dependencies: `curl`, `jq`, `termux-wallpaper`.
If any of these tools are missing the script exits with a clear error
message. Internet access is required for fetching prompts and generating
the image.

### Installation
Run `./install.sh` to place the script in `$PREFIX/bin`.
