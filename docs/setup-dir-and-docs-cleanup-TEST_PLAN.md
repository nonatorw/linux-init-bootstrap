# Test Plan — setup-dir-and-docs-cleanup: Full Project Regression

Manual regression test plan covering all project functionality after the setup directory
reorganisation and documentation cleanup. Tests are executed on Ubuntu WSL2 and Fedora WSL2.

Each scenario follows the **Given / When / Then** structure. Unless noted otherwise, execute
inside WSL2.

All test logs are stored in `C:\Dev\repos\personal_projects\test_results\`.

---

## Before Test — WSL Instance Provisioning

This section must be executed **every time a new feature branch requires testing**. It
creates clean WSL instances with all prerequisites configured. Do not skip any step.

### Log directory

```powershell
New-Item -ItemType Directory -Force "C:\Dev\repos\personal_projects\test_results"
```

### Verify repository and branch (Windows — do first)

```powershell
cd C:\Dev\repos\personal_projects\linux-init-bootstrap
git status
git branch --show-current
```

Expected: `feature/setup-dir-and-docs-cleanup`. If not, check out the correct branch before
proceeding — WSL instances mount the Windows filesystem at `/mnt/c/`, so scripts run live
from this directory.

### Create Ubuntu instance

```powershell
wsl --unregister Ubuntu-26-setup-cleanup
wsl --install Ubuntu-26.04 --web-download --name Ubuntu-26-setup-cleanup
```

Follow first-run prompts to create user `nonatorw` and set a password.

Inside Ubuntu, enable systemd (required for binfmt_misc/WSLInterop — without this,
`powershell.exe` and `ssh-add.exe` fail with "Exec format error"):

```bash
sudo bash -c 'cat > /etc/wsl.conf << EOF
[boot]
systemd=true
command = systemctl restart systemd-binfmt.service
EOF'
exit
```

```powershell
wsl --shutdown
wsl -d Ubuntu-26-setup-cleanup
```

Verify prerequisites inside WSL:

```bash
ls /proc/sys/fs/binfmt_misc/WSLInterop && echo "interop ativo"
ssh-add.exe -L && echo "1Password agent acessível"
ls /mnt/c/Dev/repos/personal_projects/linux-init-bootstrap/setup/phase3-setup-bootstrap.sh && echo OK
lsb_release -a && echo OK
exit
```

### Create Fedora instance

```powershell
wsl --install FedoraLinux-44 --web-download --name Fedora-44-setup-cleanup
```

Inside Fedora, set sudo password and enable systemd:

```bash
sudo passwd nonatorw

sudo bash -c 'cat > /etc/wsl.conf << EOF
[boot]
systemd=true
command = systemctl restart systemd-binfmt.service
EOF'
```

```powershell
wsl --shutdown
wsl -d Fedora-44-setup-cleanup
```

```bash
sudo systemctl mask audit-rules.service auditd.service
```

```powershell
wsl --shutdown
wsl -d Fedora-44-setup-cleanup
```

Verify:

```bash
systemctl is-system-running       # Expected: running
ls /proc/sys/fs/binfmt_misc/WSLInterop && echo "interop ativo"
ssh-add.exe -L && echo "1Password agent acessível"
ls /mnt/c/Dev/repos/personal_projects/linux-init-bootstrap/setup/phase3-setup-bootstrap.sh && echo OK
cat /etc/fedora-release && echo OK
```

---

## Execution Sequence

| Run | Distro | Scope                                                                               |
|:---:| ------ | ----------------------------------------------------------------------------------- |
|  1  | Ubuntu | Provisioning only                                                                   |
|  2  | Fedora | Provisioning only                                                                   |
|  3  | Ubuntu | Full fresh install — all phases, all modules, all interactive loops (covers **W5**) |
|  4  | Ubuntu | Idempotency + destructive flags against installed state                             |
|  5  | Fedora | Full fresh install — Phase 2 + Phase 3                                              |
|  6  | Ubuntu | Error conditions — Groups A and B                                                   |

**Phase 1 (Windows side) runs once** during Run 3 only.

---

## Run 3 — Ubuntu: first execution (all phases, fresh)

### Pre-conditions

- Ubuntu instance created in Run 1 (name: `Ubuntu-26-setup-cleanup`)
- No `~/.bootstrap-state`
- 1Password Desktop running with SSH agent enabled

### Step 1 — Phase 1 (PowerShell)

```powershell
$stateFileWin = (wsl -d Ubuntu-26-setup-cleanup -- bash -c "touch ~/.bootstrap-state && wslpath -w ~/.bootstrap-state")
$ps1Win = (wsl -d Ubuntu-26-setup-cleanup -- wslpath -w /mnt/c/Dev/repos/personal_projects/linux-init-bootstrap/gist/linux-init-local-phase1-windows-prereqs.ps1)
powershell.exe -ExecutionPolicy Bypass -File $ps1Win -StateFile $stateFileWin -LogDest "C:\Dev\repos\personal_projects\test_results\ubuntu-run3-phase1-winlog.log" 2>&1 | Tee-Object "C:\Dev\repos\personal_projects\test_results\ubuntu-run3-phase1.log"
```

**Scenarios covered:** P1-1 through P1-8 (see Group P1 below)

### Step 2 — Phase 2 (interactive WSL session)

Phase 2 is standalone (does not write to `~/.linux-init-bootstrap.log`). Pre-authenticate
sudo before the pipe so the password prompt is visible.

```powershell
wsl -d Ubuntu-26-setup-cleanup
```

```bash
sudo true && bash /mnt/c/Dev/repos/personal_projects/linux-init-bootstrap/gist/linux-init-local-phase2-linux-prereqs.sh \
  2>&1 | tee /mnt/c/Dev/repos/personal_projects/test_results/ubuntu-run3-phase2.log
