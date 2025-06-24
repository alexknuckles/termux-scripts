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

Dependencies: `curl`, `jq`, `termux-wallpaper`.

### Installation
Run `./install.sh` to place the script in `$PREFIX/bin`.
