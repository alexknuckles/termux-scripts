# Termux Scripts

A collection of small utilities for the Termux environment.

## wallai.sh

Generates an AI-based wallpaper using the free Pollinations API. The script requests a 15-word
description for a random theme and includes a unique seed so prompts vary even for the same theme.
You can choose between several Pollinations models using the `-m` flag. Available models are
`flux` (default), `turbo`, `flux-realism`, `flux-anime`, `flux-3d`, `flux-pro`, `anydark`,
and `gptimage`.

### Usage
```bash
wallai.sh [-p "prompt text"] [-t theme] [-m model]
```

Environment variables:
- `ALLOW_NSFW` set to `false` to disallow NSFW prompts (defaults to `true`).

Flags:
- `-p` Specify your own prompt instead of fetching a random one.
- `-t` Choose a theme for the random prompt (ignored if `-p` is used).
- `-m` Select Pollinations model: `flux` (default), `turbo`, `flux-realism`, `flux-anime`,
  `flux-3d`, `flux-pro`, `anydark`, or `gptimage`.

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
git-helper.sh <pull-all|status|push|clone|init|revert-last|clone-mine>
```

Examples:
- `git-helper.sh pull-all` updates every repository in `~/git`.
- `git-helper.sh clone <url>` clones a repository using `gh` if available.
- `git-helper.sh init` initializes a new repo in the current directory.
- `git-helper.sh revert-last` reverts the most recent commit.
- `git-helper.sh clone-mine` clones all your GitHub repositories to `~/git`.

Dependencies: `git`, `jq`, optional `gh` for GitHub integration.