```

**Scenarios covered:** P2-1, P2-2

### Step 3 — Phase 3 (same interactive WSL session)

Phase 3 must run directly in the terminal — piping breaks Windows interop (`powershell.exe`,
`ssh-add.exe`). The bootstrap writes its own log to `~/.linux-init-bootstrap.log`. Copy it
after the run completes.

```bash
bash /mnt/c/Dev/repos/personal_projects/linux-init-bootstrap/gist/linux-init-local-phase3-linux-bootstrap.sh --verbose
cp ~/.linux-init-bootstrap.log /mnt/c/Dev/repos/personal_projects/test_results/ubuntu-run3-phase3.log
```

**Interactions during run:**

| Prompt                                        | Action         | Scenario           |
| --------------------------------------------- | -------------- | ------------------ |
| `chsh` PAM (1st time)                         | wrong password | —                  |
| `[R]etry / [S]kip`                            | `r`            | A1                 |
| `chsh` PAM                                    | wrong password | —                  |
| `[R]etry / [S]kip`                            | `x`            | A5 — invalid input |
| `[R]etry / [S]kip`                            | `s`            | A3 — skip          |
| `Install Python LTS? [Y/n]`                   | `y`            | —                  |
| `Install JDK 25? [Y/n]`                       | `y`            | —                  |
| `Install Maven? [Y/n]`                        | `y`            | —                  |
| `Install Gradle? [Y/n]`                       | `y`            | —                  |
| `Install Node.js LTS? [Y/n]`                  | `y`            | —                  |
| `Install Claude Code? [Y/n]`                  | `y`            | —                  |
| `Install Gemini CLI? [Y/n]`                   | `y`            | —                  |
| SSH key menu `Enter number (1-N) or [C]ancel` | `1`            | B7                 |

**Scenarios covered:** P3-1, P3-2, P3-3, A1, A3, A5, B7, C1–C9 (via `--clean-install` / `--clean-tools` / `--reinstall` sub-runs below), D3, D4, E1–E2

---

## Run 4 — Ubuntu: second execution (state intact)

### Pre-conditions

- Same Ubuntu instance from Run 3 — do not reset state
- All modules complete in `~/.bootstrap-state`

### Steps

Open interactive WSL session:

```powershell
wsl -d Ubuntu-26-setup-cleanup
```

Each sub-run below must be executed directly in the interactive terminal (no piping).
After each sub-run, copy the log before starting the next one — the log is overwritten on each run.

```bash
# 1. Idempotency — all modules skip
bash /mnt/c/Dev/repos/personal_projects/linux-init-bootstrap/setup/phase3-setup-bootstrap.sh --verbose
cp ~/.linux-init-bootstrap.log /mnt/c/Dev/repos/personal_projects/test_results/ubuntu-run4-idempotency.log

# 2. --clean-tools abort (enter n)
bash /mnt/c/Dev/repos/personal_projects/linux-init-bootstrap/setup/phase3-setup-bootstrap.sh --verbose --clean-tools
cp ~/.linux-init-bootstrap.log /mnt/c/Dev/repos/personal_projects/test_results/ubuntu-run4-clean-tools-n.log

