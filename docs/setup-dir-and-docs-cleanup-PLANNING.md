# PLANNING — Restructure setup scripts and documentation

## 1. Context and motivation

The project entry-point scripts live at the repository root without a clear naming
convention. This makes the directory noisy and the relationship between phases implicit.
This feature reorganises them into a `setup/` subdirectory with explicit phase prefixes,
renames test-only Gist variants to a consistent `linux-init-local-phase*` pattern, updates
all Gist entry points to reference the new paths, and brings every documentation file up to
date. An archived subfolder removes stale per-feature planning docs from the main `docs/`
tree.

---

## 2. Changes in scope

### 2.1 Script renames — root → `setup/`

| Current path              | New path                               |
| ------------------------- | -------------------------------------- |
| `setup-windows.ps1`       | `setup/phase1-setup-windows.ps1`       |
| `setup-windows-admin.ps1` | `setup/phase1-setup-windows-admin.ps1` |
| `setup-prereqs-linux.sh`  | `setup/phase2-setup-prereqs-linux.sh`  |
| `bootstrap.sh`            | `setup/phase3-setup-bootstrap.sh`      |

All four files move via `git mv` to preserve history.

### 2.2 Gist local-variant renames — `gist/`

| Current path                                       | New path                                           |
| -------------------------------------------------- | -------------------------------------------------- |
| `gist/linux-init-phase1-windows-prereqs.local.ps1` | `gist/linux-init-local-phase1-windows-prereqs.ps1` |
| `gist/linux-init-phase2-linux-prereqs.local.sh`    | `gist/linux-init-local-phase2-linux-prereqs.sh`    |
| `gist/linux-init-phase3-bootstrap.local.sh`        | `gist/linux-init-local-phase3-linux-bootstrap.sh`  |

All three files move via `git mv`.

### 2.3 Internal reference updates

After the moves, every hard-coded path reference must be updated:

| File                                               | Reference to update                                                                                  |
| -------------------------------------------------- | ---------------------------------------------------------------------------------------------------- |
| `setup/phase3-setup-bootstrap.sh`                  | `local_ps_script` path (`setup-windows.ps1` → `setup/phase1-setup-windows.ps1`)                      |
| `gist/linux-init-local-phase1-windows-prereqs.ps1` | `Copy-Item` source paths for both PS1 scripts                                                        |
| `gist/linux-init-local-phase2-linux-prereqs.sh`    | `bash "$REPO_ROOT/setup-prereqs-linux.sh"` → `bash "$REPO_ROOT/setup/phase2-setup-prereqs-linux.sh"` |
| `gist/linux-init-local-phase3-linux-bootstrap.sh`  | `bash "$REPO_ROOT/bootstrap.sh"` → `bash "$REPO_ROOT/setup/phase3-setup-bootstrap.sh"`               |
| `gist/linux-init-phase1-windows-prereqs.ps1`       | `Invoke-WebRequest` URL for `setup-windows.ps1` and `setup-windows-admin.ps1`                        |
| `gist/linux-init-phase2-linux-prereqs.sh`          | `curl` URL for `setup-prereqs-linux.sh`                                                              |
| `gist/linux-init-phase3-bootstrap.sh`              | `bash "$DEST/bootstrap.sh"` → `bash "$DEST/setup/phase3-setup-bootstrap.sh"`                         |
| `setup/phase2-setup-prereqs-linux.sh`              | Header comment: `bash bootstrap.sh` → `bash setup/phase3-setup-bootstrap.sh`                         |
| `setup/phase1-setup-windows-admin.ps1`             | Trailing instructions that reference `setup-windows.ps1` and `bootstrap.sh`                          |

### 2.4 Gist remote update

The three public Gist files must be updated to reference the new `setup/` paths on GitHub raw:

- `linux-init-phase1-windows-prereqs.ps1` — download URLs: `setup/phase1-setup-windows.ps1` and `setup/phase1-setup-windows-admin.ps1`
- `linux-init-phase2-linux-prereqs.sh` — download URL: `setup/phase2-setup-prereqs-linux.sh`
- `linux-init-phase3-bootstrap.sh` — clone then call `setup/phase3-setup-bootstrap.sh`

### 2.5 Documentation archive

Move stale per-feature planning docs out of the main `docs/` tree:

| Current path                                       | New path                                                    |
| -------------------------------------------------- | ----------------------------------------------------------- |
| `docs/tool-confirmation-uv-migration-PLANNING.md`  | `docs/archived/tool-confirmation-uv-migration-PLANNING.md`  |
| `docs/tool-confirmation-uv-migration-TEST_PLAN.md` | `docs/archived/tool-confirmation-uv-migration-TEST_PLAN.md` |

### 2.6 `.gitattributes`

Add the existing root-level `.gitattributes` (already correct, untracked) to the repository.

### 2.7 Documentation review and update

Every user-facing document must reflect the new paths and be accurate end-to-end:

| File                           | Changes required                                                                                                                                                      |
| ------------------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `README.md`                    | Update all script references to `setup/phase*.sh\|ps1`; update Quick Start commands; update Flags table if needed                                                     |
| `docs/SETUP.md`                | Update all script references; fix `03_python.sh` description (was "pyenv + Poetry + uv", now "uv only"); replace local clone paths with Gist commands as primary flow |
| `docs/USAGE.md`                | Update any script references; ensure non-interactive mode section is accurate                                                                                         |
| `gist/linux-init-bootstrap.md` | Update phase table and Quick Start commands                                                                                                                           |

---

## 3. Constraints and invariants

