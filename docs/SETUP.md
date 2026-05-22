# Setup Guide

Step-by-step installation guide by platform. For flag reference and post-install steps, see [USAGE.md](USAGE.md).

---

## WSL2 (Windows Subsystem for Linux)

### Phase 1 — Windows prerequisites (one-time, admin)

Run once from an **elevated PowerShell** (right-click → Run as Administrator):

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
.\setup-windows-admin.ps1
```

Then complete the manual steps:

1. Install [1Password Desktop](https://1password.com/downloads/) and sign in
2. In 1Password → **Settings → Developer**:
   - Enable **"Use the SSH agent"**
   - Enable **"Integrate with 1Password CLI"**
3. Store your SSH key as a native **SSH Key** item in 1Password\
   (New Item → SSH Key → import private key file)

### Phase 2 — Linux prerequisites

Open a WSL terminal and run:

```bash
git clone https://github.com/nonatorw/linux-init-bootstrap.git ~/Dev/repos/linux-init-bootstrap
cd ~/Dev/repos/linux-init-bootstrap
bash setup-prereqs-linux.sh
```

Restart WSL if instructed (`wsl --shutdown` from Windows PowerShell, then reopen).

### Phase 3 — Tool install + dotfiles

```bash
cd ~/Dev/repos/linux-init-bootstrap
bash bootstrap.sh
```

Restart the terminal when it finishes.

---

## Native Linux (Silverblue, Ubuntu, Fedora, etc.)

Only Phase 3 is needed.

```bash
git clone https://github.com/nonatorw/linux-init-bootstrap.git ~/Dev/repos/linux-init-bootstrap
cd ~/Dev/repos/linux-init-bootstrap
bash bootstrap.sh
```

Restart the terminal when it finishes.

---

## Remote Entry Points (Gist)

Each phase has a self-contained entry point in `gist/` that clones the repo and runs the appropriate script — useful for bootstrapping from a completely fresh machine.

**Phase 1 (Windows)** — run from a normal PowerShell window:

```powershell
$tmp = "$env:TEMP\linux-init-phase1.ps1"
Invoke-WebRequest "https://gist.githubusercontent.com/nonatorw/79321dfef85099cdbad1d2f0fda5f959/raw/linux-init-phase1-windows-prereqs.ps1" -OutFile $tmp
powershell.exe -ExecutionPolicy Bypass -File $tmp
```

**Phase 2 (WSL prereqs):**

```bash
curl -fsSL https://gist.githubusercontent.com/nonatorw/79321dfef85099cdbad1d2f0fda5f959/raw/linux-init-phase2-linux-prereqs.sh | bash
```

**Phase 3 (bootstrap):**

```bash
curl -fsSL https://gist.githubusercontent.com/nonatorw/79321dfef85099cdbad1d2f0fda5f959/raw/linux-init-phase3-bootstrap.sh | bash
```

> Gist: [gist.github.com/nonatorw/79321dfef85099cdbad1d2f0fda5f959](https://gist.github.com/nonatorw/79321dfef85099cdbad1d2f0fda5f959)

---

## What Phase 3 Installs

| Module             | What it installs                                                                         |
|--------------------|------------------------------------------------------------------------------------------|
| `00_packages.sh`   | System upgrade + base packages (curl, git, zsh, eza, bat, jq, etc.) + locale (apt) + gh |
| `01_shell.sh`      | Oh My Zsh + Powerlevel10k + plugins                                                      |
| `02_chezmoi.sh`    | [chezmoi](https://www.chezmoi.io/) dotfile manager                                       |
| `03_python.sh`     | pyenv + Python LTS + Poetry + uv                                                         |
| `04_java.sh`       | SDKman + Azul Zulu JDK 25 + Maven + Gradle                                               |
| `05_node.sh`       | NVM + Node.js LTS                                                                        |
| `06_ai.sh`         | Claude Code + Gemini CLI                                                                 |
| `07_containers.sh` | Podman                                                                                   |

After the modules run, the bootstrap also:

1. **Populates `~/.ssh/known_hosts`** — fetches host keys for `github.com`, `gitlab.com`, and `bitbucket.org` at runtime via `ssh-keyscan`. No keys are stored in this repo.
2. **Clones `chezmoi-dotfiles`** — via HTTPS to `~/Dev/repos/chezmoi-dotfiles`.
3. **Applies dotfiles** — runs `chezmoi apply --force`.

---

## Resuming After Failure

The bootstrap writes progress to `~/.bootstrap-state`. If a run is interrupted, re-running `bootstrap.sh` skips completed modules automatically.

To reset a single module and re-run it:

```bash
sed -i '/^module_03_python=/d' ~/.bootstrap-state
bash bootstrap.sh
```

See [USAGE.md](USAGE.md) for full flag reference including `--reinstall` and `--clean-tools`.