# 3. --reinstall abort (enter n)
bash /mnt/c/Dev/repos/personal_projects/linux-init-bootstrap/setup/phase3-setup-bootstrap.sh --verbose --reinstall
cp ~/.linux-init-bootstrap.log /mnt/c/Dev/repos/personal_projects/test_results/ubuntu-run4-reinstall-n.log

# 4. --reinstall confirm (enter y)
bash /mnt/c/Dev/repos/personal_projects/linux-init-bootstrap/setup/phase3-setup-bootstrap.sh --verbose --reinstall
cp ~/.linux-init-bootstrap.log /mnt/c/Dev/repos/personal_projects/test_results/ubuntu-run4-reinstall-y.log

# 5. Non-interactive — signing_key e chezmoi.toml removidos; PS1 re-captura e auto-seleciona primeiro key
sed -i '/^signing_key=/d; /^phase_windows=/d' ~/.bootstrap-state
rm -f ~/.config/chezmoi/chezmoi.toml
bash /mnt/c/Dev/repos/personal_projects/linux-init-bootstrap/setup/phase3-setup-bootstrap.sh --verbose --non-interactive
cp ~/.linux-init-bootstrap.log /mnt/c/Dev/repos/personal_projects/test_results/ubuntu-run4-non-interactive.log

# 5b. --non-interactive + --clean-tools — deve abortar sem prompt
bash /mnt/c/Dev/repos/personal_projects/linux-init-bootstrap/setup/phase3-setup-bootstrap.sh --verbose --non-interactive --clean-tools
cp ~/.linux-init-bootstrap.log /mnt/c/Dev/repos/personal_projects/test_results/ubuntu-run4-non-interactive-clean-tools.log

# 5c. --non-interactive + --reinstall — deve abortar sem prompt
bash /mnt/c/Dev/repos/personal_projects/linux-init-bootstrap/setup/phase3-setup-bootstrap.sh --verbose --non-interactive --reinstall
cp ~/.linux-init-bootstrap.log /mnt/c/Dev/repos/personal_projects/test_results/ubuntu-run4-non-interactive-reinstall.log

# 6. --clean-tools confirm (enter y)
bash /mnt/c/Dev/repos/personal_projects/linux-init-bootstrap/setup/phase3-setup-bootstrap.sh --verbose --clean-tools
cp ~/.linux-init-bootstrap.log /mnt/c/Dev/repos/personal_projects/test_results/ubuntu-run4-clean-tools-y.log

# 7. --clean-install confirm (enter y)
bash /mnt/c/Dev/repos/personal_projects/linux-init-bootstrap/setup/phase3-setup-bootstrap.sh --verbose --clean-install
cp ~/.linux-init-bootstrap.log /mnt/c/Dev/repos/personal_projects/test_results/ubuntu-run4-clean-install-y.log
```

**Scenarios covered:** C1–C9, D1, D2, D5, E1, E2, I1–I5, M1–M4, NI1–NI5

---

## Run 5 — Fedora: first execution (fresh)

### Pre-conditions

- Fedora instance created in Run 2 (name: `Fedora-44-setup-cleanup`)
- No `~/.bootstrap-state`
- systemd active, sudo password set

### Step 1 — Phase 2 (interactive WSL session)

```powershell
wsl -d Fedora-44-setup-cleanup
```

```bash
bash /mnt/c/Dev/repos/personal_projects/linux-init-bootstrap/gist/linux-init-local-phase2-linux-prereqs.sh
cp ~/.linux-init-bootstrap.log /mnt/c/Dev/repos/personal_projects/test_results/fedora-run5-phase2.log
```

**Scenarios covered:** P2-1 (dnf path)

### Step 2 — Phase 3 (interactive WSL session)

```powershell
wsl -d Fedora-44-setup-cleanup
```

```bash
bash /mnt/c/Dev/repos/personal_projects/linux-init-bootstrap/gist/linux-init-local-phase3-linux-bootstrap.sh --verbose
cp ~/.linux-init-bootstrap.log /mnt/c/Dev/repos/personal_projects/test_results/fedora-run5-phase3.log
```

Same interactions as Run 3 Step 3.

**Scenarios covered:** P3-1, P3-2, P3-3, A1, A3, A5, B7, D3

### Group A supplemental runs (Fedora)

```bash
# A4 — skip with S
sudo chsh -s /bin/bash nonatorw
sed -i '/^module_00_packages=/d' ~/.bootstrap-state
bash /mnt/c/Dev/repos/personal_projects/linux-init-bootstrap/setup/phase3-setup-bootstrap.sh --verbose --modules packages
cp ~/.linux-init-bootstrap.log /mnt/c/Dev/repos/personal_projects/test_results/fedora-run5-group-a-s.log
# At [R]etry / [S]kip: enter wrong password then S

