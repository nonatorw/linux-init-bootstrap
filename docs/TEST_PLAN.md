# Test Plan — Input Confirmation Loops and Gist Entry Points

Manual test plan for the user input confirmation loops in `install/00_packages.sh`, `lib/dotfiles.sh`, and `lib/clean.sh`, and for the Gist entry point scripts (`gist/`).

Each scenario follows the **Given / When / Then** structure. Unless noted otherwise, execute inside WSL2.

All test logs are stored in `C:\Dev\repos\personal_projects\test_results\`.

---

## Before Test — WSL Instance Provisioning

This section must be executed **every time a new feature branch requires testing**. It creates clean WSL instances with all prerequisites configured. Do not skip any step.

### Log directory

Create the log directory on Windows before starting any test run:

```powershell
New-Item -ItemType Directory -Force "C:\Dev\repos\personal_projects\test_results"
```

### Verify repository and branch (Windows — do first)

Before creating any WSL instance, confirm the repository is checked out on the correct feature branch:

```powershell
cd C:\Dev\repos\personal_projects\linux-init-bootstrap
git status
git branch --show-current
```

Expected: the feature branch under test (e.g. `feature/tool-confirmation-uv-migration`). If not, check out the correct branch before proceeding — the WSL instances mount the Windows filesystem directly at `/mnt/c/`, so the scripts they run are read live from this directory.

### Create Ubuntu instance

```powershell
wsl --install Ubuntu-26.04 --web-download --name Ubuntu-26-<feature-name>
```

> Replace `<feature-name>` with a short slug for the feature under test (e.g. `tool-confirm`).

Follow the distro first-run prompts to create user `nonatorw` and set a password. The password set here is used by `sudo` and by `chsh` during bootstrap — choose one you can type reliably.

Enable systemd and configure boot command to keep Windows interop active across sessions (required for `powershell.exe` and `ssh-add.exe` to be reachable from WSL2):

```bash
sudo bash -c 'cat > /etc/wsl.conf << EOF
[boot]
systemd=true
command = systemctl restart systemd-binfmt.service
EOF'
```

Restart the instance to activate systemd:

```powershell
wsl --shutdown
wsl -d Ubuntu-26-<feature-name>
```

Verify systemd and interop are fully active:

```bash
ls /proc/sys/fs/binfmt_misc/WSLInterop && echo "interop ativo"
ssh-add.exe -L && echo "1Password agent acessível"
```

Expected: `interop ativo` printed, SSH keys listed. If no keys appear, ensure 1Password Desktop is running on Windows with SSH agent enabled before proceeding.

Verify that the repository is accessible from WSL:

```bash
ls /mnt/c/Dev/repos/personal_projects/linux-init-bootstrap/setup/phase3-setup-bootstrap.sh && echo OK
```

Expected: `OK` printed. If the file is not found, the Windows path is wrong or the repository was not cloned.

Verify distro identity:

```bash
lsb_release -a && echo OK
```

Expected: Ubuntu version info printed, `OK` on the last line.

> **Why systemd is required:** Ubuntu WSL2 does not enable systemd by default. Without it, the Windows interop binfmt_misc entries are not registered, which means `powershell.exe` and `ssh-add.exe` fail with "Exec format error" even though the interop socket (`WSL_INTEROP`) is present. The bootstrap relies on `powershell.exe` to run Phase 1 Windows prerequisites and on `ssh-add.exe` to read SSH keys from the 1Password agent.

### Create Fedora instance

```powershell
wsl --install FedoraLinux-44 --web-download --name Fedora-44-<feature-name>
```

Follow the distro first-run prompts to create user `nonatorw`.

Inside the Fedora session, **set the sudo password** (required for any `sudo` call during bootstrap):

```bash
sudo passwd nonatorw
```

Enable systemd and configure boot command to keep Windows interop active across sessions (required for `powershell.exe` and `ssh-add.exe` to be reachable from WSL2):

```bash
sudo bash -c 'cat > /etc/wsl.conf << EOF
[boot]
systemd=true
command = systemctl restart systemd-binfmt.service
EOF'
```

Restart the instance to activate systemd:

```powershell
wsl --shutdown
wsl -d Fedora-44-<feature-name>
```

Fix the `audit` services that fail on WSL2 and cause systemd to report `degraded` (they require kernel features unavailable in WSL2):

```bash
sudo systemctl mask audit-rules.service auditd.service
```

Restart the instance once more to confirm the masked services and boot command take effect:

```powershell
wsl --shutdown
wsl -d Fedora-44-<feature-name>
```

Verify systemd and interop are fully active:

```bash
systemctl is-system-running
ls /proc/sys/fs/binfmt_misc/WSLInterop && echo "interop ativo"
ssh-add.exe -L && echo "1Password agent acessível"
```

Expected:

- `systemctl is-system-running` → `running` (not `degraded`)
- `interop ativo` printed
- `ssh-add.exe -L` lists SSH keys from 1Password agent

Verify distro identity:

```bash
cat /etc/fedora-release && echo OK
```

Expected: Fedora release string printed, `OK` on the last line.

> **Why systemd is required:** Fedora WSL2 does not enable systemd by default. Without it, the Windows interop layer does not activate correctly, which means `powershell.exe` and `ssh-add.exe` are not reachable from within WSL2. The bootstrap relies on `ssh-add.exe` to read SSH keys from the 1Password agent for dotfile signing key resolution.
>
> **Why sudo password is required:** Fedora's default WSL2 image may not configure passwordless sudo for the initial user. The bootstrap calls `sudo` during package installation (dnf). Without a password set, those calls hang or fail.
>
> **Why audit services must be masked:** `audit-rules.service` and `auditd.service` require kernel audit subsystem features unavailable in WSL2. They fail on every boot, causing systemd to report `degraded` and preventing `systemd-binfmt.service` from registering PE binary execution (Windows interop). Masking them permanently suppresses the failure.

---

## Execution Sequence

Tests are executed in six ordered runs. Each run has a fixed environment and scope.

| Run | Environment                  | Distro | Scope                                                                     | Status |
|:---:| ---------------------------- | ------ | ------------------------------------------------------------------------- | ------ |
|  1  | Create Ubuntu WSL2 image     | Ubuntu | Provisioning only — no test execution                                     | ✔ Done |
|  2  | Create Fedora WSL2 image     | Fedora | Provisioning only — no test execution                                     | ✔ Done |
|  3  | Ubuntu — first execution     | Ubuntu | All phases fresh: Phase 1 (Windows) + Phase 2 + Phase 3; Groups A-E, K, L | ✔ Done |
|  4  | Ubuntu — second execution    | Ubuntu | State from Run 3 intact; idempotency + clean flags; Groups C, D, E        | ✔ Done |
|  5  | Fedora — first execution     | Fedora | All phases fresh: Phase 2 + Phase 3; Groups A-E, K                        | ✔ Done |
|  6  | Ubuntu — error condition run | Ubuntu | Deliberate error conditions: Groups A, B                                  | ✔ Done |

**Phase 1 (Windows side) runs once** — it is platform-independent and executed during Run 3 only.

---

## Run 1 — Create Ubuntu WSL2 image

Follow the **Before Test — Create Ubuntu instance** section above, using name `Ubuntu-26-feature-tool-confirm`.

---

## Run 2 — Create Fedora WSL2 image

Follow the **Before Test — Create Fedora instance** section above, using name `Fedora-44-feature-tool-confirm`.

---

## Run 3 — Ubuntu: first execution (all phases, fresh)

### Run 3 pre-conditions

- Ubuntu WSL2 distro created in Run 1 (name: `Ubuntu-26-feature-tool-confirm`)
- No bootstrap state file (`~/.bootstrap-state` does not exist)
- 1Password Desktop running on Windows with SSH agent enabled
- At least one SSH key stored as a native SSH Key item in 1Password

### Step 1 — Phase 1 (Windows side, run once)

Execute from a **normal PowerShell window** (not elevated):

```powershell
$tmp = "$env:TEMP\linux-init-phase1.ps1"
Invoke-WebRequest "https://gist.githubusercontent.com/nonatorw/79321dfef85099cdbad1d2f0fda5f959/raw/linux-init-phase1-windows-prereqs.ps1" -OutFile $tmp
powershell.exe -ExecutionPolicy Bypass -File $tmp
```

**Scenarios covered:** L1–L10 (see Group L below)

### Step 2 — Phase 2 (interactive WSL session)

Phase 2 runs `sudo apt update` / `sudo dnf check-update` which requires a visible password
prompt — piping breaks it. Run directly in the interactive terminal and copy the log after.

```bash
bash /mnt/c/Dev/repos/personal_projects/linux-init-bootstrap/gist/linux-init-local-phase2-linux-prereqs.sh
cp ~/.linux-init-bootstrap.log /mnt/c/Dev/repos/personal_projects/test_results/ubuntu-run3-phase2.log
```

**Scenarios covered:** K1, K2 (network failure must be simulated separately)

### Step 3 — Phase 3 (interactive WSL session)

Phase 3 triggers interactive prompts (Groups A, B, C, D, E) that require a TTY. Open an interactive WSL session and run the bootstrap directly:

```powershell
wsl -d Ubuntu-26-feature-tool-confirm
```

Phase 3 must run directly in the interactive terminal — piping breaks Windows interop
(`powershell.exe`, `ssh-add.exe`). The bootstrap writes its own log to `~/.linux-init-bootstrap.log`.
Copy it after the run completes.

```bash
bash /mnt/c/Dev/repos/personal_projects/linux-init-bootstrap/gist/linux-init-local-phase3-linux-bootstrap.sh --verbose
cp ~/.linux-init-bootstrap.log /mnt/c/Dev/repos/personal_projects/test_results/ubuntu-run3-phase3.log
```

**Scenarios covered:** K4, K6, D3, D4, A1–A6, B1–B9, C1–C9, E1–E2

---

## Run 4 — Ubuntu: second execution (state from Run 3 intact)

### Run 4 pre-conditions

- Same Ubuntu distro from Run 3 — do not reset state
- `~/.bootstrap-state` exists with all modules marked `complete`
- `~/Dev/tools` directories exist

### Run 4 scope

Validates idempotency and destructive flag behaviour against an already-installed environment.

**Scenarios covered:** C1–C9, D1–D2, D5, E1–E2, K3, K5

### Run 4 steps

Open an interactive WSL session (prompts require TTY throughout):

```powershell
wsl -d Ubuntu-26-feature-tool-confirm
```

Execute in the order below inside WSL. Each step depends on state left by the previous one.
`--clean-install` is last because it destroys `~/Dev/tools`, `~/.bootstrap-state`, and dotfiles,
leaving the environment unrecoverable for further tests.

Each sub-run must execute directly in the interactive terminal. Copy the log after each run
before starting the next — the log file is overwritten on each execution.

```bash
# 1. Idempotency — bootstrap skips completed modules
bash /mnt/c/Dev/repos/personal_projects/linux-init-bootstrap/setup/phase3-setup-bootstrap.sh --verbose
cp ~/.linux-init-bootstrap.log /mnt/c/Dev/repos/personal_projects/test_results/ubuntu-run4-idempotency.log

