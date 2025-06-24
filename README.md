# Termux Scripts

A collection of small utilities for the Termux environment.

## Installation
Run `./scripts/installer.sh` to create symlinks in `$PREFIX/bin` pointing to the scripts. Shortcuts are installed as hard links under `~/.shortcuts/termux-scripts` so they work with Termux Widget. Use `-c` to copy the scripts to `~/bin`, shortcuts to `~/.shortcuts/termux-scripts`, and alias files to `~/.aliases.d/` instead. Missing packages will be offered for installation automatically. The installer also sets executable permissions so commands like `gpullall` work immediately.

To install without cloning the repository run:

```bash
curl -L https://github.com/alexknuckles/termux-scripts/releases/latest/download/installer.sh | bash -s -- -r
```

Use `-g` along with `-r` to also clone the repository to `~/git/termux-scripts` after installing.
The installer updates your shell configuration to source every `*.aliases` file in `~/.aliases.d/` on startup.
Shortcut scripts are located in the `termux-scripts-shortcuts` directory.

## wallai.sh

Generates an AI-based wallpaper using the free Pollinations API. The script requests a 15-word
description for a random theme and includes a unique seed so prompts vary even for the same theme.
You can choose between several Pollinations models using the `-m` flag or let the
script pick one at random with `-r`. Models are retrieved from the Pollinations
API. If that fails the script falls back to `flux`, `turbo` and `gptimage`. The
random option ignores `gptimage` (requires a flower-tier account) and `turbo`
due to low quality. The default model is `flux`.

### Usage
```bash
wallai [-p "prompt text"] [-t theme] [-m model] [-r]
```

Environment variables:
- `ALLOW_NSFW` set to `false` to disallow NSFW prompts (defaults to `true`).

Flags:
- `-p` Specify your own prompt instead of fetching a random one.
- `-t` Choose a theme for the random prompt (ignored if `-p` is used).
- `-m` Select Pollinations model. Available models come from the API and usually
  include `flux`, `turbo` and `gptimage`. `flux` is used if none is provided.
  The `gptimage` model requires a flower-tier Pollinations account; without
  access the API returns an error. The `turbo` model tends to produce lower quality images.
- `-r` Pick a random model from the available list, excluding `gptimage` and `turbo`.

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

## githelper.sh

Provides shortcuts for common git tasks and automates pulling
all repositories under `~/git`.

### Usage
```bash
githelper <pull-all|push-all|status|push|clone|init|revert-last|clone-mine|newrepo|set-next|set-next-all>
```

Examples:
- `githelper pull-all` updates every repository in `~/git`.
- `githelper push-all` pushes each repository in `~/git` to its main branch. Use `-c` to enter a commit message for all.
- `githelper clone -u <url>` clones a repository using `gh` if available.
- `githelper init` initializes a new repo in the current directory.
- `githelper revert-last` reverts the most recent commit.
- `githelper clone-mine` clones all your GitHub repositories to `~/git`. Specify a different user with `-u`.
- `githelper newrepo [-d dir] [-ns] [description]` creates a new repo with an AI-generated README and agents file. Scanning files is enabled by default; use `-ns` to disable scanning and `-d` to specify a different directory.
- `githelper set-next` tags the current repository as the next release and pushes the tag. Use `-p` for a description prompt.
- `githelper set-next-all` performs the same tag operation on every repository in `~/git`.

Dependencies: `git`, `jq`, optional `gh` for GitHub integration.