# A6 — successful retry
sudo chsh -s /bin/bash nonatorw
sed -i '/^module_00_packages=/d' ~/.bootstrap-state
bash /mnt/c/Dev/repos/personal_projects/linux-init-bootstrap/setup/phase3-setup-bootstrap.sh --verbose --modules packages
cp ~/.linux-init-bootstrap.log /mnt/c/Dev/repos/personal_projects/test_results/fedora-run5-group-a-retry.log
# At [R]etry / [S]kip: enter wrong password then r, then correct password
```

---

## Run 6 — Ubuntu: error conditions

### Group A — chsh failure loop

Reset default shell to bash, clear packages state, then run with `--modules packages`:

```bash
sudo chsh -s /bin/bash nonatorw
sed -i '/^module_00_packages=/d' ~/.bootstrap-state
bash /mnt/c/Dev/repos/personal_projects/linux-init-bootstrap/setup/phase3-setup-bootstrap.sh --verbose --modules packages
cp ~/.linux-init-bootstrap.log /mnt/c/Dev/repos/personal_projects/test_results/ubuntu-run6-group-a.log
```

Enter wrong password at each `chsh` PAM prompt to exercise A1–A6.

### Group B — SSH key retry and selection loops

**B1–B5 (no keys):** Disable SSH agent in 1Password before running.

```bash
sed -i '/^signing_key=/d; /^phase_dotfiles=/d' ~/.bootstrap-state
rm -f ~/.config/chezmoi/chezmoi.toml
bash /mnt/c/Dev/repos/personal_projects/linux-init-bootstrap/setup/phase3-setup-bootstrap.sh --verbose --skip-dotfiles
cp ~/.linux-init-bootstrap.log /mnt/c/Dev/repos/personal_projects/test_results/ubuntu-run6-group-b-nokeys.log
```

At `[R]etry / [C]ancel`: `r` (B1) → `R` (B2) → `c` (B3). Repeat for `C` (B4) and `x` (B5).

**B6–B9 (multiple keys):** Re-enable SSH agent before running.

```bash
sed -i '/^signing_key=/d; /^phase_dotfiles=/d' ~/.bootstrap-state
rm -f ~/.config/chezmoi/chezmoi.toml
bash /mnt/c/Dev/repos/personal_projects/linux-init-bootstrap/setup/phase3-setup-bootstrap.sh --verbose --skip-dotfiles
cp ~/.linux-init-bootstrap.log /mnt/c/Dev/repos/personal_projects/test_results/ubuntu-run6-group-b-keys.log
```

At `Enter number (1-N) or [C]ancel`: `0` (B8 — invalid) → `1` (B7 — valid). Repeat for `c` (B9).

---

## Group P1 — Phase 1: `setup/phase1-setup-windows.ps1`

**Context:** Verifies Windows prerequisites and captures SSH signing key from 1Password agent.
**Execute on:** Windows (PowerShell). **Run:** 3 only (via local Gist variant).

|  ID  | Given                                 | When         | Then                                                        |
|:----:| ------------------------------------- | ------------ | ----------------------------------------------------------- |
| P1-1 | winget present                        | Phase 1 runs | `✓ winget available` displayed                              |
| P1-2 | winget absent                         | Phase 1 runs | Warning: install App Installer from Microsoft Store         |
| P1-3 | ssh.exe present                       | Phase 1 runs | `✓ ssh.exe` displayed                                       |
| P1-4 | ssh-agent service disabled            | Phase 1 runs | `✓ ssh-agent service is disabled` displayed                 |
| P1-5 | ssh-agent service active              | Phase 1 runs | Warning: conflicts with 1Password; run admin script         |
| P1-6 | 1Password Desktop present             | Phase 1 runs | `✓ 1Password CLI / Desktop found` displayed                 |
| P1-7 | 1Password SSH pipe active, 1 key      | Phase 1 runs | Key captured automatically; written to state file           |
| P1-8 | 1Password SSH pipe active, N > 1 keys | Phase 1 runs | Selection menu shown; user picks key; written to state file |

---

## Group P2 — Phase 2: `setup/phase2-setup-prereqs-linux.sh`

**Context:** Installs minimal prerequisites (curl, git) on Linux before bootstrap.
**Runs:** 3 (Ubuntu/apt), 5 (Fedora/dnf).

|  ID  | Given                             | When           | Then                                                       |
|:----:| --------------------------------- | -------------- | ---------------------------------------------------------- |
| P2-1 | curl and git already installed    | Phase 2 runs   | Both shown as `⊙ already installed`; state set to complete |
| P2-2 | curl or git missing               | Phase 2 runs   | Package installed; `✓ installed` displayed                 |
| P2-3 | Phase 2 already complete in state | Re-run Phase 2 | `✓ Phase 2 already complete — skipping` displayed          |

---

## Group P3 — Phase 3 entry point: `setup/phase3-setup-bootstrap.sh` via local Gist

**Context:** Local Gist variant invokes `setup/phase3-setup-bootstrap.sh` directly from the
local repo. Verifies the entry point wires up correctly.
**Runs:** 3, 5.

|  ID  | Given                         | When         | Then                                                                    |
|:----:| ----------------------------- | ------------ | ----------------------------------------------------------------------- |
| P3-1 | Local Gist invoked            | Phase 3 runs | Header "Using bootstrap.sh from local repo" printed; bootstrap executes |
| P3-2 | `--verbose` flag passed       | Phase 3 runs | Flag forwarded to bootstrap; verbose output blocks appear               |
| P3-3 | `--skip-dotfiles` flag passed | Phase 3 runs | Flag forwarded; dotfiles section skipped                                |

---

## Group A — `install/00_packages.sh`: chsh confirmation loop

**Context:** `chsh -s <zsh>` fails when wrong password entered. Loop re-prompts until retry
succeeds or user skips.
**Location:** `install/00_packages.sh`
**Runs:** 3, 5, 6.

| ID | Given                           | When                                   | Then                                        |
|:--:| ------------------------------- | -------------------------------------- | ------------------------------------------- |
| A1 | `chsh` fails                    | User enters `r`                        | Loop continues; `chsh` called again         |
| A2 | `chsh` fails                    | User enters `R`                        | Same as A1                                  |
| A3 | `chsh` fails                    | User enters `s`                        | Warning: skip; script continues             |
| A4 | `chsh` fails                    | User enters `S`                        | Same as A3                                  |
| A5 | `chsh` fails                    | User enters any other input            | Warning: invalid choice; prompt shown again |
| A6 | `chsh` fails, then user retries | User enters `r`, then correct password | Shell changed; loop exits                   |

---

## Group P0 — `install/00_packages.sh`: apt dist-upgrade

**Context:** On Debian/Ubuntu systems, `apt dist-upgrade` runs after `apt update` and before
package installation to fully update the system (resolves dependency graph — adds/removes
packages as needed). The `dnf` path already performs `dnf5 upgrade -y` equivalently.
**Location:** `install/00_packages.sh`
**Runs:** 3 (Ubuntu, covered implicitly); observable in log.

| ID   | Given                                 | When                    | Then                                                                                            |
|:----:| ------------------------------------- | ----------------------- | ----------------------------------------------------------------------------------------------- |
| P0-1 | Ubuntu/apt; packages upgradable       | `install_packages` runs | Log shows `STEP Upgrading system packages...` followed by `run_cmd: apt dist-upgrade`; no error |
| P0-2 | Ubuntu/apt; system already up to date | `install_packages` runs | `apt dist-upgrade` exits 0; step completes; `OK Base packages installed` shown                  |

---

## Group B — `lib/dotfiles.sh`: 1Password SSH key loops

**Context:** Retry loop when no keys found; selection menu when N > 1 keys.
**Location:** `lib/dotfiles.sh`
**Runs:** 3, 5, 6.

| ID | Given                  | When                         | Then                                                          |
|:--:| ---------------------- | ---------------------------- | ------------------------------------------------------------- |
| B1 | No keys in agent       | User enters `r`              | Loop retries; `ssh-add -L` called again                       |
| B2 | No keys in agent       | User enters `R`              | Same as B1                                                    |
| B3 | No keys in agent       | User enters `c`              | Warning: cancelled; dotfiles not applied; bootstrap continues |
| B4 | No keys in agent       | User enters `C`              | Same as B3                                                    |
| B5 | No keys in agent       | User enters any other input  | Warning: invalid choice; prompt shown again                   |
| B6 | Exactly 1 key in agent | —                            | Key selected automatically; no prompt shown                   |
| B7 | N > 1 keys             | User enters valid number     | Corresponding key selected; dotfiles applied                  |
| B8 | N > 1 keys             | User enters 0 or non-numeric | Warning: invalid selection; prompt shown again                |
| B9 | N > 1 keys             | User enters `c` or `C`       | Warning: cancelled; dotfiles not applied                      |

> **Note:** B6 is not testable in an environment where the 1Password agent always exposes
> more than one key.

---

## Group C — `lib/clean.sh`: destructive flag confirmations

**Context:** `--clean-install`, `--clean-tools`, `--reinstall` require explicit `y`
confirmation before executing. Default is N.
**Runs:** 3, 4.

### C1–C5: `--clean-install`

| ID | When                        | Then                              |
|:--:| --------------------------- | --------------------------------- |
| C1 | User enters `y`             | All destructive steps execute     |
| C2 | User enters `Y`             | Same as C1                        |
| C3 | User enters `n`             | Warning: aborted; nothing removed |
| C4 | User presses Enter (empty)  | Same as C3                        |
| C5 | User enters any other input | Same as C3                        |

### C6–C7: `--clean-tools`

| ID | When                             | Then                                                          |
|:--:| -------------------------------- | ------------------------------------------------------------- |
| C6 | User enters `y` or `Y`           | Dev tool dirs removed; state cleared; shell + dotfiles intact |
| C7 | User enters `n`, Enter, or other | Warning: aborted; nothing removed                             |

### C8–C9: `--reinstall`

| ID | When                             | Then                                            |
|:--:| -------------------------------- | ----------------------------------------------- |
| C8 | User enters `y` or `Y`           | Clean tools run; state reset; bootstrap re-runs |
| C9 | User enters `n`, Enter, or other | Warning: aborted; nothing removed               |

---

## Group D — Pipe-invocation and stdin isolation

**Context:** When invoked via `curl | bash`, stdin is the pipe. All `read` calls use
`</dev/tty` to bypass the pipe.
**Runs:** 3 (D3–D4), 4 (D1–D2, D5).

| ID | Given                                                                                                | When            | Then                                                           |
|:--:| ---------------------------------------------------------------------------------------------------- | --------------- | -------------------------------------------------------------- |
| D1 | Direct invocation: `bash setup/phase3-setup-bootstrap.sh --clean-tools`                              | User enters `y` | Confirmation read correctly; clean executes                    |
| D2 | Direct invocation                                                                                    | User enters `n` | Abort shown; nothing removed                                   |
| D3 | Pipe invocation via local Gist: `bash gist/linux-init-local-phase3-linux-bootstrap.sh --clean-tools` | User enters `y` | Confirmation read from `/dev/tty`; clean executes despite pipe |
| D4 | Pipe invocation                                                                                      | User enters `n` | Abort shown; nothing removed                                   |
| D5 | `bash setup/phase3-setup-bootstrap.sh < /dev/null`                                                   | Prompt reached  | Non-interactive detected; defaults to Y; all tools install     |

---

## Group E — `--reinstall` single-confirmation regression

**Context:** `--reinstall` must show exactly one confirmation prompt (no double-prompt from
calling `_clean_tools` internally).
**Runs:** 3, 4.

| ID | Given                                              | When            | Then                                                                             |
|:--:| -------------------------------------------------- | --------------- | -------------------------------------------------------------------------------- |
| E1 | `bash setup/phase3-setup-bootstrap.sh --reinstall` | User enters `y` | Exactly one `Continue? [y/N]:` prompt; clean runs; state reset; no second prompt |
| E2 | `bash setup/phase3-setup-bootstrap.sh --reinstall` | User enters `n` | Exactly one prompt; abort shown; nothing removed                                 |

---

## Group I — Idempotency

**Context:** Re-running bootstrap with all modules already complete must skip every module
and apply dotfiles without re-prompting for tools.
**Run:** 4.

| ID | Given                              | When                                             | Then                                                                                   |
|:--:| ---------------------------------- | ------------------------------------------------ | -------------------------------------------------------------------------------------- |
| I1 | All modules complete in state      | `bash setup/phase3-setup-bootstrap.sh`           | Every module shows `⊙ already complete`; no install runs                               |
| I2 | All modules complete               | `bash setup/phase3-setup-bootstrap.sh --verbose` | Same as I1; no regressions in verbose output                                           |
| I3 | `phase_dotfiles=complete` in state | Bootstrap runs                                   | `⊙ chezmoi.toml already exists` shown; dotfiles re-applied cleanly                     |
| I4 | Phase 2 already complete           | Phase 2 re-run                                   | `✓ Phase 2 already complete — skipping`                                                |
| I5 | `phase_windows=complete` in state  | Bootstrap runs again on WSL2                     | PS1 invocation skipped entirely; `⊙ phase1-setup-windows.ps1 — already complete` shown |

---

## Group M — `--modules` flag

**Context:** `--modules` runs only the specified modules; confirmation prompts operate
within modules normally.
**Run:** 4.

| ID | Given                                         | When           | Then                                                                |
|:--:| --------------------------------------------- | -------------- | ------------------------------------------------------------------- |
| M1 | `--modules python`                            | Bootstrap runs | Only module 03 executes; all others skipped                         |
| M2 | `--modules java,node`                         | Bootstrap runs | Modules 04 and 05 execute; all others skipped                       |
| M3 | `--modules ai` with Node.js already installed | Bootstrap runs | Module 06 executes; Node guard satisfied                            |
| M4 | `--modules ai` with Node.js absent            | Bootstrap runs | Node guard triggers; offers NVM install; if declined, module aborts |

---

## Group W — `phase_windows` state guard (WSL2 only)

**Context:** `phase3-setup-bootstrap.sh` now tracks `phase_windows=complete` in state so
that `phase1-setup-windows.ps1` is only invoked once per bootstrap lifecycle, eliminating
the double SSH-key-capture appearance on re-runs.
**Run:** 4 (Ubuntu, state intact after Run 3).

| ID | Given                                     | When                         | Then                                                                                                          |
|:--:| ----------------------------------------- | ---------------------------- | ------------------------------------------------------------------------------------------------------------- |
| W1 | `phase_windows` absent in state           | Bootstrap runs on WSL2       | PS1 invoked; on success `phase_windows=complete` written to state                                             |
| W2 | `phase_windows=complete` in state         | Bootstrap runs again on WSL2 | PS1 skipped; `⊙ phase1-setup-windows.ps1 — already complete` displayed                                        |
| W3 | `--reinstall` executed (state file wiped) | Bootstrap runs next          | `phase_windows` absent; PS1 invoked again; key captured fresh                                                 |
| W4 | `--clean-tools` executed                  | Bootstrap runs next          | `phase_windows` still present; PS1 skipped; key not re-captured                                               |
| W5 | Fresh install on WSL2 (no state file)     | Full bootstrap runs          | `signing_key` prompted once; dotfiles section shows `✓ signing_key loaded from state file`; no second prompt  |

**Setup for W1/W2 (Run 4, inside WSL):**

```bash
# W1 — remove phase_windows to force re-invoke
sed -i '/^phase_windows=/d' ~/.bootstrap-state
bash /mnt/c/Dev/repos/personal_projects/linux-init-bootstrap/setup/phase3-setup-bootstrap.sh --verbose --skip-dotfiles \
  2>&1 | tee /mnt/c/Dev/repos/personal_projects/test_results/ubuntu-run4-group-w1.log
