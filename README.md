# linux-init-bootstrap

> **Pending verification:** The `setup-python`, `setup-dotfiles`, and `setup-ai` recipes in
> `bluefin-template` have been updated but not yet tested on a live Bluefin machine. See
> [docs/superpowers/plans/2026-05-18-linux-init-bootstrap-refactor.md](docs/superpowers/plans/2026-05-18-linux-init-bootstrap-refactor.md)
> for details.

Minimal bootstrap script for setting up a Linux development environment from scratch.
Installs development tools and [chezmoi](https://www.chezmoi.io/), then delegates all
dotfile management to [chezmoi-dotfiles](https://github.com/nonatorw/chezmoi-dotfiles).

This repository supersedes [nonatorw/nonatorw-dotfiles](https://github.com/nonatorw/nonatorw-dotfiles)
(now archived).

## Usage

```bash
git clone https://github.com/nonatorw/linux-init-bootstrap.git ~/Dev/repos/linux-init-bootstrap
cd ~/Dev/repos/linux-init-bootstrap
bash bootstrap.sh
```

Then apply dotfiles — chezmoi is configured to use `~/Dev/repos/chezmoi-dotfiles` as its
source directory (see [chezmoi-dotfiles](https://github.com/nonatorw/chezmoi-dotfiles)):

```bash
# Clone to the expected location
git clone https://github.com/nonatorw/chezmoi-dotfiles.git ~/Dev/repos/chezmoi-dotfiles

# Configure chezmoi to use that path
mkdir -p ~/.config/chezmoi
echo 'sourceDir = "~/Dev/repos/chezmoi-dotfiles"' > ~/.config/chezmoi/chezmoi.toml

# Apply dotfiles
chezmoi apply
```

## What this installs

| Module             | What it installs                                   |
|--------------------|----------------------------------------------------|
| `00_packages.sh`   | Base system packages (curl, git, zsh, socat, etc.) |
| `01_shell.sh`      | Oh My Zsh + Powerlevel10k + plugins                |
| `02_chezmoi.sh`    | [chezmoi](https://www.chezmoi.io/) dotfile manager |
| `03_python.sh`     | pyenv + Python LTS + Poetry + uv                   |
| `04_java.sh`       | SDKman + Azul Zulu JDK 25 + Maven + Gradle         |
| `05_node.sh`       | NVM + Node.js LTS                                  |
| `06_ai.sh`         | Claude Code + Gemini CLI                           |
| `07_containers.sh` | Podman + Podman Compose                            |

## 1Password SSH Agent

All git operations use SSH authenticated via 1Password. The setup differs by platform.

### Bluefin / Linux (native)

1Password exposes the SSH agent natively at `~/.1password/agent.sock`. No extra setup needed
after installing the [1Password desktop app](https://1password.com/downloads/linux/).

Configure `~/.ssh/config` to use it:

```
Host *
  IdentityAgent ~/.1password/agent.sock
```

### WSL2

The 1Password Desktop app runs on Windows and exposes the SSH agent as a Windows named pipe.
WSL2 cannot access named pipes directly — a relay is needed.

#### Prerequisites (Windows — manual steps)

1. Install [1Password Desktop](https://1password.com/downloads/) (version 8.10+)
2. In 1Password → Settings → Developer:
   - Enable **"Use the SSH agent"**
   - Enable **"Integrate with 1Password CLI"**
3. Install `npiperelay` via winget (PowerShell):

```powershell
winget install jstarks.npiperelay
```

#### How the relay works (automatic after bootstrap)

After the bootstrap runs and `chezmoi apply` is executed, `dev_configs.sh` automatically
starts the relay on every terminal session:

```bash
# Simplified version of what dev_configs.sh does:
export SSH_AUTH_SOCK="$HOME/.ssh/1password-agent.sock"
setsid socat UNIX-LISTEN:"$SSH_AUTH_SOCK",fork \
  EXEC:"npiperelay.exe -ei -s //./pipe/openssh-ssh-agent",nofork &
```

This bridges the 1Password named pipe (`//./pipe/openssh-ssh-agent`) to a Unix socket
that SSH and git can use. `socat` (installed by `00_packages.sh`) handles the bridge.

#### Verifying it works

```bash
ssh-add -l        # should list your 1Password SSH key
ssh -T git@github.com   # should say "Hi <user>! You've successfully authenticated"
```

The bootstrap will warn if `npiperelay.exe` is not found after installation.

## Key design decisions

- **Bootstrap only** — installs tools. All shell config, aliases, git config, and environment
  variables live in [chezmoi-dotfiles](https://github.com/nonatorw/chezmoi-dotfiles).
- **Idempotent** — safe to run multiple times; each module skips already-installed tools.
- **No modes** — no `--install`/`--link`/`--reinstall` flags. One command does everything.
- **Hardened git clones** — uses `GIT_CONFIG_NOSYSTEM=1 HOME=/tmp` to avoid conflicts with
  1Password SSH signing during bootstrap.
- **Fixed Java version** — always installs Azul Zulu `25.0.3.fx-zulu` via SDKman.
