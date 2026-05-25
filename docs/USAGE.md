# Usage Reference

Flag reference, examples, post-install steps, and troubleshooting. For installation instructions, see [SETUP.md](SETUP.md).

---

## Flags

| Flag               | Description                                                                                                                              |
|--------------------|------------------------------------------------------------------------------------------------------------------------------------------|
| `--help`           | Print flag reference. `--help <flag>` expands detail and examples for that flag.                                                         |
| `--verbose`        | Show external tool output in terminal (delimited blocks) and tee to `~/.linux-init-bootstrap.log`.                                       |
| `--skip-dotfiles`  | Skip the dotfiles section after tool installation.                                                                                       |
| `--modules <list>` | Run only the specified modules (comma-separated). Valid names: `packages`, `shell`, `chezmoi`, `python`, `java`, `node`, `ai`, `containers`. |
| `--clean-tools`    | Remove dev tools, symlinks, and tool state entries; run package cleanup. Preserves shell + dotfiles.                                     |
| `--reinstall`      | Full state reset + clean tools + complete reinstall from scratch.                                                                        |
| `--clean-install`  | Remove everything (tools, dotfiles, state) and reinstall. Use `--reinstall` to keep dotfiles.                                            |

### `--verbose`

Shows output from external tools (apt, git clone, curl installers) in the terminal, wrapped in delimited blocks. Output is always written to the log file regardless.

```bash
bash bootstrap.sh --verbose
```

### `--skip-dotfiles`

Runs all tool modules normally but skips the dotfiles section entirely. Useful when re-running bootstrap after a failed tool install without touching dotfiles.

```bash
bash bootstrap.sh --skip-dotfiles
```

### `--modules <list>`

Runs only the specified modules, skipping all others. Takes a comma-separated list of module names.

Valid names: `packages`, `shell`, `chezmoi`, `python`, `java`, `node`, `ai`, `containers`

```bash
# Install only the AI tools
bash bootstrap.sh --modules ai

# Install Java and Node together
bash bootstrap.sh --modules java,node

# Re-run Python after resetting its state
sed -i '/^module_03/d' ~/.bootstrap-state
bash bootstrap.sh --modules python
```

Module dependencies still apply: `--modules ai` will offer to install Node.js first if it is absent.

### `--clean-tools`

Removes dev tool directories and tool state entries; preserves shell configuration and dotfiles.

**Removes:**
- `~/Dev/tools/python/`, `~/Dev/tools/node/`, `~/Dev/tools/java/`, `~/Dev/tools/ai/`
- `/usr/local/bin/node` symlink
- State entries for modules `03_python` through `07_containers`
- Package cleanup: `apt autoclean && apt autoremove -y` (or dnf / brew equivalent)

**Preserves:** Oh My Zsh, Powerlevel10k, plugins, chezmoi dotfiles, system packages.

```bash
bash bootstrap.sh --clean-tools
```

### `--reinstall`

Equivalent to `--clean-tools` plus a full bootstrap run from scratch. Removes all state and re-runs all phases.

```bash
bash bootstrap.sh --reinstall
```

### `--clean-install`

Removes everything — tools, managed dotfiles (via `chezmoi purge`), and the state file — then reinstalls. Use `--reinstall` if you want to keep your dotfiles.

```bash
bash bootstrap.sh --clean-install
```

---

## Log File

All runs append to `~/.linux-init-bootstrap.log`. Format:

```
[YYYY-MM-DD HH:MM:SS.ssssss - PID - function_name] LEVEL  message
```

On WSL2, the Windows-side scripts write to `%USERPROFILE%\linux-init-bootstrap_win.log` with the same format.

To follow the log during a run:

```bash
tail -f ~/.linux-init-bootstrap.log
```

---

## Post-Install Manual Steps

After the bootstrap completes, some tools require manual authentication.

### Claude Code

```bash
claude
```

Follow the onboarding steps — the CLI guides you through login interactively.

### Gemini CLI

```bash
gemini
```

Follow the onboarding steps.

### GitHub Copilot CLI

The bootstrap installs `gh` (GitHub CLI) but the `gh copilot` extension requires manual install and authentication.

```bash
# Authenticate gh (choose GitHub.com or your enterprise host)
gh auth login

# Install the Copilot extension
gh extension install github/gh-copilot

# Follow the onboarding steps
gh copilot --version
```

---

## Tool Confirmation Prompts

Each module installs its package manager unconditionally, then prompts individually for each optional tool:

| Module      | Always installed | Prompted per tool            |
|-------------|------------------|------------------------------|
| `03_python` | uv               | Python LTS                   |
| `04_java`   | SDKman           | JDK 25 (Zulu), Maven, Gradle |
| `05_node`   | NVM              | Node.js LTS                  |
| `06_ai`     | —                | Claude Code, Gemini CLI      |

Declined tools are recorded as `skipped` and re-prompted on the next run. Tools already installed are shown as `⊙ already installed` with a `--clean-tools` hint.

In non-interactive mode (piped input or no TTY), all prompts default to **Y**.

### Non-interactive mode

The bootstrap detects whether a real terminal is available by probing `/dev/tty`. If no TTY is present (e.g. piped input, CI, or `bash bootstrap.sh < /dev/null`), all confirmation prompts auto-accept with **Y** and the SSH signing-key selection auto-picks the first key returned by the 1Password agent.

This allows unattended runs:

```bash
# Fully unattended — all prompts accept Y, first SSH key selected automatically
bash bootstrap.sh < /dev/null
```

The Windows prerequisite script (`setup-windows.ps1`) receives a `-NonInteractive` flag from `bootstrap.sh` in this case and applies the same auto-selection logic.

## Module Dependencies

`06_ai.sh` requires Node.js. If run via `--modules ai` without Node.js installed, the bootstrap offers to install it via NVM before continuing. If NVM is also absent, the user is directed to run `--modules node` first.

---

## Troubleshooting

### A module failed mid-run

Re-run `bootstrap.sh` — it resumes from the last incomplete module automatically.

### Reset and re-run a single module

```bash
# Example: reset all Python state (re-prompts for Python LTS)
sed -i '/^module_03/d' ~/.bootstrap-state
bash bootstrap.sh

# Example: reset only the Java tools (re-prompts for JDK, Maven, Gradle)
sed -i '/^module_04/d' ~/.bootstrap-state
bash bootstrap.sh
```

### Full reset (keep dotfiles)

```bash
bash bootstrap.sh --reinstall
```

### Full reset (remove dotfiles too)

```bash
bash bootstrap.sh --clean-install
```

### SSH known_hosts setup had issues

```bash
ssh-keyscan -H github.com >> ~/.ssh/known_hosts
ssh-keyscan -H gitlab.com >> ~/.ssh/known_hosts
ssh-keyscan -H bitbucket.org >> ~/.ssh/known_hosts
```

### Dotfiles not applied

Re-run the bootstrap — it will retry the dotfiles step:

```bash
bash bootstrap.sh
```

Check the log for details:

```bash
grep -i "dotfiles\|chezmoi" ~/.linux-init-bootstrap.log | tail -20
```