# Expected: PS1 runs; signing_key capture shown; phase_windows=complete written

# W2 — phase_windows now complete; verify PS1 is skipped
bash /mnt/c/Dev/repos/personal_projects/linux-init-bootstrap/setup/phase3-setup-bootstrap.sh --verbose --skip-dotfiles \
  2>&1 | tee /mnt/c/Dev/repos/personal_projects/test_results/ubuntu-run4-group-w2.log
# Expected: "already complete" skip message; no PS1 output
```

---

## Group NI — `--non-interactive` flag

**Context:** `--non-interactive` suppresses all interactive prompts. Destructive flags abort immediately. SSH signing key auto-selects the first available key. The `chsh` retry loop exits with skip. Added in this feature branch as part of the `--non-interactive` implementation.

**Location:** `setup/phase3-setup-bootstrap.sh`, `lib/clean.sh`, `lib/dotfiles.sh`, `lib/output.sh`, `install/00_packages.sh`

**Run:** 4 (NI1–NI5, Ubuntu, state intact), 6 (NI6, Ubuntu, agent disabled).

| ID  | Given                                                        | When                                | Then                                                                                                                   |
| --- | ------------------------------------------------------------ | ----------------------------------- | ---------------------------------------------------------------------------------------------------------------------- |
| NI1 | State complete, `signing_key` present in state               | `--non-interactive`                 | All modules skipped; no prompts shown; exits with `Bootstrap complete`                                                 |
| NI2 | `signing_key` removed from state; 1Password agent has N keys | `--non-interactive`                 | PS1 invoked with `-NonInteractive`; first key auto-selected; `signing_key` written to state; no selection prompt shown |
| NI3 | Any state                                                    | `--non-interactive --clean-tools`   | Warning: `Non-interactive mode — --clean-tools requires explicit confirmation; aborting`; nothing removed              |
| NI4 | Any state                                                    | `--non-interactive --reinstall`     | Warning: `Non-interactive mode — --reinstall requires explicit confirmation; aborting`; nothing removed                |
| NI5 | Any state                                                    | `--non-interactive --clean-install` | Warning: `Non-interactive mode — --clean-install requires explicit confirmation; aborting`; nothing removed            |
| NI6 | 1Password agent disabled; `signing_key` absent from state    | `--non-interactive --skip-dotfiles` | Warning: `Non-interactive mode — cannot prompt for retry; dotfiles not applied`; bootstrap continues without dotfiles  |

**Setup (Run 4, inside WSL — executar após sub-run 5):**

```bash
# NI1 — já coberto pelo sub-run 5 (estado completo + --non-interactive)

