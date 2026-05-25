# PLANNING — Tool confirmation prompts + uv migration

## 1. Context and motivation

Two related changes to improve the bootstrap UX and reduce installation time:

1. **Per-tool confirmation prompts** — each manager module installs its manager
   unconditionally, then asks the user whether to install each managed tool. This
   avoids installing Java or Python runtimes on machines that do not need them,
   while keeping the manager available for future use.

2. **Replace pyenv + Poetry with uv** — uv installs pre-compiled Python binaries
   (seconds, not minutes), manages virtual environments natively, and replaces both
   pyenv and Poetry. The compilation bottleneck in `03_python.sh` is eliminated.

---

## 2. Behaviour specification

### Manager install (always, no prompt)

Each module always installs its manager. Managers are lightweight and are the
foundation for later tool installs or manual use.

| Module         | Manager                     | Always installed |
| -------------- | --------------------------- | :--------------: |
| `03_python.sh` | uv                          | yes              |
| `04_java.sh`   | SDKman                      | yes              |
| `05_node.sh`   | NVM                         | yes              |
| `06_ai.sh`     | — (uses NVM + Node from 05) | —                |

### Tool confirmation (prompt only when not installed)

After the manager is ready, each tool is checked individually:

- **Already installed** → explicit `skip` message identifying the tool and version,
  followed by a hint: `To reinstall, run: bash bootstrap.sh --clean-tools`. No prompt.
- **Not installed** → prompt `Install <tool>? [Y/n]:`. Default is `Y`.
  - `Y` or Enter → install.
  - `n` → skip, record `skipped` in state so the next run prompts again.

### Module-level flow

#### 03_python.sh

```text
install uv (always)
if python lts not installed:
  prompt "Install Python LTS? [Y/n]"
  if confirmed: uv python install <lts-version>
```

#### 04_java.sh

```text
install SDKman (always)
if jdk not installed:
  prompt "Install JDK 25 (Zulu)? [Y/n]"
  if confirmed: sdk install java 25.0.3.fx-zulu
if maven not installed:
  prompt "Install Maven? [Y/n]"
  if confirmed: sdk install maven
if gradle not installed:
  prompt "Install Gradle? [Y/n]"
  if confirmed: sdk install gradle
```

#### 05_node.sh

```text
install NVM (always)
if node lts not installed:
  prompt "Install Node.js LTS? [Y/n]"
  if confirmed: nvm install --lts
```

#### 06_ai.sh

```text
if NVM not installed: install NVM
if Node.js LTS not installed: install Node.js LTS
if gh not found: warn "gh not found — run: bash bootstrap.sh --modules packages"
for each ai tool (claude, gemini):
  if not installed:
    prompt "Install <tool>? [Y/n]"
    if confirmed: install
  else: skip
always display Copilot post-install instructions:
  gh auth login
  gh extension install github/gh-copilot
  gh copilot --version
```

---

## 3. State tracking

Sub-states are added per tool. Manager state is unchanged.

### New state keys

```text
module_03_python_lts=complete|skipped
module_04_java_jdk=complete|skipped
module_04_java_maven=complete|skipped
module_04_java_gradle=complete|skipped
module_05_node_lts=complete|skipped
module_06_ai_claude=complete|skipped
module_06_ai_gemini=complete|skipped
```

### Skip behaviour

A tool with state `skipped` is prompted again on next run (same as absent).
A tool with state `complete` shows `skip` and is not prompted.

### `--clean-tools` impact

`_clean_tools` already removes `module_03` through `module_07` state entries.
The new sub-state keys follow the same prefix pattern and will be removed
automatically by the existing `sed` filter.

---

## 4. uv migration (`03_python.sh`)

### Removed

- `pyenv` installation and all related logic
- `pyenv-doctor`, `pyenv-update` plugins
- Python compilation via `pyenv install`
- `poetry` installation

### Added

- `uv` installation via `curl -LsSf https://astral.sh/uv/install.sh | sh`
- `uv python install` for Python LTS (pre-compiled binary, ~5 seconds)
- `uv` already present in current `03_python.sh` as last step — promoted to primary

### Python version strategy

- uv installs the latest CPython LTS automatically via `uv python install`
- Version pinning uses `uv python pin` (writes `.python-version`, compatible with pyenv tooling)

### Module header update

```bash
# 03_python.sh
# Python environment: uv (package manager + Python installer).
```

---

## 5. Prompt helper

A shared `_confirm` helper is added to `lib/output.sh`:

```bash
# Returns 0 if user confirms (Y/Enter), 1 if user declines (n)
# Skips prompt and returns 0 if stdin is not a TTY (non-interactive mode)
_confirm() {
  local prompt="$1"
  if [[ ! -t 0 ]]; then return 0; fi
  printf "  %s [Y/n]: " "$prompt"
  local reply
  read -r reply </dev/tty
  [[ -z "$reply" || "$reply" =~ ^[Yy] ]]
}
```

---

## 6. `--modules` interaction

The `--modules` flag skips entire modules. Confirmation prompts are orthogonal:
they operate within a module that is already running. A user who wants to run
only the manager without any tools would answer `n` to all prompts within that
module.

No changes to `--modules` parsing or `_run_module` are required.

---

## 7. Non-interactive mode

When `bootstrap.sh` is invoked via `curl | bash` (stdin is a pipe, not a TTY),
`_confirm` detects the absence of a TTY and defaults to `Y` — preserving the
current fully-automatic behaviour for unattended installs.

---

## 8. Files to change

| File                   | Change                                                                     |
| ---------------------- | -------------------------------------------------------------------------- |
| `lib/output.sh`        | Add `_confirm` helper                                                      |
| `install/03_python.sh` | Replace pyenv+Poetry with uv; add Python LTS prompt                        |
| `install/04_java.sh`   | Add per-tool prompts for JDK, Maven, Gradle                                |
| `install/05_node.sh`   | Add Node.js LTS prompt                                                     |
| `install/06_ai.sh`     | Add NVM/Node guard; add per-tool prompts; always show Copilot instructions |
| `lib/state.sh`         | No changes — sub-state keys work with existing `state_set`/`state_get`     |
| `lib/clean.sh`         | No changes — existing prefix filter covers new sub-state keys              |
| `README.md`            | Document module dependencies and new prompt behaviour                      |
| `docs/USAGE.md`        | Document prompt behaviour, non-interactive mode, `--modules` interaction   |

---

## 9. Out of scope

- Changes to `--modules` flag parsing
- Changes to `lib/clean.sh` destructive operations
- Changes to `00_packages.sh`, `01_shell.sh`, `02_chezmoi.sh`, `07_containers.sh`
- Copilot installation (instructions only, no automation)
