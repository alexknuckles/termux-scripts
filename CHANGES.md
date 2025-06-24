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