# NI2 — já coberto pelo sub-run 5 (signing_key removida + --non-interactive)

# NI3
bash /mnt/c/Dev/repos/personal_projects/linux-init-bootstrap/setup/phase3-setup-bootstrap.sh --verbose --non-interactive --clean-tools
cp ~/.linux-init-bootstrap.log /mnt/c/Dev/repos/personal_projects/test_results/ubuntu-run4-non-interactive-clean-tools.log

# NI4
bash /mnt/c/Dev/repos/personal_projects/linux-init-bootstrap/setup/phase3-setup-bootstrap.sh --verbose --non-interactive --reinstall
cp ~/.linux-init-bootstrap.log /mnt/c/Dev/repos/personal_projects/test_results/ubuntu-run4-non-interactive-reinstall.log

# NI5
bash /mnt/c/Dev/repos/personal_projects/linux-init-bootstrap/setup/phase3-setup-bootstrap.sh --verbose --non-interactive --clean-install
cp ~/.linux-init-bootstrap.log /mnt/c/Dev/repos/personal_projects/test_results/ubuntu-run4-non-interactive-clean-install.log
```

**Setup para NI6 (Run 6 — desabilitar agente 1Password antes):**

```bash
sed -i '/^signing_key=/d' ~/.bootstrap-state
bash /mnt/c/Dev/repos/personal_projects/linux-init-bootstrap/setup/phase3-setup-bootstrap.sh --verbose --non-interactive --skip-dotfiles
cp ~/.linux-init-bootstrap.log /mnt/c/Dev/repos/personal_projects/test_results/ubuntu-run6-ni6.log
```

---

## Group G — Gist remote entry points

**Context:** The three public Gist files download scripts from the new `setup/` paths on
GitHub raw and execute them. Requires a real network connection and a merged, pushed commit.
**Run:** after merge to main only.

| ID | Given                              | When                                 | Then                                                                                                |
|:--:| ---------------------------------- | ------------------------------------ | --------------------------------------------------------------------------------------------------- |
| G1 | Network available                  | Phase 1 Gist invoked from PowerShell | Downloads `setup/phase1-setup-windows.ps1` and `setup/phase1-setup-windows-admin.ps1`; runs phase 1 |
| G2 | Network available                  | Phase 2 Gist invoked                 | Downloads `setup/phase2-setup-prereqs-linux.sh`; runs Phase 2                                       |
| G3 | Network available                  | Phase 3 Gist invoked                 | Clones repo; calls `setup/phase3-setup-bootstrap.sh`; full bootstrap runs                           |
| G4 | `--verbose` passed to Phase 3 Gist | `curl ... \| bash -s -- --verbose`   | Flag forwarded; verbose output appears                                                              |
| G5 | Repo already cloned                | Phase 3 Gist re-invoked              | "Repo already cloned" message; no second clone; bootstrap runs                                      |

---

## Regression Checks

After every run, verify these invariants:

| Check                                               | How to verify                                                      |
| --------------------------------------------------- | ------------------------------------------------------------------ |
| Bootstrap log written                               | `tail -20 ~/.linux-init-bootstrap.log`                             |
| `--clean-install` abort leaves `~/Dev/tools` intact | `ls ~/Dev/tools` — directory must exist                            |
| `--clean-tools` abort leaves state entries intact   | `cat ~/.bootstrap-state` — module entries present                  |
| `--reinstall` abort leaves state file intact        | `cat ~/.bootstrap-state` — file must exist                         |
| Re-run after cancelled clean resumes correctly      | `bash setup/phase3-setup-bootstrap.sh` — completed modules skipped |
| Platform detected correctly                         | Log header shows correct `Platform:` and `Package manager:`        |
