# Termux Scripts

A collection of small utilities for the Termux environment.

## Requirements
- [Termux](https://f-droid.org/packages/com.termux/) – obviously required
- [Termux Widget](https://f-droid.org/packages/com.termux.widget/) for shortcut support
- [Termux:API](https://f-droid.org/packages/com.termux.api/) for wallpaper and other integrations

## Installation
Run `./scripts/installer.sh` to install the scripts. They are copied to `~/bin/termux-scripts`, shortcuts under `~/.shortcuts/termux-scripts`, and an alias file in `~/.aliases.d/`. Missing packages will be offered for installation automatically. The installer also sets executable permissions so commands like `gpullall` and `gpull` work immediately. It appends `~/bin/termux-scripts` to your `~/.bashrc` and exports it so the utilities are available right away. The alias file is sourced as soon as it's installed. Pass `-u` to remove everything created by a previous run.

To install the stable release without cloning the repository run:

```bash
curl -L https://github.com/alexknuckles/termux-scripts/releases/latest/download/installer.sh | bash -s -- -r
```

To install the testing version run:

```bash
curl -L https://github.com/alexknuckles/termux-scripts/releases/download/testing/installer.sh | bash -s -- -r
```

Use `-g` to clone the repository to `~/git/termux-scripts` first and install from that local copy, avoiding an additional download.
The installer updates your shell configuration to source every `*.aliases` file in `~/.aliases.d/` on startup.
Shortcut scripts are located in the `termux-scripts-shortcuts` directory.
Run the installer with `-u` to remove the symlinks, shortcuts and alias file and clean up the shell configuration. A new shell starts afterward so any loaded aliases are cleared.

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
wallai [-p "prompt text"] [-t theme] [-m model] [-r] [-s]
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
- `-s` Save the latest generated wallpaper to `~/pictures/saved-generated-wallpapers/` with the prompt embedded using `exiftool`.

After showing the chosen prompt, the script also prints which Pollinations model will
be used for image generation.

If no prompt is provided, the script retrieves a themed picture description from the Pollinations text
API using a random genre such as fantasy or cyberpunk. You can override the random choice with
`-t theme`. The API is asked to respond in exactly 15 words. A random seed parameter ensures that
repeated calls yield different descriptions even when the theme is the same.

Dependencies: `curl`, `jq`, `termux-wallpaper`, optional `exiftool` for the `-s` option (also used by the `walsave` alias).
Images are saved as PNG or JPEG depending on what the API returns.
If any of these tools are missing the script exits with a clear error
message. Internet access is required for fetching prompts and generating
the image.

The installer creates a `walsave` alias and `walsave-shortcut.sh` so you
can archive the currently set wallpaper with metadata via `wallai -s`.

## githelper.sh

Provides shortcuts for common git tasks and automates pulling
all repositories under `~/git`.

### Usage
```bash
githelper <pull-all|push-all|status|pull|push|clone|init|revert-last|clone-mine|newrepo|set-next|set-next-all>
```

Examples:
- `githelper pull-all` updates every repository in `~/git`.
- `githelper push-all` pushes each repository in `~/git` to its main branch. Use `-c` to enter a commit message for all.
- `githelper pull` pulls the latest changes for the current repository.
- `githelper clone -u <url>` clones a repository using `gh` if available.
- `githelper init` initializes a new repo in the current directory.
- `githelper revert-last` reverts the most recent commit.
- `githelper clone-mine` clones all your GitHub repositories to `~/git`. Specify a different user with `-u`.
- `githelper newrepo [-d dir] [-n] [-m description]` creates a new repo with an AI-generated README and agents file. Scanning files is enabled by default; use `-n` to disable scanning, `-d` to choose a directory and `-m` to provide a description. The script uses the Pollinations API but falls back to plain text if the response isn't valid JSON.
- `githelper set-next` creates a prerelease with the `testing` tag by default. Use `-r` for a full release which automatically increments from the latest `v*` tag.
- `githelper set-next-all` runs the same command across every repository in `~/git`.
- Both commands ensure `gh auth setup-git` has configured credentials so pushes won't prompt for a password.

Dependencies: `git`, `jq`, optional `gh` for GitHub integration.
Use `scripts/lint.sh` to run ShellCheck, `scripts/security_check.sh` to scan for risky patterns, and `tests/test_newrepo.sh` for a basic test of githelper newrepo.
