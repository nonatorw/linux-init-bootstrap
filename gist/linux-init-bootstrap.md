# linux-init-bootstrap

Automated development environment setup for Linux and WSL2.

A single command installs development tools (Python, Java, Node.js, AI CLIs, containers),
populates SSH known_hosts, and applies dotfiles via chezmoi — with state tracking so it
resumes safely after interruption.

## Phases

| Phase                             | Platform              | Script                                  |
|-----------------------------------|-----------------------|-----------------------------------------|
| Phase 1 — Windows prerequisites   | WSL2 (Windows side)   | `linux-init-phase1-windows-prereqs.ps1` |
| Phase 2 — Linux prerequisites     | WSL2 / Linux          | `linux-init-phase2-linux-prereqs.sh`    |
| Phase 3 — Tool install + dotfiles | WSL2 / Linux          | `linux-init-phase3-bootstrap.sh`        |

## Quick Start

**Phase 1** — WSL2 only, run from a normal PowerShell window:

```powershell
$tmp = "$env:TEMP\linux-init-phase1.ps1"
Invoke-WebRequest "https://gist.githubusercontent.com/nonatorw/79321dfef85099cdbad1d2f0fda5f959/raw/linux-init-phase1-windows-prereqs.ps1" -OutFile $tmp
powershell.exe -ExecutionPolicy Bypass -File $tmp
```

**Phase 2** — run inside WSL or any Linux machine:

```bash
curl -fsSL https://gist.githubusercontent.com/nonatorw/79321dfef85099cdbad1d2f0fda5f959/raw/linux-init-phase2-linux-prereqs.sh | bash
```

**Phase 3** — run inside WSL or native Linux:

```bash
curl -fsSL https://gist.githubusercontent.com/nonatorw/79321dfef85099cdbad1d2f0fda5f959/raw/linux-init-phase3-bootstrap.sh | bash
```

---

Full documentation and source: **[github.com/nonatorw/linux-init-bootstrap](https://github.com/nonatorw/linux-init-bootstrap)**
