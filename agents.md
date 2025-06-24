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

---

## 📝 DocGen

**Goal:**  
Auto-generate `README.md` and inline comments:

- Script name, purpose, usage examples
- Dependencies (e.g. `curl`, `jq`, `gh`, etc.)
- Flags and arguments
- Output expectations

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

## 🛠 Installer

**Goal:**  
Generate an `install.sh` script that:

- Symlinks or copies scripts to `$PREFIX/bin`
- Sets executable permissions
- Optionally installs shortcuts and aliases
- Use hard links for shortcut files since Termux Widget doesn't
  always follow symlinks

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

---
