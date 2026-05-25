# Test Plan — Input Confirmation Loops and Gist Entry Points

Manual test plan for the user input confirmation loops in `install/00_packages.sh`, `lib/dotfiles.sh`, and `lib/clean.sh`, and for the Gist entry point scripts (`gist/`).

Each scenario follows the **Given / When / Then** structure. Unless noted otherwise, execute inside WSL2.

---

## Execution Sequence

Tests are executed in five ordered runs. Each run has a fixed environment and scope.

| Run | Environment                  | Distro  | Scope                                                                     |
| --- | ---------------------------- | ------- | ------------------------------------------------------------------------- |
| 1   | Create Ubuntu WSL2 image     | Ubuntu  | Provisioning only — no test execution                                     |
| 2   | Create Fedora WSL2 image     | Fedora  | Provisioning only — no test execution                                     |
| 3   | Ubuntu — first execution     | Ubuntu  | All phases fresh: Phase 1 (Windows) + Phase 2 + Phase 3; Groups A–E, K, L |
| 4   | Ubuntu — second execution    | Ubuntu  | State from Run 3 intact; idempotency + clean flags; Groups C, D, E        |
| 5   | Fedora — first execution     | Fedora  | All phases fresh: Phase 2 + Phase 3; Groups A–E, K                        |

**Phase 1 (Windows side) runs once** — it is platform-independent and executed during Run 3 only.

---

## Run 1 — Create Ubuntu WSL2 image

```powershell
wsl --install Ubuntu-26.04 --web-download --name Ubuntu-26-feature-polish-design
# Follow the distro first-run prompts to create a user and password.
# When complete, verify:
wsl -d Ubuntu-26-feature-polish-design -- bash -c "lsb_release -a && echo OK"
```

Expected: Ubuntu version info printed, `OK` on the last line.

---

## Run 2 — Create Fedora WSL2 image

```powershell
wsl --install FedoraLinux-44 --web-download --name Fedora-44-feature-polish-design
# Follow the distro first-run prompts to create a user and password.
```

Inside the Fedora session, set the user password and enable systemd (required for Windows interop):

```bash
sudo passwd nonatorw

sudo bash -c 'cat > /etc/wsl.conf << EOF
[boot]
systemd=true
EOF'
```

Then restart the instance from PowerShell to activate systemd:

```powershell
wsl --shutdown
wsl -d Fedora-44-feature-polish-design
```

Verify:

```bash
wsl -d Fedora-44-feature-polish-design -- bash -c "cat /etc/fedora-release && echo OK"
```

Expected: Fedora release string printed, `OK` on the last line.

> **Why systemd is required:** Fedora WSL2 does not enable systemd by default. Without it, the Windows interop layer does not activate correctly, which means `powershell.exe` and `ssh-add.exe` are not reachable from within WSL2. The bootstrap relies on `ssh-add.exe` to read SSH keys from the 1Password agent for dotfile signing key resolution.

---

## Run 3 — Ubuntu: first execution (all phases, fresh)

### Run 3 pre-conditions

- Ubuntu WSL2 distro created in Run 1 (name used below: `Ubuntu-26-test`)
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

### Step 2 — Phase 2 (invoked from PowerShell via wsl)

```powershell
wsl -d Ubuntu-26-test -- bash -c "
  curl -fsSL https://gist.githubusercontent.com/nonatorw/79321dfef85099cdbad1d2f0fda5f959/raw/linux-init-phase2-linux-prereqs.sh | bash
"
```

**Scenarios covered:** K1, K2 (network failure must be simulated separately)

### Step 3 — Phase 3 (interactive WSL session)

Phase 3 triggers interactive prompts (Groups A, B, C, D, E) that require a TTY. Open an
interactive WSL session and run the bootstrap directly:

```powershell
wsl -d Ubuntu-26-test
```

```bash
# Inside WSL:
curl -fsSL https://gist.githubusercontent.com/nonatorw/79321dfef85099cdbad1d2f0fda5f959/raw/linux-init-phase3-bootstrap.sh | bash
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
wsl -d Ubuntu-26-test
```

Execute in the order below inside WSL. Each step depends on state left by the previous one.
`--clean-install` is last because it destroys `~/Dev/tools`, `~/.bootstrap-state`, and dotfiles,
leaving the environment unrecoverable for further tests.

