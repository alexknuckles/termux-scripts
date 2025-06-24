# Termux Scripts

A collection of small utilities for the Termux environment.

## wallai.sh

Generates an AI-based wallpaper using the free Pollinations API. The script requests a 15-word
description for a random theme and includes a unique seed so prompts vary even for the same theme.
You can choose between several Pollinations models using the `-m` flag or let the
script pick one at random with `-r`. Models are retrieved from the Pollinations
API. If that fails the script falls back to `flux`, `turbo` and `gptimage`. The
default model is `flux`.

### Usage
```bash
wallai.sh [-p "prompt text"] [-t theme] [-m model] [-r]
```

Environment variables:
- `ALLOW_NSFW` set to `false` to disallow NSFW prompts (defaults to `true`).

Flags:
- `-p` Specify your own prompt instead of fetching a random one.
- `-t` Choose a theme for the random prompt (ignored if `-p` is used).
- `-m` Select Pollinations model. Available models come from the API and usually
  include `flux`, `turbo` and `gptimage`. `flux` is used if none is provided.
  The `gptimage` model requires a flower-tier Pollinations account; without
  access the API returns an error.
- `-r` Pick a random model from the available list.

After showing the chosen prompt, the script also prints which Pollinations model will
be used for image generation.

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

## githelper.sh

Provides shortcuts for common git tasks and automates pulling
all repositories under `~/git`.

### Usage
```bash
githelper.sh <pull-all|status|push|clone|init|revert-last|clone-mine|newrepo>
```

Examples:
- `githelper.sh pull-all` updates every repository in `~/git`.
- `githelper.sh clone -u <url>` clones a repository using `gh` if available.
- `githelper.sh init` initializes a new repo in the current directory.
- `githelper.sh revert-last` reverts the most recent commit.
- `githelper.sh clone-mine` clones all your GitHub repositories to `~/git`. Specify a different user with `-u`.
- `githelper.sh newrepo [-d dir] [-ns] [description]` creates a new repo with an AI-generated README and agents file. Scanning files is enabled by default; use `-ns` to disable scanning and `-d` to specify a different directory.

Dependencies: `git`, `jq`, optional `gh` for GitHub integration.
