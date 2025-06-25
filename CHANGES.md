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
- Installer with `-g` clones first and installs from the clone to avoid duplicate downloads.
- Documented Termux, Termux Widget and Termux API requirements with F-Droid links.
- Installer now ensures `~/bin/termux-scripts` is on the PATH and exports it for immediate use.
- Installer now appends the path to `~/.bashrc`, sources it and loads the alias file immediately.

- gnext and gnextall now configure gh git credentials automatically when needed.

- Shortcut scripts now use absolute paths to installed commands for reliability with Termux Widget.
- wallai now logs prompts with filenames and can archive the last wallpaper with exif metadata using `-s`.
- New `walsave` alias archives the current wallpaper without generating a new image.
- wallai now names wallpapers with the correct extension based on the API response.
- Installer now prints the path to walsave after installation.

- Renamed wallai-save shortcut to walsave-shortcut for clarity.
- Uninstaller now spawns a fresh shell to remove loaded aliases.
- githelper newrepo now requires `-m` for the description and uses `-n` to disable scanning.
- githelper newrepo gracefully handles invalid Pollinations responses.
- Fixed githelper newrepo failing when committing in an empty directory.
- Improved wallai header comments and tags.
- Added APIFallback agent to validate API error handling.
- Added lint script and test harness for githelper newrepo.