# 2. --clean-tools abort — enter 'n' at prompt; verify nothing is removed
bash /mnt/c/Dev/repos/personal_projects/linux-init-bootstrap/setup/phase3-setup-bootstrap.sh --verbose --clean-tools
cp ~/.linux-init-bootstrap.log /mnt/c/Dev/repos/personal_projects/test_results/ubuntu-run4-clean-tools-n.log

# 3. --reinstall abort — enter 'n' at prompt; verify nothing is removed
bash /mnt/c/Dev/repos/personal_projects/linux-init-bootstrap/setup/phase3-setup-bootstrap.sh --verbose --reinstall
cp ~/.linux-init-bootstrap.log /mnt/c/Dev/repos/personal_projects/test_results/ubuntu-run4-reinstall-n.log

# 4. --reinstall confirm — enter 'y'; clears state and tools
bash /mnt/c/Dev/repos/personal_projects/linux-init-bootstrap/setup/phase3-setup-bootstrap.sh --verbose --reinstall
cp ~/.linux-init-bootstrap.log /mnt/c/Dev/repos/personal_projects/test_results/ubuntu-run4-reinstall-y.log

# 5. Non-interactive — signing_key e chezmoi.toml removidos; PS1 re-captura e auto-seleciona primeiro key
#    Remove chezmoi.toml too — otherwise _resolve_signing_key is never called (toml already exists path)
sed -i '/^signing_key=/d; /^phase_windows=/d' ~/.bootstrap-state
rm -f ~/.config/chezmoi/chezmoi.toml
bash /mnt/c/Dev/repos/personal_projects/linux-init-bootstrap/setup/phase3-setup-bootstrap.sh --verbose --non-interactive
cp ~/.linux-init-bootstrap.log /mnt/c/Dev/repos/personal_projects/test_results/ubuntu-run4-non-interactive.log

