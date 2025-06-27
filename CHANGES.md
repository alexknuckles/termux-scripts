- Applying previous commit.
- Add gpull command to githelper with alias.
- Installer now copies to `~/bin/termux-scripts` by default and no longer
  accepts the `-c` flag.
- Installer tracks installed version to avoid unnecessary reinstalls.
- README links refer to stable or testing releases.
- Pre-release tag renamed to `testing` in githelper.
- gnext and gnextall now explicitly set the `testing` tag.
- Simplified `set-next` and `set-next-all` to only accept `-r`; prerelease uses
  the `testing` tag by default.
- gnext -r now removes the `testing` tag and creates a release tag.
- Pre-releases now list commits since the previous tag when creating GitHub releases.
- githelper-setnextall shortcut no longer forces the `testing` tag.
- Removed the `-g` option from the installer. Use the testing installer to clone and install from the latest commit.
- Documented Termux, Termux Widget and Termux API requirements with F-Droid links.
- Installer now ensures `~/bin/termux-scripts` is on the PATH and exports it for immediate use.
- Installer now appends the path to `~/.bashrc`, sources it and loads the alias file immediately.

- gnext and gnextall now configure gh git credentials automatically when needed.

- Shortcut scripts now use absolute paths to installed commands for reliability with Termux Widget.
- wallai now logs prompts with filenames and can archive the last wallpaper with exif metadata using `-s`.
- New `walfave` alias archives the current wallpaper without generating a new image.
- wallai now names wallpapers with the correct extension based on the API response.
- Installer now prints the path to walfave after installation.

- Removed the walfave script. The alias now calls `wallai -f` to archive the
  latest wallpaper.

- Renamed wallai-save shortcut to walfave-shortcut for clarity.
- Uninstaller now spawns a fresh shell to remove loaded aliases.
- githelper newrepo now requires `-m` for the description and uses `-n` to disable scanning.
- githelper newrepo gracefully handles invalid Pollinations responses.
- Fixed githelper newrepo failing when committing in an empty directory.
- Improved wallai header comments and tags.
- Added APIFallback agent to validate API error handling.
- Added lint script and test harness for githelper newrepo.
- Added SecurityCheck script and silenced shellcheck warnings in installer.
- Updated lint, security check and test scripts to use Termux bash shebang.
- `wallai -f` now archives the last wallpaper without generating a new image.
- Removed obsolete `tests/test_newrepo.sh`; its checks are now covered elsewhere.
- Removed broken listcmds script.
- `gpush` now stages, commits with "gpush-ed", and pushes to the main branch.
- `gpushall` now automatically stages, commits with "gpush-ed", and pushes each repo to the main branch.
- Updated README with githelper push docs, clearer set-next notes and F-Droid badges.
- Switched to remote F-Droid badge and removed local image.
- githelper newrepo now sets the initial branch to `main` and creates a private GitHub repository named after the directory.
- Fixed githelper newrepo using '.' as the project name when run in the current directory.
- Testing installer now clones the repo for bleeding edge installs.
- Release installer no longer clones the repo and README clarifies the usage.
- Removed cleanup of old git clone path from installer uninstall routine.
- Added repo logo to README.
- Arranged Termux app requirements into three columns in the README.
- Upload workflow now triggers once and attaches the correct installer.
- Testing installer now attaches to testing releases.
- githelper set-next now creates annotated tags and aborts if the push fails to prevent untagged releases.
- gnext now deletes the old testing release so GitHub Actions publishes a fresh prerelease.
- githelper now creates a default .gitignore to skip __pycache__ and other common cruft.
- wallai now supports a `-y` flag for picking a visual style. Styles are chosen at random if omitted, and the theme list has been expanded.
- wallai gains theme and style weighting, negative prompt support with `-n`,
  Pollinations parameters for logo removal and enhancement, slugified filenames
  and seed logging for repeatable generations.
- wallai adds a favorites system via `-f`, inspired mode with `-i`,
  weather-aware prompting with `-w` and an emoji spinner during image generation.
- wallai now falls back to a local list of prompts if the API request fails.
- wallai retries Pollinations API calls and prints the success message on a new line.
- wallai validates downloaded files and retries if the file is not an image.
- wallai supports per-group configuration with auto-bootstrap, discovery mode via `-d`,
  group-based favorites with `-f [group]` and generation with `-g [group]`.
- Config bootstrapping now includes the full list of default themes and styles.
- wallai now supports a -v flag to print API URLs and responses.
- Fixed `-d` erroneously consuming the next flag as its argument. Verbose mode now works with discovery.
- Added `-l` to wallai to reuse theme and style from the last image.
- wallai now uses unique seeds for discovery and logs them for repeatability.
- wallai now supports a `-h` flag to display usage information.
