# linux-init-bootstrap

Minimal bootstrap script for setting up a Linux development environment from scratch.
Installs development tools, populates SSH known_hosts, clones
[chezmoi-dotfiles](https://github.com/nonatorw/chezmoi-dotfiles), and applies dotfiles —
all in a single command.

## Usage

```bash
git clone https://github.com/nonatorw/linux-init-bootstrap.git ~/Dev/repos/linux-init-bootstrap
cd ~/Dev/repos/linux-init-bootstrap
bash bootstrap.sh
```

That's it. The bootstrap runs all install modules, then automatically clones and applies
`chezmoi-dotfiles`. Restart the terminal when it finishes.

## What this installs

| Module             | What it installs                                            |
|--------------------|-------------------------------------------------------------|
| `00_packages.sh`   | Base system packages (curl, git, zsh, socat, etc.) + locale |
| `01_shell.sh`      | Oh My Zsh + Powerlevel10k + plugins                         |
| `02_chezmoi.sh`    | [chezmoi](https://www.chezmoi.io/) dotfile manager          |
| `03_python.sh`     | pyenv + Python LTS + Poetry + uv                            |
| `04_java.sh`       | SDKman + Azul Zulu JDK 25 + Maven + Gradle                  |
| `05_node.sh`       | NVM + Node.js LTS                                           |
| `06_ai.sh`         | Claude Code + Gemini CLI                                    |
| `07_containers.sh` | Podman                                                      |

After the modules run, the bootstrap also:

1. **Populates `~/.ssh/known_hosts`** — fetches host keys for `github.com`, `gitlab.com`,
   and `bitbucket.org` at runtime via `ssh-keyscan`. No keys are stored in this repo.
2. **Clones `chezmoi-dotfiles`** — via HTTPS (no auth required, repo is public) to
   `~/Dev/repos/chezmoi-dotfiles`.
3. **Applies dotfiles** — runs `chezmoi apply --force`.

## SSH agent bootstrap order

The 1Password SSH agent relay (`socat` + `npiperelay`) is **not** active during the
bootstrap itself — it starts automatically via `dev_configs.sh` when a new terminal session
opens. This is why:

- `chezmoi-dotfiles` is cloned via **HTTPS**, not SSH
- SSH host keys are pre-populated via `ssh-keyscan` (TCP only, no auth) so that `git push`
  works immediately after reopening the terminal with the relay active

```text
bootstrap runs
  └── install modules (socat installed here)
  └── ssh-keyscan github.com → ~/.ssh/known_hosts    (TCP only, no auth)
  └── git clone chezmoi-dotfiles via HTTPS           (no auth)
  └── chezmoi apply                                  (local files only)

restart terminal
  └── dev_configs.sh starts socat relay
  └── SSH agent active → git push works
```

## 1Password SSH Agent

All git operations use SSH authenticated via 1Password. The setup differs by platform.

### Bluefin / Linux (native)

1Password exposes the SSH agent natively at `~/.1password/agent.sock`. No extra setup
needed after installing the [1Password desktop app](https://1password.com/downloads/linux/).

### WSL2

The 1Password Desktop app runs on Windows and exposes the SSH agent as a Windows named
pipe. WSL2 cannot access named pipes directly — a relay is needed.

#### Prerequisites (Windows — one-time manual steps)

1. Install [1Password Desktop](https://1password.com/downloads/) (version 8.10+)
2. In 1Password → Settings → Developer:
   - Enable **"Use the SSH agent"**
   - Enable **"Integrate with 1Password CLI"**
3. Install `npiperelay` via winget (PowerShell):

```powershell
winget install jstarks.npiperelay
```

#### How the relay works (automatic after bootstrap)

After the bootstrap and a terminal restart, `dev_configs.sh` automatically starts the
relay on every session:

```bash
# Simplified version of what dev_configs.sh does:
export SSH_AUTH_SOCK="$HOME/.ssh/1password-agent.sock"
setsid socat UNIX-LISTEN:"$SSH_AUTH_SOCK",fork \
  EXEC:"npiperelay.exe -ei -s //./pipe/openssh-ssh-agent",nofork &
```

This bridges the 1Password named pipe (`//./pipe/openssh-ssh-agent`) to a Unix socket
that SSH and git can use.

#### Verifying it works

```bash
ssh-add -l              # should list your 1Password SSH key
ssh -T git@github.com   # should say "Hi <user>! You've successfully authenticated"
```

The bootstrap warns if `npiperelay.exe` is not found during installation.

## Key design decisions

- **Single command** — tools, SSH known_hosts, and dotfiles are all handled by one run of
  `bootstrap.sh`. No manual post-install steps.
- **HTTPS for bootstrap clones** — all `git clone` calls during the bootstrap use HTTPS or
  `GIT_CONFIG_NOSYSTEM=1 HOME=/tmp` to avoid dependency on SSH signing or agent availability.
- **SSH known_hosts at runtime** — host keys are fetched via `ssh-keyscan` during the
  bootstrap, never stored in this repo.
- **Idempotent** — safe to run multiple times; each module skips already-installed tools and
  verifies installation integrity (not just directory existence).
- **No modes** — no `--install`/`--link`/`--reinstall` flags. One command does everything.
- **Fixed Java version** — always installs Azul Zulu `25.0.3.fx-zulu` via SDKman.