# 5b. Non-interactive + --clean-tools — must abort without prompting
bash /mnt/c/Dev/repos/personal_projects/linux-init-bootstrap/setup/phase3-setup-bootstrap.sh --verbose --non-interactive --clean-tools
cp ~/.linux-init-bootstrap.log /mnt/c/Dev/repos/personal_projects/test_results/ubuntu-run4-non-interactive-clean-tools.log

# 5c. Non-interactive + --reinstall — must abort without prompting
bash /mnt/c/Dev/repos/personal_projects/linux-init-bootstrap/setup/phase3-setup-bootstrap.sh --verbose --non-interactive --reinstall
cp ~/.linux-init-bootstrap.log /mnt/c/Dev/repos/personal_projects/test_results/ubuntu-run4-non-interactive-reinstall.log

# 6. --clean-tools confirm — enter 'y'; removes dev tool directories and tool state
bash /mnt/c/Dev/repos/personal_projects/linux-init-bootstrap/setup/phase3-setup-bootstrap.sh --verbose --clean-tools
cp ~/.linux-init-bootstrap.log /mnt/c/Dev/repos/personal_projects/test_results/ubuntu-run4-clean-tools-y.log
```

---

## Run 5 — Fedora: first execution (fresh)

### Run 5 pre-conditions

- Fedora WSL2 distro created in Run 2 (name: `Fedora-44-feature-tool-confirm`)
- No bootstrap state file (`~/.bootstrap-state` does not exist)
- sudo password set for `nonatorw` (done during Before Test)
- systemd enabled and active (done during Before Test)
- Phase 1 already executed in Run 3 (Windows side does not repeat)
- 1Password SSH agent active (same Windows setup)

### Step 1 — Phase 2 (interactive WSL session)

```powershell
wsl -d Fedora-44-feature-tool-confirm
```

```bash
bash /mnt/c/Dev/repos/personal_projects/linux-init-bootstrap/gist/linux-init-local-phase2-linux-prereqs.sh
cp ~/.linux-init-bootstrap.log /mnt/c/Dev/repos/personal_projects/test_results/fedora-run5-phase2.log
```

**Scenarios covered:** K1 (Fedora / dnf path)

### Step 2 — Phase 3 (interactive WSL session)

```powershell
wsl -d Fedora-44-feature-tool-confirm
```

```bash
bash /mnt/c/Dev/repos/personal_projects/linux-init-bootstrap/gist/linux-init-local-phase3-linux-bootstrap.sh --verbose
cp ~/.linux-init-bootstrap.log /mnt/c/Dev/repos/personal_projects/test_results/fedora-run5-phase3.log
```

**Scenarios covered:** K4, D3, D4, A1–A6, B1–B9, C1–C9

---

## Run 6 — Ubuntu: error condition run (Groups A, B)

### Run 6 pre-conditions

- Ubuntu WSL2 distro from Run 3/4 with bootstrap fully installed
- zsh already set as default shell (so Group A can only be triggered on a fresh distro or after resetting the shell)

### Group A — setup

Group A requires `chsh` to fail. The only reliable way is to use a fresh distro where zsh is not yet the default shell, and deliberately enter the wrong password when `chsh` prompts for it.

Recommended approach: reset the default shell to bash first:

```bash
# Reset default shell to bash so chsh runs again on next bootstrap
sudo chsh -s /bin/bash nonatorw
# Clear packages module state so bootstrap re-runs it (chsh lives in 00_packages.sh)
sed -i '/^module_00_packages=/d' ~/.bootstrap-state
```

Then run the bootstrap and deliberately enter the wrong password at the `chsh` PAM prompt to trigger A1–A5:

```bash
bash /mnt/c/Dev/repos/personal_projects/linux-init-bootstrap/setup/phase3-setup-bootstrap.sh --verbose --modules packages
cp ~/.linux-init-bootstrap.log /mnt/c/Dev/repos/personal_projects/test_results/ubuntu-run6-group-a.log
```

### Group B — setup

Group B tests the retry loop triggered when `ssh-add.exe -L` returns no keys, and the multi-key selection menu triggered when more than one key is found.

**B1–B5 (no keys):** Disable the SSH agent in 1Password before running.

1. In 1Password → Settings → Developer → uncheck "Use the SSH agent"

2. Confirm it is off:

   ```bash
   ssh-add.exe -L 2>&1
   # Expected: "Error connecting to agent: No such file or directory"
   ```

3. Prepare state:

   ```bash
   sed -i '/^signing_key=/d' ~/.bootstrap-state
   sed -i '/^phase_dotfiles=/d' ~/.bootstrap-state
   rm -f ~/.config/chezmoi/chezmoi.toml
   ```

4. Run directly in the interactive terminal:

   ```bash
   bash /mnt/c/Dev/repos/personal_projects/linux-init-bootstrap/setup/phase3-setup-bootstrap.sh --verbose --skip-dotfiles
   cp ~/.linux-init-bootstrap.log /mnt/c/Dev/repos/personal_projects/test_results/ubuntu-run6-group-b.log
   ```

   At `[R]etry / [C]ancel`: enter `r` (B1) → `R` (B2) → `c` (B3). Repeat run for `C` (B4) and invalid input `x` (B5).

**B6–B9 (keys present, multi-key selection):** Re-enable the SSH agent before running.

1. In 1Password → Settings → Developer → check "Use the SSH agent"

2. Confirm keys are visible:

   ```bash
   ssh-add.exe -L 2>&1
   # Expected: two ssh-ed25519 keys listed
   ```

3. Prepare state (disable agent again for B6 retry path, re-enable mid-run):

   ```bash
   sed -i '/^signing_key=/d' ~/.bootstrap-state
   sed -i '/^phase_dotfiles=/d' ~/.bootstrap-state
   rm -f ~/.config/chezmoi/chezmoi.toml
   ```

   Disable agent again → run bootstrap → at `[R]etry / [C]ancel` re-enable agent then enter `r` (B6) → menu appears → enter `0` (B8 — invalid) → `1` (B7 — valid selection).

4. Repeat run for B9: prepare state, run with agent enabled, at `Enter number (1-2) or [C]ancel` enter `c`.

---

## Group P0 — `install/00_packages.sh`: apt dist-upgrade

**Context:** On Debian/Ubuntu systems, `apt dist-upgrade` runs after `apt update` and before
package installation to fully update the system (resolves dependency graph — adds/removes
packages as needed). The `dnf` path already performs `dnf5 upgrade -y` equivalently.
**Location:** `install/00_packages.sh`
**Runs:** 3 (Ubuntu, covered implicitly); observable in log.

| ID   | Given                                 | When                    | Then                                                                                            |
| :--: | ------------------------------------- | ----------------------- | ----------------------------------------------------------------------------------------------- |
| P0-1 | Ubuntu/apt; packages upgradable       | `install_packages` runs | Log shows `STEP Upgrading system packages...` followed by `run_cmd: apt dist-upgrade`; no error |
| P0-2 | Ubuntu/apt; system already up to date | `install_packages` runs | `apt dist-upgrade` exits 0; step completes; `OK Base packages installed` shown                  |

---

## Group A — `install/00_packages.sh`: chsh confirmation loop

**Context:** Triggered when `chsh -s <zsh_path>` fails (wrong password or PAM error). The loop re-prompts until the user retries successfully or skips.

**Location:** `install/00_packages.sh:124–138`

**Runs:** 3, 5

**Setup to trigger A1–A5:** `chsh` only fails when the wrong password is entered at the PAM prompt. To reliably trigger the loop, enter a wrong password deliberately when `chsh` prompts for it during the bootstrap run.

| ID | Given                                   | When                                                        | Then                                                                                                           |
| -- | --------------------------------------- | ----------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------- |
| A1 | `chsh` fails (simulated wrong password) | User enters `r`                                             | Loop continues; `chsh` is called again on next iteration; no error message about invalid input                 |
| A2 | `chsh` fails                            | User enters `R`                                             | Same as A1                                                                                                     |
| A3 | `chsh` fails                            | User enters `s`                                             | Warning displayed: `Skipping — set default shell manually: chsh -s <zsh_path>`; script continues past the loop |
| A4 | `chsh` fails                            | User enters `S`                                             | Same as A3                                                                                                     |
| A5 | `chsh` fails                            | User enters any other input (e.g. `x`, empty Enter)         | Warning displayed: `Invalid choice — enter R to retry or S to skip.`; prompt is shown again                    |
| A6 | `chsh` succeeds on retry                | User previously entered `r`, then provides correct password | Success message displayed; loop exits                                                                          |

---

## Group B — `lib/dotfiles.sh`: 1Password SSH key retry loop

**Context:** Triggered when `ssh-add -L` (or `ssh-add.exe -L` on WSL2) returns no keys. The loop re-prompts until a key is found or the user cancels.

**Location:** `lib/dotfiles.sh:32–59`

**Runs:** 3, 5

| ID | Given                                  | When                                                    | Then                                                                                                                                                                       |
| -- | -------------------------------------- | ------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| B1 | 1Password SSH agent has no keys loaded | User enters `r`                                         | Loop continues; `ssh-add -L` is called again; no error message about invalid input                                                                                         |
| B2 | 1Password SSH agent has no keys loaded | User enters `R`                                         | Same as B1                                                                                                                                                                 |
| B3 | 1Password SSH agent has no keys loaded | User enters `c`                                         | Warning: `Cancelled by user — dotfiles not applied`; function returns 1; bootstrap continues with a warning                                                                |
| B4 | 1Password SSH agent has no keys loaded | User enters `C`                                         | Same as B3                                                                                                                                                                 |
| B5 | 1Password SSH agent has no keys loaded | User enters any other input (e.g. `x`, empty Enter)     | Warning: `Invalid choice — enter R to retry or C to cancel.`; prompt is shown again                                                                                        |
| B6 | 1Password SSH agent has exactly 1 key  | — (no prompt shown)                                     | Key is selected automatically; message: `SSH signing key detected automatically`; proceeds to chezmoi. **Not testable in this environment** (agent always exposes 2 keys). |
| B7 | 1Password SSH agent has N > 1 keys     | User enters a valid number (1 to N)                     | Corresponding key is selected; message: `SSH signing key selected`; proceeds to chezmoi                                                                                    |
| B8 | 1Password SSH agent has N > 1 keys     | User enters a number outside range or non-numeric input | Warning: `Invalid selection — enter a number between 1 and N, or C to cancel`; prompt is shown again                                                                       |
| B9 | 1Password SSH agent has N > 1 keys     | User enters `c` or `C`                                  | Warning: `Cancelled by user — dotfiles not applied`; function returns 1                                                                                                    |

---

## Group C — `lib/clean.sh`: destructive operation y/N confirmation

**Context:** Triggered when `--clean-install`, `--clean-tools`, or `--reinstall` flags are passed to `bootstrap.sh`. Each function requires explicit `y` confirmation before executing any destructive action.

**Runs:** 3 (first confirmation behaviour), 4 (full destructive execution against real state)

### C1–C5: `_clean_install` (`bash bootstrap.sh --clean-install`)

| ID | When                                           | Then                                                                                                    |
| -- | ---------------------------------------------- | ------------------------------------------------------------------------------------------------------- |
| C1 | User enters `y`                                | All destructive steps execute: `~/Dev/tools` removed, `chezmoi purge` run, `~/.bootstrap-state` removed |
| C2 | User enters `Y`                                | Same as C1                                                                                              |
| C3 | User enters `n`                                | Warning: `Aborted by user`; function returns; nothing is removed                                        |
| C4 | User presses Enter (empty input, default N)    | Same as C3                                                                                              |
| C5 | User enters any other input (e.g. `x`, `yes`)  | Same as C3 — only exact `y` or `Y` proceeds                                                             |

### C6–C7: `_clean_tools` (`bash bootstrap.sh --clean-tools`)

| ID | When                                     | Then                                                                                                         |
| -- | ---------------------------------------- | ------------------------------------------------------------------------------------------------------------ |
| C6 | User enters `y` or `Y`                   | Dev tool directories removed; tool state entries cleared; package cleanup runs; shell and dotfiles untouched |
| C7 | User enters `n`, Enter, or anything else | Warning: `Aborted by user`; nothing is removed                                                               |

### C8–C9: `_reinstall` (`bash bootstrap.sh --reinstall`)

| ID | When                                     | Then                                                                                                    |
| -- | ---------------------------------------- | ------------------------------------------------------------------------------------------------------- |
| C8 | User enters `y` or `Y`                   | `_do_clean_tools` executes; `~/.bootstrap-state` removed; script exits with message to re-run bootstrap |
| C9 | User enters `n`, Enter, or anything else | Warning: `Aborted by user`; nothing is removed; script exits cleanly                                    |

---

## Group D — Pipe-invocation and stdin isolation

**Context:** When the script is run via `curl ... | bash`, the shell's `stdin` is the pipe, not the terminal. All `read` calls use `</dev/tty` to read directly from the terminal, bypassing the pipe. These scenarios validate that interactive prompts work correctly in both invocation modes.

**Runs:** 3 (D3–D4 via Gist), 4 (D1–D2 direct, D5 non-interactive)

| ID | Given                                                                                       | When                                          | Then                                                                                                                                            |
| -- | ------------------------------------------------------------------------------------------- | --------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------- |
| D1 | Script invoked directly: `bash bootstrap.sh --clean-tools`                                  | User enters `y` at the prompt                 | Confirmation is read correctly; clean executes                                                                                                  |
| D2 | Script invoked directly: `bash bootstrap.sh --clean-tools`                                  | User enters `n` at the prompt                 | Abort message shown; nothing removed                                                                                                            |
| D3 | Script invoked via pipe: `curl -fsSL ... \| bash -s -- --clean-tools`                       | User enters `y` at the prompt in the terminal | Confirmation is read from `/dev/tty`; clean executes despite pipe on stdin                                                                      |
| D4 | Script invoked via pipe: `curl -fsSL ... \| bash -s -- --clean-tools`                       | User enters `n` at the prompt                 | Abort message shown; nothing removed                                                                                                            |
| D5 | Script invoked with stdin redirected (`< /dev/null`) or via `curl \| bash` with no terminal | Prompt is reached                             | `_confirm` detects no `/dev/tty`, prints `non-interactive, defaulting to Y`, and proceeds without user input — all tools install automatically  |

---

## Group NI — `--non-interactive` flag

**Context:** `--non-interactive` suppresses all interactive prompts. Destructive flags (`--clean-install`, `--clean-tools`, `--reinstall`) abort immediately — they require explicit confirmation and are unsafe to auto-confirm. The SSH signing key auto-selects the first available key. The `_confirm()` helper and the `chsh` retry loop also respect the flag.

**Location:** `setup/phase3-setup-bootstrap.sh`, `lib/clean.sh`, `lib/dotfiles.sh`, `lib/output.sh`, `install/00_packages.sh`

**Runs:** 4 (NI1–NI5), 6 (NI6)

| ID  | Given                                                        | When                                | Then                                                                                                                    |
| --- | ------------------------------------------------------------ | ----------------------------------- | ----------------------------------------------------------------------------------------------------------------------- |
| NI1 | State complete, `signing_key` present in state               | `--non-interactive`                 | All modules skipped; no prompts shown; exits with `Bootstrap complete`                                                  |
| NI2 | `signing_key` removed from state; 1Password agent has N keys | `--non-interactive`                 | PS1 invoked with `-NonInteractive`; first key auto-selected; `signing_key` written to state; no selection prompt shown  |
| NI3 | Any state                                                    | `--non-interactive --clean-tools`   | Warning: `Non-interactive mode — --clean-tools requires explicit confirmation; aborting`; nothing removed               |
| NI4 | Any state                                                    | `--non-interactive --reinstall`     | Warning: `Non-interactive mode — --reinstall requires explicit confirmation; aborting`; nothing removed                 |
| NI5 | Any state                                                    | `--non-interactive --clean-install` | Warning: `Non-interactive mode — --clean-install requires explicit confirmation; aborting`; nothing removed             |
| NI6 | 1Password agent disabled; `signing_key` absent from state    | `--non-interactive --skip-dotfiles` | Warning: `Non-interactive mode — cannot prompt for retry; dotfiles not applied`; bootstrap continues without dotfiles   |

---

## Group E — `_reinstall` single-confirmation regression

**Context:** `_reinstall` previously called `_clean_tools`, which had its own `read` prompt, causing a double-confirmation UX. After refactor, `_reinstall` calls `_do_clean_tools` (no prompt) directly, so only one confirmation is shown.

**Runs:** 3, 4

| ID | Given                           | When            | Then                                                                                                    |
| -- | ------------------------------- | --------------- | ------------------------------------------------------------------------------------------------------- |
| E1 | `bash bootstrap.sh --reinstall` | User enters `y` | Exactly one `Continue? [y/N]:` prompt appears; `_do_clean_tools` runs; state is reset; no second prompt |
| E2 | `bash bootstrap.sh --reinstall` | User enters `n` | Exactly one prompt appears; abort message shown; nothing is removed                                     |

---

## Group K — Gist entry points: Phase 2 and Phase 3 (Linux/WSL)

### K1–K3: Phase 2 (`gist/linux-init-phase2-linux-prereqs.sh`)

**Context:** Downloads `setup-prereqs-linux.sh` into a `mktemp -d` directory and runs it. No repo clone is performed. Uses `set -euo pipefail`.

**Runs:** 3 (Ubuntu/apt), 4 (re-invocation), 5 (Fedora/dnf)

| ID | Given                                | When                                  | Then                                                                                      |
| -- | ------------------------------------ | ------------------------------------- | ----------------------------------------------------------------------------------------- |
| K1 | Network available                    | `curl -fsSL <gist-url> \| bash`       | `setup-prereqs-linux.sh` downloaded to a temp dir and executed; no repo clone happens     |
| K2 | `curl` fails (no network or bad URL) | Phase 2 invocation                    | `set -euo pipefail` aborts immediately; `setup-prereqs-linux.sh` is never executed        |
| K3 | Phase 2 already executed previously  | Re-invocation (Run 4)                 | `setup-prereqs-linux.sh` runs again; already-installed packages are skipped (idempotent)  |

### K4–K7: Phase 3 (`gist/linux-init-phase3-bootstrap.sh`)

**Context:** Clones the repo into `~/Dev/repos/linux-init-bootstrap` if not already present, then runs `bootstrap.sh "$@"`. All flags are forwarded. Uses `set -euo pipefail`.

**Runs:** 3, 4 (K5 re-invocation), 5

| ID | Given                                                  | When                                            | Then                                                                                                   |
| -- | ------------------------------------------------------ | ----------------------------------------------- | ------------------------------------------------------------------------------------------------------ |
| K4 | `~/Dev/repos/linux-init-bootstrap` does not exist      | `curl -fsSL <gist-url> \| bash`                 | `git clone` runs; repo created at `$DEST`; `bootstrap.sh` called                                       |
| K5 | `~/Dev/repos/linux-init-bootstrap/.git` already exists | Re-invocation of Phase 3 (Run 4)                | Message "Repo already cloned at $DEST" displayed; `git clone` is **not** called; `bootstrap.sh` called |
| K6 | Repo already exists                                    | `curl -fsSL <gist-url> \| bash -s -- --verbose` | `--verbose` forwarded via `"$@"` to `bootstrap.sh`; verbose output blocks appear in terminal           |
| K7 | `git clone` fails (no network or permission error)     | Invocation with no local repo                   | `set -euo pipefail` aborts; `bootstrap.sh` is never called                                             |

---

## Group L — `setup-windows.ps1`: interactive loops (PowerShell — Windows side)

**Context:** `setup-windows.ps1` contains two `Read-Host` loops for SSH key capture. Previously the Gist invoked this script with `-NonInteractive`, which caused `Read-Host` to throw before the user could respond. Fix applied: `-NonInteractive` removed from `linux-init-phase1-windows-prereqs.ps1`.

**Location:** `setup-windows.ps1:148–161` (retry loop), `setup-windows.ps1:204–219` (selection loop)

**Execute on:** Windows (PowerShell), not WSL. **Run:** 3 only.

### L1–L4: Retry loop (0 keys found, `$maxRetries = 3`)

| ID | Given                                        | When                                    | Then                                                                                                        |
| -- | -------------------------------------------- | --------------------------------------- | ----------------------------------------------------------------------------------------------------------- |
| L1 | 1Password agent has no keys, attempt < 3     | User enters `r` or `R` at `Read-Host`   | Loop continues; `Get-SshKeys` called again on next iteration                                                |
| L2 | 1Password agent has no keys, attempt < 3     | User enters anything other than `r`/`R` | Warning: "Skipping SSH key capture — run bootstrap.sh to retry interactively"; loop exits; script continues |
| L3 | 1Password agent has no keys                  | 3rd attempt exhausted with no key found | Loop exits without calling `Read-Host`; warning "SSH signing key not captured"; script continues            |
| L4 | 1Password agent returns a key on 2nd attempt | User enters `r` on 1st attempt          | Loop exits on success; key captured and written to state file                                               |

### L5–L8: Selection loop (N > 1 keys found)

| ID | Given                | When                                       | Then                                                                                                       |
| -- | -------------------- | ------------------------------------------ | ---------------------------------------------------------------------------------------------------------- |
| L5 | N > 1 keys available | User enters a valid number (1 to N)        | Corresponding key selected; `Write-StateKey` called; ok message displayed                                  |
| L6 | N > 1 keys available | User enters a number outside range         | Warning: "Invalid selection — enter a number between 1 and N, or C to cancel"; prompt shown again          |
| L7 | N > 1 keys available | User enters non-numeric text (not `c`/`C`) | Warning: "Invalid selection"; prompt shown again                                                           |
| L8 | N > 1 keys available | User enters `c` or `C`                     | Warning: "Cancelled — bootstrap.sh will prompt interactively"; `signing_key` not written; script continues |

### L9–L10: Phase 1 via Gist — interactive prompts work end-to-end

**Context:** Fix applied — `-NonInteractive` removed from the Gist invocation. The terminal stays interactive throughout, consistent with how Phase 2 and Phase 3 handle `read` via `/dev/tty`.

**Execute:** run Phase 1 via the Gist command from a normal PowerShell window (not elevated).

| ID  | Given                                                 | When                                | Then                                                                                     |
| --- | ----------------------------------------------------- | ----------------------------------- | ---------------------------------------------------------------------------------------- |
| L9  | Phase 1 invoked via Gist; 1Password agent has no keys | Script reaches the retry prompt     | `Read-Host` is displayed; user can enter `r` to retry or any other key to skip; no crash |
| L10 | Phase 1 invoked via Gist; N > 1 keys                  | Script reaches the selection prompt | `Read-Host` is displayed; user can enter a number or `c` to cancel; no crash             |

---

## Regression Checks

After executing any scenario above, verify the following invariants:

| Check                                                                        | How to verify                                                   |
| ---------------------------------------------------------------------------- | --------------------------------------------------------------- |
| Bootstrap log is written regardless of user choice                           | `tail -20 ~/.linux-init-bootstrap.log`                          |
| `_clean_install` abort leaves `~/Dev/tools` intact                           | `ls ~/Dev/tools` — directory must still exist                   |
| `_clean_tools` abort leaves tool state entries intact                        | `cat ~/.bootstrap-state` — module entries must still be present |
| `_reinstall` abort leaves `~/.bootstrap-state` intact                        | `cat ~/.bootstrap-state` — file must still exist                |
| Re-running `bootstrap.sh` after a cancelled clean resumes from correct state | Run `bash bootstrap.sh` — completed modules must be skipped     |
