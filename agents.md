# 🧠 Codex Agents for Termux Scripts

This file defines a set of agents to optimize and manage the Termux Scripts repository.

---

## 🚦 Linter

**Goal:**  
Ensure all shell scripts follow best practices:

- POSIX-compatible where feasible
- Use `#!/data/data/com.termux/files/usr/bin/bash` shebang
- Set `set -euo pipefail` at the top
- Quote variables and use `"$@"` for arguments
- Prefer single-letter flags for command arguments
- All scripts and commands should expose flags for each argument
- Run `scripts/lint.sh` to check for ShellCheck warnings

---

## 📝 DocGen

**Goal:**  
Auto-generate `README.md` and inline comments:

- Script name, purpose, usage examples
- Dependencies (e.g. `curl`, `jq`, `gh`, etc.)
- Flags and arguments
- Output expectations
- Document every subcommand in the header comment of each script

---

## 🔗 AliasMaker

**Goal:**  
Generate a `.aliases` file or `.shortcuts` compatible with Termux:

- Suggest short, intuitive aliases for frequently used scripts
- Respect common CLI idioms (`netinfo`, `pushgit`, etc.)
- Optionally generate bash-compatible exports for `$PATH` use
- Ensure every script has a short alias entry in `aliases/aliases`
- Provide a matching shortcut script in the `termux-scripts-shortcuts` directory
- Create shortcut files only for githelper subcommands that are
  context-free—they must not depend on the current directory or require
  additional arguments. Valid examples are `pull-all`, `push-all`, and
  `clone-mine` which become shortcuts like `githelper-pullall.sh`.
- Shortcut filenames must mirror the alias name exactly to avoid confusion

---

## ⏰ Scheduler

**Goal:**  
Identify scripts that should be scheduled:

- Create crontab entries (e.g., backups, updates)
- Suggest `termux-job-scheduler` equivalents for event-based tasks

---

## 🧼 Optimizer

**Goal:**  
Improve performance and reduce redundancy:

- Inline multiple pipes where beneficial
- Cache repeated values (e.g., date stamps)
- Replace slow commands with faster alternatives

---

## 🔒 SecurityCheck

**Goal:**  
Scan for risky patterns:

- Unchecked `rm`, `mv`, or `dd` usage
- Missing validation on user inputs
- Suggest confirmation prompts or `--dry-run` flags

---

## 🌐 APIFallback

**Goal:**
Ensure scripts gracefully handle network failures or invalid API responses:

- Mock failing responses such as invalid JSON or network errors
- Verify Pollinations integrations produce fallback output
- Add simple tests for critical API-dependent commands

---

## 🧹 InputSanitizer

**Goal:**
Ensure strings sent to APIs are properly escaped and validated:

- Escape prompts before inserting into JSON bodies
- Use `jq` to validate JSON responses when possible
- Add tests that run scripts with quotes and other special characters

---

## 🛠 Installer

**Goal:**  
Generate an `install.sh` script that:

- Symlinks or copies scripts to `$PREFIX/bin`
- Sets executable permissions
- Optionally installs shortcuts and aliases
- Use hard links for shortcut files since Termux Widget doesn't
  always follow symlinks
- Print a confirmation line for each installed command so none are missed
- Append the install directory to the user's shell rc and export PATH so new commands work immediately
- Uninstall should spawn a fresh shell to clear loaded aliases

---

## 🏷 Tagger

**Goal:**  
Add frontmatter or inline tags for script categorization:

- `# TAG: networking`, `# TAG: git`, etc.
- Helps future agents or UI tools filter/group scripts

---

## 🧪 Tester _(optional)_

**Goal:**
If any scripts have flags or interactive input, generate minimal test cases or test harnesses.
Specifically ensure `githelper newrepo` succeeds when run in an empty directory and creates an initial commit.
Run any newly added or modified scripts, functions or commands before opening a pull request to confirm they execute without immediate errors.
- `tests/test_wallai.sh` runs during environment setup while network access is available. Do not rerun after the sandbox drops connectivity. Failures are logged under `/tmp/wallai-tests` with a `failures.log` summary. The script must keep running even when tests fail so issues can be fixed during the session.

---

## 📝 ChangeTracker

**Goal:**
Maintain a running changelog so new releases can be generated automatically:

- Record notable commit messages since the last version in `CHANGES.md`
- Summaries should be brief bullet points
- Used by `gnext` when no description is provided

---

## 🔄 CI Runner

**Goal:**
Automate running lint scripts (and any tests) on every commit:

- Execute `scripts/lint.sh`
- Fail if any command returns a non-zero status
- Intended for GitHub Actions or similar CI setup

---

## 🔍 AuditBot

**Goal:**
Continuously review the repository and agent definitions:

 - Run `scripts/lint.sh` and `scripts/security_check.sh` on a schedule and whenever new scripts are added
- Scan for unreachable or incomplete logic in shell functions
- Ensure every script and function has a descriptive header with usage examples
- Inspect `agents.md` and propose new agents if commit logs reveal manual fixes
- Record findings and references in `AUDIT.md`
