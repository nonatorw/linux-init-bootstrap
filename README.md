# linux-init-bootstrap

Minimal bootstrap script for setting up a Linux development environment from scratch.
Installs development tools, populates SSH known_hosts, clones
[chezmoi-dotfiles](https://github.com/nonatorw/chezmoi-dotfiles), and applies dotfiles —
all in a single command.

## Documentation

- [docs/SETUP.md](docs/SETUP.md) — step-by-step installation guide (start here)
- [docs/USAGE.md](docs/USAGE.md) — flags, examples, post-install, troubleshooting

## Overview

The bootstrap is split into three phases. On a fresh WSL2 machine, run them in order.
On a native Linux machine, only Phase 3 is needed.

```text
Phase 1 (Windows — WSL2 only): Windows prerequisites
  setup-windows-admin.ps1   ← run once, elevated PowerShell
  setup-windows.ps1         ← auto-invoked by bootstrap.sh

Phase 2 (Linux prereqs):         WSL2 + standalone Linux
  setup-prereqs-linux.sh              ← run before bootstrap.sh

Phase 3 (WSL / Linux):      Tool install + dotfiles
  bootstrap.sh              ← main entry point
```

## Quick Start

### WSL2

```powershell
# Windows: run once from elevated PowerShell
Set-ExecutionPolicy Bypass -Scope Process -Force
.\setup-windows-admin.ps1
```

```bash
# WSL: clone repo and run all phases
git clone https://github.com/nonatorw/linux-init-bootstrap.git ~/Dev/repos/linux-init-bootstrap
cd ~/Dev/repos/linux-init-bootstrap
bash setup-prereqs-linux.sh
bash bootstrap.sh
```

### Native Linux

```bash
git clone https://github.com/nonatorw/linux-init-bootstrap.git ~/Dev/repos/linux-init-bootstrap
cd ~/Dev/repos/linux-init-bootstrap
bash bootstrap.sh
```

Restart the terminal when it finishes.

## Remote Entry Points (Gist)

Each phase has a self-contained entry point in `gist/` that clones the repo and runs the
appropriate script — useful for bootstrapping from a completely fresh machine.

**Phase 1 (Windows)** — run from a normal PowerShell window:

```powershell
$tmp = "$env:TEMP\linux-init-phase1.ps1"
Invoke-WebRequest "https://gist.githubusercontent.com/nonatorw/79321dfef85099cdbad1d2f0fda5f959/raw/linux-init-phase1-windows-prereqs.ps1" -OutFile $tmp
powershell.exe -ExecutionPolicy Bypass -File $tmp
```

**Phase 2 (Linux prereqs):**

```bash
curl -fsSL https://gist.githubusercontent.com/nonatorw/79321dfef85099cdbad1d2f0fda5f959/raw/linux-init-phase2-linux-prereqs.sh | bash
```

**Phase 3 (bootstrap):**

```bash
curl -fsSL https://gist.githubusercontent.com/nonatorw/79321dfef85099cdbad1d2f0fda5f959/raw/linux-init-phase3-bootstrap.sh | bash
```

> Gist: [gist.github.com/nonatorw/79321dfef85099cdbad1d2f0fda5f959](https://gist.github.com/nonatorw/79321dfef85099cdbad1d2f0fda5f959)

## Flags

| Flag               | Description                                                                          |
|--------------------|--------------------------------------------------------------------------------------|
| `--help`           | Flag reference. `--help <flag>` expands detail for a specific flag.                  |
| `--verbose`        | Show external tool output in terminal (delimited blocks).                            |
| `--clean-tools`    | Remove dev tools and tool state. Preserves shell, dotfiles, and system packages.     |
| `--reinstall`      | Full state reset + clean tools + complete reinstall from scratch.                    |
| `--clean-install`  | Remove all tools, dotfiles, and state, then reinstall from scratch.                  |

See [docs/USAGE.md](docs/USAGE.md) for examples and details on each flag.

## Resume on Error

The bootstrap writes progress to `~/.bootstrap-state` (key=value format). If a run is
interrupted, re-running `bootstrap.sh` will skip modules that already completed.

To reset a single module:

```bash
sed -i '/^module_03_python=/d' ~/.bootstrap-state
```

To reset everything:

```bash
bash bootstrap.sh --reinstall
```

## What Phase 3 Installs

| Module             | What it installs                                                                        |
|--------------------|-----------------------------------------------------------------------------------------|
| `00_packages.sh`   | System upgrade + base packages (curl, git, zsh, eza, bat, jq, etc.) + locale (apt) + gh |
| `01_shell.sh`      | Oh My Zsh + Powerlevel10k + plugins                                                     |
| `02_chezmoi.sh`    | [chezmoi](https://www.chezmoi.io/) dotfile manager                                      |
| `03_python.sh`     | pyenv + Python LTS + Poetry + uv                                                        |
| `04_java.sh`       | SDKman + Azul Zulu JDK 25 + Maven + Gradle                                              |
| `05_node.sh`       | NVM + Node.js LTS                                                                       |
| `06_ai.sh`         | Claude Code + Gemini CLI (gh copilot requires manual post-install steps)                |
| `07_containers.sh` | Podman                                                                                  |

## Post-Install Manual Steps

After the bootstrap completes, some tools require manual authentication before they are fully functional.

### Claude Code

Run `claude` and follow the onboarding steps — the CLI guides you through login interactively:

```bash
claude
```

### Gemini CLI

Run `gemini` and follow the onboarding steps — the CLI guides you through login interactively:

```bash
gemini
```

### GitHub Copilot CLI

The bootstrap installs `gh` (GitHub CLI) but the `gh copilot` extension must be installed and authenticated manually — authentication varies by account type (GitHub.com or GitHub Enterprise).

```bash
# Authenticate gh (choose GitHub.com or your enterprise host)
gh auth login

# Install the Copilot extension
gh extension install github/gh-copilot

# Follow the onboarding steps
gh copilot --version
```

---

After the modules run, the bootstrap also:

1. **Populates `~/.ssh/known_hosts`** — fetches host keys for `github.com`, `gitlab.com`,
   and `bitbucket.org` at runtime via `ssh-keyscan`. No keys are stored in this repo.
2. **Clones `chezmoi-dotfiles`** — via HTTPS (no auth required, repo is public) to
   `~/Dev/repos/chezmoi-dotfiles`.
3. **Applies dotfiles** — runs `chezmoi apply --force`.

## SSH Agent Bootstrap Order

The SSH agent is **not** active during the bootstrap itself — it becomes available after
the first terminal restart. This is why:

- `chezmoi-dotfiles` is cloned via **HTTPS**, not SSH
- SSH host keys are pre-populated via `ssh-keyscan` (TCP only, no auth) so that `git push`
  works immediately after reopening the terminal

```text
bootstrap runs
  └── install modules
  └── ssh-keyscan github.com → ~/.ssh/known_hosts    (TCP only, no auth)
  └── git clone chezmoi-dotfiles via HTTPS           (no auth)
  └── chezmoi apply                                  (local files only)

restart terminal
  └── aliases.sh activates ssh.exe / ssh-add.exe (WSL2)
  └── SSH agent active → git push works
```

## 1Password SSH Agent

All git operations use SSH authenticated via 1Password. The setup differs by platform.

### Bluefin / Linux (native)

1Password exposes the SSH agent natively at `~/.1password/agent.sock`. No extra setup
needed after installing the [1Password desktop app](https://1password.com/downloads/linux/).

### WSL2 (via Windows executables)

On WSL2, `aliases.sh` (deployed by chezmoi) aliases `ssh`, `ssh-add`, and `op` to their
Windows counterparts (`ssh.exe`, `ssh-add.exe`, `op.exe`). This makes the terminal use the
Windows OpenSSH client, which communicates directly with the 1Password Desktop agent via
the Windows named pipe — no relay process needed.

#### Prerequisites (Windows — one-time manual steps)

Run `setup-windows-admin.ps1` from an elevated PowerShell, then complete the manual steps:

1. Install [1Password Desktop](https://1password.com/downloads/) and sign in
2. In 1Password → **Settings → Developer**:
   - Enable **"Use the SSH agent"**
   - Enable **"Integrate with 1Password CLI"**
3. Store your SSH key as a native **SSH Key** item in 1Password (New Item → SSH Key →
   import private key file). The key must be of this type — not a generic password item —
   for the agent integration to work.

The `setup-windows-admin.ps1` script handles:

- Installing the Windows OpenSSH client optional feature (provides `ssh.exe`)
- Disabling the Windows `ssh-agent` service (1Password manages the agent pipe directly; the native service conflicts)

#### Verifying it works

Open a new WSL terminal after the bootstrap completes, then:

```bash
ssh-add -l              # should list your 1Password SSH key
ssh -T git@github.com   # should say "Hi <user>! You've successfully authenticated"
```

## Key Design Decisions

- **Three phases** — Windows prerequisites, Linux prerequisites, and tool install are separated
  so each can be run and re-run independently.
- **State tracking** — `~/.bootstrap-state` records each module's result so the bootstrap
  can resume after failure without re-running completed steps.
- **Single command for Phase 3** — tools, SSH known_hosts, and dotfiles are all handled by
  one run of `bootstrap.sh`. No manual post-install steps.
- **HTTPS for bootstrap clones** — all `git clone` calls during the bootstrap use HTTPS or
  `GIT_CONFIG_NOSYSTEM=1 HOME=/tmp` to avoid dependency on SSH signing or agent availability.
- **SSH known_hosts at runtime** — host keys are fetched via `ssh-keyscan` during the
  bootstrap, never stored in this repo.
- **Idempotent** — safe to run multiple times; each module skips already-installed tools and
  verifies installation integrity (not just directory existence).
- **No modes** — no `--install`/`--link`/`--reinstall` flags beyond `--clean-install`.
  One command does everything.
- **Fixed Java version** — always installs Azul Zulu `25.0.3.fx-zulu` via SDKman.