```bash
# 1. Idempotency — bootstrap skips completed modules (K3, K5)
bash ~/Dev/repos/linux-init-bootstrap/bootstrap.sh

# 2. Abort confirmations — enter 'n' at each prompt; verify nothing is removed (C3, C4, C7, C9, E2)
bash ~/Dev/repos/linux-init-bootstrap/bootstrap.sh --clean-tools
bash ~/Dev/repos/linux-init-bootstrap/bootstrap.sh --reinstall

# 3. Single-prompt regression — enter 'y'; count prompts (E1)
bash ~/Dev/repos/linux-init-bootstrap/bootstrap.sh --reinstall

# 4. stdin isolation — invoke via pipe, enter 'y' and 'n' at terminal (D1–D5)
bash ~/Dev/repos/linux-init-bootstrap/bootstrap.sh --clean-tools
curl -fsSL <gist-phase3-url> | bash -s -- --clean-tools

# 5. clean-install — enter 'y'; destroys environment; must be last (C1, C2)
bash ~/Dev/repos/linux-init-bootstrap/bootstrap.sh --clean-install
```

---

## Run 5 — Fedora: first execution (fresh)

### Run 5 pre-conditions

- Fedora WSL2 distro created in Run 2 (name used below: `Fedora-44-test`)
- No bootstrap state file
- Phase 1 already executed in Run 3 (Windows side does not repeat)
- 1Password SSH agent active (same Windows setup)

### Step 1 — Phase 2 (invoked from PowerShell via wsl)

```powershell
wsl -d Fedora-44-test -- bash -c "
  curl -fsSL https://gist.githubusercontent.com/nonatorw/79321dfef85099cdbad1d2f0fda5f959/raw/linux-init-phase2-linux-prereqs.sh | bash
"
```

**Scenarios covered:** K1 (Fedora / dnf path)

### Step 2 — Phase 3 (interactive WSL session)

```powershell
wsl -d Fedora-44-test
```

```bash
# Inside WSL:
curl -fsSL https://gist.githubusercontent.com/nonatorw/79321dfef85099cdbad1d2f0fda5f959/raw/linux-init-phase3-bootstrap.sh | bash
```

**Scenarios covered:** K4, D3, D4, A1–A6, B1–B9, C1–C9

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

| ID | Given                                  | When                                                    | Then                                                                                                        |
| -- | -------------------------------------- | ------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------- |
| B1 | 1Password SSH agent has no keys loaded | User enters `r`                                         | Loop continues; `ssh-add -L` is called again; no error message about invalid input                          |
| B2 | 1Password SSH agent has no keys loaded | User enters `R`                                         | Same as B1                                                                                                  |
| B3 | 1Password SSH agent has no keys loaded | User enters `c`                                         | Warning: `Cancelled by user — dotfiles not applied`; function returns 1; bootstrap continues with a warning |
| B4 | 1Password SSH agent has no keys loaded | User enters `C`                                         | Same as B3                                                                                                  |
| B5 | 1Password SSH agent has no keys loaded | User enters any other input (e.g. `x`, empty Enter)     | Warning: `Invalid choice — enter R to retry or C to cancel.`; prompt is shown again                         |
| B6 | 1Password SSH agent has exactly 1 key  | — (no prompt shown)                                     | Key is selected automatically; message: `SSH signing key detected automatically`; proceeds to chezmoi       |
| B7 | 1Password SSH agent has N > 1 keys     | User enters a valid number (1 to N)                     | Corresponding key is selected; message: `SSH signing key selected`; proceeds to chezmoi                     |
| B8 | 1Password SSH agent has N > 1 keys     | User enters a number outside range or non-numeric input | Warning: `Invalid selection — enter a number between 1 and N, or C to cancel`; prompt is shown again        |
| B9 | 1Password SSH agent has N > 1 keys     | User enters `c` or `C`                                  | Warning: `Cancelled by user — dotfiles not applied`; function returns 1                                     |

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

**Runs:** 3 (D3–D4 via Gist), 4 (D1–D2 direct, D5 CI simulation)

| ID | Given                                                                        | When                                          | Then                                                                       |
| -- | ---------------------------------------------------------------------------- | --------------------------------------------- | -------------------------------------------------------------------------- |
| D1 | Script invoked directly: `bash bootstrap.sh --clean-tools`                   | User enters `y` at the prompt                 | Confirmation is read correctly; clean executes                             |
| D2 | Script invoked directly: `bash bootstrap.sh --clean-tools`                   | User enters `n` at the prompt                 | Abort message shown; nothing removed                                       |
| D3 | Script invoked via pipe: `curl -fsSL ... \| bash -s -- --clean-tools`        | User enters `y` at the prompt in the terminal | Confirmation is read from `/dev/tty`; clean executes despite pipe on stdin |
| D4 | Script invoked via pipe: `curl -fsSL ... \| bash -s -- --clean-tools`        | User enters `n` at the prompt                 | Abort message shown; nothing removed                                       |
| D5 | Script invoked via pipe with no terminal (e.g. CI): `/dev/tty` not available | Prompt is reached                             | Script aborts gracefully (read returns empty → treated as `N`)             |

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
