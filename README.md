# Termux Scripts

A collection of small utilities for the Termux environment.

## wallai.sh

Generates an AI-based wallpaper using the free Pollinations API. The script requests a 15-word
description for a random theme and includes a unique seed so prompts vary even for the same theme.

### Usage
```bash
wallai.sh [-p "prompt text"] [-t theme]
```

Environment variables:
- `ALLOW_NSFW` set to `false` to disallow NSFW prompts (defaults to `true`).

Flags:
- `-p` Specify your own prompt instead of fetching a random one.
- `-t` Choose a theme for the random prompt (ignored if `-p` is used).

If no prompt is provided, the script retrieves a themed picture description from the Pollinations text
API using a random genre such as fantasy or cyberpunk. You can override the random choice with
`-t theme`. The API is asked to respond in exactly 15 words. A random seed parameter ensures that
repeated calls yield different descriptions even when the theme is the same.

Dependencies: `curl`, `jq`, `termux-wallpaper`.
If any of these tools are missing the script exits with a clear error
message. Internet access is required for fetching prompts and generating
the image.

### Installation
Run `./install.sh` to place the script in `$PREFIX/bin`.

## git-helper.sh

Provides shortcuts for common git tasks and automates pulling
all repositories under `~/git`.

### Usage
```bash
git-helper.sh <pull-all|status|push|clone>
```

Examples:
- `git-helper.sh pull-all` updates every repository in `~/git`.
- `git-helper.sh clone <url>` clones a repository using `gh` if available.

Dependencies: `git`, optional `gh` for GitHub integration.