- **No behaviour change.** All scripts perform the same operations as before; only file locations and internal references change.
- **`git mv` for all moves.** History must be preserved on every renamed file.
- **Gist remote must match repo.** After merge, the three public Gist files must be updated manually (GitHub web UI or `gh gist edit`) to match the new content — documented as a post-merge step.
- **Local Gist variants must remain non-publishable.** The `linux-init-local-*` files are for local validation only. They must retain the "do not publish" header comment.
- **`BOOTSTRAP_DIR` in `phase3-setup-bootstrap.sh`.** The script computes its own directory via `$(dirname "${BASH_SOURCE[0]}")`. After moving to `setup/`, `BOOTSTRAP_DIR` will be `<repo>/setup`. The reference to `setup-windows.ps1` must change to `$BOOTSTRAP_DIR/../setup/phase1-setup-windows.ps1` — or, more simply, `$(cd "$BOOTSTRAP_DIR/.." && pwd)/setup/phase1-setup-windows.ps1`. In practice, since the script is now inside `setup/`, the sibling reference becomes `$BOOTSTRAP_DIR/phase1-setup-windows.ps1`.
- **`lib/`, `install/` paths in `phase3-setup-bootstrap.sh`.** These are sourced as `$BOOTSTRAP_DIR/lib/...` and `$BOOTSTRAP_DIR/install/...`. After moving to `setup/`, `BOOTSTRAP_DIR` points to `setup/` but `lib/` and `install/` remain at the repo root. All `source` calls must change to `$BOOTSTRAP_DIR/../lib/...` and `$BOOTSTRAP_DIR/../install/...`. The cleanest fix is to define a `REPO_ROOT="$(cd "$BOOTSTRAP_DIR/.." && pwd)"` variable and use it for all root-relative paths.

---

## 4. Files to change

| File                                               | Type of change                                                                         |
| -------------------------------------------------- | -------------------------------------------------------------------------------------- |
| `setup-windows.ps1`                                | Move → `setup/phase1-setup-windows.ps1`                                                |
| `setup-windows-admin.ps1`                          | Move → `setup/phase1-setup-windows-admin.ps1`; update trailing instructions            |
| `setup-prereqs-linux.sh`                           | Move → `setup/phase2-setup-prereqs-linux.sh`; update header comment                    |
| `bootstrap.sh`                                     | Move → `setup/phase3-setup-bootstrap.sh`; add `REPO_ROOT`; fix all root-relative paths |
| `gist/linux-init-phase1-windows-prereqs.local.ps1` | Move + rename; update `Copy-Item` source paths; add `-LogDest` param to copy win log   |
| `gist/linux-init-phase2-linux-prereqs.local.sh`    | Move + rename; update `bash` call                                                      |
| `gist/linux-init-phase3-bootstrap.local.sh`        | Move + rename; update `bash` call                                                      |
| `gist/linux-init-phase1-windows-prereqs.ps1`       | Update download URLs                                                                   |
| `gist/linux-init-phase2-linux-prereqs.sh`          | Update download URL                                                                    |
| `gist/linux-init-phase3-bootstrap.sh`              | Update `bash` call to `setup/phase3-setup-bootstrap.sh`                                |
| `gist/linux-init-bootstrap.md`                     | Update phase table and Quick Start                                                     |
| `README.md`                                        | Update all script references and Quick Start                                           |
| `docs/SETUP.md`                                    | Update all script references; fix module table                                         |
| `docs/USAGE.md`                                    | Update any script references                                                           |
| `docs/TEST_PLAN.md`                                | Replace with full regression test plan (see TEST_PLAN doc)                             |
| `.gitattributes`                                   | Add to repository (already correct, currently untracked)                               |
| `docs/tool-confirmation-uv-migration-PLANNING.md`  | Move → `docs/archived/`                                                                |
| `docs/tool-confirmation-uv-migration-TEST_PLAN.md` | Move → `docs/archived/`                                                                |

---

## 5. Behaviour fix — `phase_windows` state guard

`phase3-setup-bootstrap.sh` previously invoked `phase1-setup-windows.ps1` unconditionally
on every run in WSL2. This caused the SSH signing-key capture logic to execute on each run,
even when the key had already been captured and stored in the state file.

**Fix (part 1 — guard):** wrap the PS1 invocation in a `phase_windows` state check. If
`phase_windows=complete`, the PS1 is skipped and a `skip` message is printed. When the PS1
completes without error, `state_set "phase_windows" "complete"` is written.

**Fix (part 2 — signing_key normalisation):** after the PS1 returns successfully, the bootstrap
reads `signing_key` back from the state file via `state_get` and immediately re-writes it via
`state_set`. This normalises the line endings to Linux-native `\n`, working around a WSL2
9P-protocol filesystem-cache issue: `WriteAllLines` from PowerShell writes with `\r\n` line
endings, and those bytes may not be immediately visible to the Linux kernel (or may be present
with embedded `\r` that survives `sed -i` rewrites). The read-back-and-rewrite ensures
`state_get "signing_key"` in `_resolve_signing_key` finds the value and skips the interactive
prompt during the dotfiles section.

**Impact on `--clean-tools`:** `_do_clean_tools` removes `module_03`–`module_07` prefixes only.
`phase_windows` is intentionally **not** cleared by `--clean-tools` — the Windows prerequisites
remain valid after tool removal.

**Impact on `--reinstall`:** `_reinstall` removes the entire state file, so `phase_windows`
is cleared and the PS1 runs again on the next bootstrap run.

**Files changed:** `setup/phase3-setup-bootstrap.sh` only.

---

## 6. Out of scope

- Changes to `lib/`, `install/`, or any runtime behaviour beyond section 5
- Changes to state file format or keys
- Changes to Gist URL (same Gist ID, files are updated in place)
- New features or module additions
