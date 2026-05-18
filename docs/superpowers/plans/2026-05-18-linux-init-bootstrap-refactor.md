# linux-init-bootstrap: Refactor from nonatorw-dotfiles Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Transform `nonatorw-dotfiles` into `linux-init-bootstrap` — a minimal, focused bootstrap that installs dev tools and chezmoi, then delegates all dotfile management to `chezmoi-dotfiles`. Removes all files that are now owned by `chezmoi-dotfiles`.

**Architecture:** The bootstrap installs tools via distro-agnostic scripts (pyenv/sdkman/nvm/npm via curl/git) plus `lib/platform.sh` for the two distro-specific scripts (`00_packages.sh`, `07_containers.sh`). It installs chezmoi as the last step and prints instructions for the user to run `chezmoi init`. All dotfile management (`local-bin/`, `link.sh`, `git/`, `claude/`, `java/`) is removed — those are owned by `chezmoi-dotfiles`.

**Tech Stack:** bash, lib/platform.sh (apt/dnf/brew abstraction), chezmoi

---

## Context

### Dependency: chezmoi-dotfiles plan must be completed first

Before executing this plan, the `chezmoi-dotfiles` plan (`2026-05-18-uv-support-and-sync.md`) must be applied and pushed. This bootstrap's `local-bin/` files will be deleted — chezmoi-dotfiles must be the verified source of truth before deletion.

### What this repo becomes

```text
linux-init-bootstrap/
├── bootstrap.sh          ← orchestrator (no --reinstall, no link.sh call)
├── lib/
│   └── platform.sh       ← unchanged: detects PLATFORM + PKG_MANAGER
└── install/
    ├── 00_packages.sh    ← unchanged
    ├── 01_shell.sh       ← remove zsh-z plugin (kept zsh-z, drop duplicate z)
    ├── 02_chezmoi.sh     ← NEW: installs chezmoi via PKG_MANAGER
    ├── 03_python.sh      ← add _install_uv(); renamed from 02_python.sh
    ├── 04_java.sh        ← fix sdk install java (no version pin); renamed from 03
    ├── 05_node.sh        ← unchanged; renamed from 04
    ├── 06_ai.sh          ← fix _init_gemini_dir path; renamed from 05
    └── 07_containers.sh  ← unchanged; renamed from 06
```

### What gets deleted

- `link.sh` — chezmoi owns all symlinking
- `local-bin/` — entire directory; owned by `chezmoi-dotfiles`
- `git/` — `.gitconfig` owned by `chezmoi-dotfiles/dot_gitconfig.tmpl`
- `claude/` — `CLAUDE.md` owned by `chezmoi-dotfiles/CLAUDE.md.tmpl`
- `java/settings.xml` — owned by `chezmoi-dotfiles/dot_m2/settings.xml`
- `zsh/` — `.zshrc` and `.p10k.zsh` owned by `chezmoi-dotfiles`
- `plan-refactoring-nonatorw-dotfiles.md` — superseded by this plan

### What stays

- `lib/platform.sh` — bootstrap owns platform detection
- `install/` — all install scripts (refactored as above)
- `bootstrap.sh` — refactored orchestrator

---

## File Map

| File                                    | Action                                                                                                                               |
| --------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------ |
| `bootstrap.sh`                          | **Modify**: remove ALL flags (`--install`, `--link`, `--reinstall`), remove `link.sh` call, update module list, update final message |
| `install/01_shell.sh`                   | **Modify**: remove `z` plugin (keep `zsh-z`); add `GIT_CONFIG_NOSYSTEM=1 HOME=/tmp` to all `git clone` calls                         |
| `install/02_chezmoi.sh`                 | **Create**: installs chezmoi via `pkg_install`                                                                                       |
| `install/02_python.sh`                  | **Rename** → `install/03_python.sh`; add `_install_uv()`; add `GIT_CONFIG_NOSYSTEM=1 HOME=/tmp` to pyenv clone                       |
| `install/03_java.sh`                    | **Rename** → `install/04_java.sh`; fix `sdk install java` (no version pin)                                                           |
| `install/04_node.sh`                    | **Rename** → `install/05_node.sh`; add `GIT_CONFIG_NOSYSTEM=1 HOME=/tmp` to NVM clone                                                |
| `install/05_ai.sh`                      | **Rename** → `install/06_ai.sh`; fix `_init_gemini_dir` path                                                                         |
| `install/06_containers.sh`              | **Rename** → `install/07_containers.sh` (no content changes)                                                                         |
| `link.sh`                               | **Delete**                                                                                                                           |
| `local-bin/`                            | **Delete** entire directory                                                                                                          |
| `git/`                                  | **Delete** entire directory                                                                                                          |
| `claude/`                               | **Delete** entire directory                                                                                                          |
| `java/`                                 | **Delete** entire directory                                                                                                          |
| `zsh/`                                  | **Delete** entire directory (after bootstrap confirmed working)                                                                      |
| `plan-refactoring-nonatorw-dotfiles.md` | **Delete** (superseded)                                                                                                              |

---

## Task 1: Fix `install/01_shell.sh` — remove `z` plugin and harden `git clone` calls

**Files:**

- Modify: `install/01_shell.sh`

**Background on `GIT_CONFIG_NOSYSTEM`:** When `~/.gitconfig` has `commit.gpgsign = true` (1Password SSH signing), every `git clone` attempts to verify the signing program. On WSL with 1Password configured, this can fail when running from a shell where the SSH agent socket is not yet available (e.g., during a fresh bootstrap). `GIT_CONFIG_NOSYSTEM=1 HOME=/tmp` bypasses all user and system git config for the clone, exactly as `bluefin-template` already does.

- [ ] **Step 1: Remove `z` from the plugins map**

The `declare -A plugins` in `_install_zsh_plugins()` contains `["zsh-z"]` — this is correct and should stay. There is no `z` entry in this map (the duplicate was only in `zsh/.zshrc`). No change needed here for the plugin map itself.

- [ ] **Step 2: Add `GIT_CONFIG_NOSYSTEM=1 HOME=/tmp` to all `git clone` calls**

In `_install_p10k()`, change:

```bash
git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$p10k_dir"
```

To:

```bash
GIT_CONFIG_NOSYSTEM=1 HOME=/tmp git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$p10k_dir"
```

In `_install_zsh_plugins()`, change:

```bash
git clone --depth=1 "${plugins[$plugin]}" "$plugin_dir"
```

To:

```bash
GIT_CONFIG_NOSYSTEM=1 HOME=/tmp git clone --depth=1 "${plugins[$plugin]}" "$plugin_dir"
```

- [ ] **Step 3: Verify syntax**

```bash
bash -n install/01_shell.sh
```

- [ ] **Step 4: Commit**

```bash
git add install/01_shell.sh
git commit -m "fix: harden git clones in 01_shell.sh with GIT_CONFIG_NOSYSTEM=1"
```

---

## Task 2: Create `install/02_chezmoi.sh`

**Files:**

- Create: `install/02_chezmoi.sh`
- [ ] **Step 1: Create the file**

```bash
#!/usr/bin/env bash
# ============================================================
# 02_chezmoi.sh — chezmoi (dotfiles manager)
# ============================================================

install_chezmoi() {
  if has chezmoi; then
    echo "[chezmoi] chezmoi already installed: $(chezmoi --version)"
    return 0
  fi
  echo "[chezmoi] Installing chezmoi..."
  pkg_install chezmoi
  echo "[chezmoi] chezmoi: $(chezmoi --version)"
}
```

- [ ] **Step 2: Make executable and verify syntax**

```bash
chmod +x install/02_chezmoi.sh
bash -n install/02_chezmoi.sh
```

Expected: no output (no syntax errors).

- [ ] **Step 3: Commit**

```bash
git add install/02_chezmoi.sh
git commit -m "feat: add chezmoi install module (02_chezmoi.sh)"
```

---

## Task 3: Rename and fix `install/02_python.sh` → `install/03_python.sh`

**Files:**

- Rename: `install/02_python.sh` → `install/03_python.sh`
- Modify: add `_install_uv()`, harden pyenv `git clone`

- [ ] **Step 1: Rename the file**

```bash
git mv install/02_python.sh install/03_python.sh
```

- [ ] **Step 2: Add `GIT_CONFIG_NOSYSTEM=1 HOME=/tmp` to the pyenv clone**

In `_install_pyenv()`, change:

```bash
git clone https://github.com/pyenv/pyenv.git "$PYENV_ROOT"
```

To:

```bash
GIT_CONFIG_NOSYSTEM=1 HOME=/tmp git clone https://github.com/pyenv/pyenv.git "$PYENV_ROOT"
```

- [ ] **Step 3: Add `_install_uv()` function**

Add after `_install_poetry()` and before the end of the file:

```bash
_install_uv() {
  if has uv; then
    echo "[python] uv already installed: $(uv --version)"
    return 0
  fi
  echo "[python] Installing uv..."
  curl -LsSf https://astral.sh/uv/install.sh | sh
  echo "[python] uv: $(~/.local/bin/uv --version)"
}
```

Add `_install_uv` call to `install_python()`:

```bash
install_python() {
  echo "[python] Configuring Python environment..."
  _install_pyenv
  _install_python_version
  _install_poetry
  _install_uv
}
```

- [ ] **Step 4: Verify syntax**

```bash
bash -n install/03_python.sh
```

- [ ] **Step 5: Commit**

```bash
git add install/03_python.sh
git commit -m "feat: rename 02_python→03_python, add UV installer, harden pyenv git clone"
```

---

## Task 4: Rename and fix `install/03_java.sh` → `install/04_java.sh`

**Files:**

- Rename: `install/03_java.sh` → `install/04_java.sh`
- Modify: update version pin to `25.0.3.fx-zulu`; fix header comment (Temurin → Zulu)

- [ ] **Step 1: Rename**

```bash
git mv install/03_java.sh install/04_java.sh
```

- [ ] **Step 2: Fix header comment and `_install_java_lts()` version**

File header (line 3):

```bash
# 04_java.sh — SDKman + Java LTS (Zulu 25.0.3.fx) + Maven + Gradle
```

In `_install_java_lts()` (line ~79–80):

```bash
  echo "[java] Installing Java LTS (Zulu 25.0.3.fx via SDKman)..."
  sdk install java 25.0.3.fx-zulu
```

- [ ] **Step 3: Verify syntax**

```bash
bash -n install/04_java.sh
```

- [ ] **Step 4: Commit**

```bash
git add install/04_java.sh
git commit -m "fix: rename 03_java→04_java, update to Zulu 25.0.3.fx, fix header comment"
```

---

## Task 5: Rename and fix `install/04_node.sh` → `install/05_node.sh`

**Files:**

- Rename: `install/04_node.sh` → `install/05_node.sh`
- Modify: harden NVM `git clone` with `GIT_CONFIG_NOSYSTEM=1 HOME=/tmp`; remove `$DO_REINSTALL` reference

- [ ] **Step 1: Rename**

```bash
git mv install/04_node.sh install/05_node.sh
```

- [ ] **Step 2: Add `GIT_CONFIG_NOSYSTEM=1 HOME=/tmp` to the NVM clone**

In `_install_nvm()`, change:

```bash
    git clone --depth=1 --branch "$latest" https://github.com/nvm-sh/nvm.git "$NVM_DIR"
```

To:

```bash
    GIT_CONFIG_NOSYSTEM=1 HOME=/tmp git clone --depth=1 --branch "$latest" https://github.com/nvm-sh/nvm.git "$NVM_DIR"
```

- [ ] **Step 3: Remove dead `$DO_REINSTALL` reference from `install_node()`**

The `install_node()` function currently has:

```bash
  if $DO_REINSTALL && [[ "${REINSTALL_NODE:-false}" == "false" ]]; then
    echo "[node] NVM kept — skipping Node.js install"
    return 0
  fi
```

Remove that entire `if` block. The simplified function becomes:

```bash
install_node() {
  echo "[node] Configuring Node.js environment..."
  _install_nvm
  _install_node_lts
}
```

- [ ] **Step 4: Verify syntax**

```bash
bash -n install/05_node.sh
```

- [ ] **Step 5: Commit**

```bash
git add install/05_node.sh
git commit -m "fix: rename 04_node→05_node, harden NVM git clone, remove DO_REINSTALL ref"
```

---

## Task 6: Rename and fix `install/05_ai.sh` → `install/06_ai.sh`

**Files:**

- Rename: `install/05_ai.sh` → `install/06_ai.sh`
- Modify: fix `_init_gemini_dir` to write to `gemini-config/` dir, not `~/.gemini`

- [ ] **Step 1: Rename**

```bash
git mv install/05_ai.sh install/06_ai.sh
```

- [ ] **Step 2: Fix `_init_gemini_dir()`**

Current:

```bash
_init_gemini_dir() {
  mkdir -p "$HOME/.gemini"
  if [[ ! -f "$HOME/.gemini/projects.json" ]]; then
    echo '{"projects":[]}' > "$HOME/.gemini/projects.json"
  fi
}
```

Replace with:

```bash
_init_gemini_dir() {
  local gemini_config_dir="$HOME/Dev/tools/ai/gemini-config"
  mkdir -p "$gemini_config_dir"
  if [[ ! -f "$gemini_config_dir/projects.json" ]]; then
    echo '{"projects":[]}' > "$gemini_config_dir/projects.json"
  fi
}
```

The symlink `~/.gemini → ~/Dev/tools/ai/gemini-config` is created by `chezmoi apply`, not here.

- [ ] **Step 3: Verify syntax**

```bash
bash -n install/06_ai.sh
```

- [ ] **Step 4: Commit**

```bash
git add install/06_ai.sh
git commit -m "fix: rename 05_ai→06_ai, init gemini-config dir (not ~/.gemini)"
```

---

## Task 7: Rename `install/06_containers.sh` → `install/07_containers.sh`

**Files:**

- Rename: `install/06_containers.sh` → `install/07_containers.sh`

- [ ] **Step 1: Rename**

```bash
git mv install/06_containers.sh install/07_containers.sh
```

- [ ] **Step 2: Commit**

```bash
git add install/07_containers.sh
git commit -m "refactor: rename 06_containers→07_containers (sequence adjustment)"
```

---

## Task 8: Refactor `bootstrap.sh`

**Files:**

- Modify: `bootstrap.sh`

- [ ] **Step 1: Remove ALL flags and related functions**

The new `bootstrap.sh` only installs tools — no linking (chezmoi does it), no reinstall, no install-only mode. All three flags lose their purpose. Remove entirely:

- `DO_INSTALL`, `DO_LINK`, `DO_REINSTALL` variables and all `for arg in "$@"` block
- `_uninstall_tools()` function
- The `if $DO_REINSTALL` block
- The `if $DO_INSTALL` block (wrapping — keep the call to `_run_install` directly)
- The `if $DO_LINK` block (calls `link.sh`)

- [ ] **Step 2: Update `_run_install()` with new module sequence**

```bash
_run_install() {
  header "Installing development tools"

  mkdir -p "$HOME/Dev/tools/python/pyenv" \
           "$HOME/Dev/tools/python/poetry" \
           "$HOME/Dev/tools/node/nvm" \
           "$HOME/Dev/tools/java/sdkman" \
           "$HOME/Dev/tools/ai/claude" \
           "$HOME/Dev/tools/ai/gemini" \
           "$HOME/Dev/tools/ai/gemini-config" \
           "$HOME/Dev/repos"

  for module in  "$DOTFILES_DIR/install/00_packages.sh" \
                 "$DOTFILES_DIR/install/01_shell.sh" \
                 "$DOTFILES_DIR/install/02_chezmoi.sh" \
                 "$DOTFILES_DIR/install/03_python.sh" \
                 "$DOTFILES_DIR/install/04_java.sh" \
                 "$DOTFILES_DIR/install/05_node.sh" \
                 "$DOTFILES_DIR/install/06_ai.sh" \
                 "$DOTFILES_DIR/install/07_containers.sh"
  do
    if [[ -f "$module" ]]; then
      source "$module"
      "$(basename "$module" .sh | sed 's/^[0-9]*_/install_/')" || \
        warn "Module $(basename "$module") reported an issue — continuing"
    fi
  done
}
```

- [ ] **Step 3: Update entry point and final message**

```bash
# Entry point — simplified
echo ""
echo -e "${MAGENTA}╔══════════════════════════════════════════════╗${RESET}"
echo -e "${MAGENTA}║       linux-init-bootstrap — setup           ║${RESET}"
echo -e "${MAGENTA}╚══════════════════════════════════════════════╝${RESET}"
echo ""

_run_install

echo ""
success "Bootstrap complete! Tools installed."
echo ""
info "Next step — apply dotfiles:"
info "  chezmoi init --apply git@github.com:nonatorw/chezmoi-dotfiles.git"
```

- [ ] **Step 4: Verify syntax**

```bash
bash -n bootstrap.sh
```

- [ ] **Step 5: Commit**

```bash
git add bootstrap.sh
git commit -m "refactor: simplify bootstrap — remove link/reinstall, update module sequence, add chezmoi next-step message"
```

---

## Task 9: Delete files now owned by `chezmoi-dotfiles`

**Prerequisite:** Confirm `chezmoi apply` has been run successfully on this machine with the updated `chezmoi-dotfiles`. The active dotfiles (`~/.zshrc`, `~/.local/bin/`, etc.) must be sourced from chezmoi, not from symlinks into this repo.

- [ ] **Step 1: Verify active dotfiles are sourced from chezmoi**

```bash
readlink ~/.zshrc
readlink ~/.local/bin/aliases.sh
readlink ~/.local/bin/dev_configs.sh
```

Expected: paths pointing into `~/.local/share/chezmoi/` (chezmoi's source dir), NOT into `~/Dev/repos/nonatorw-dotfiles/`.

If still pointing to this repo, run `chezmoi apply` first before continuing.

- [ ] **Step 2: Delete all files owned by chezmoi-dotfiles**

```bash
cd ~/Dev/repos/nonatorw-dotfiles
git rm -r link.sh local-bin/ git/ claude/ java/ zsh/
git rm plan-refactoring-nonatorw-dotfiles.md
```

- [ ] **Step 3: Verify nothing critical was missed**

```bash
ls -la ~/Dev/repos/nonatorw-dotfiles/
```

Expected structure:

```console
bootstrap.sh
lib/
install/
docs/
```

- [ ] **Step 4: Commit**

```bash
git commit -m "refactor: remove files now owned by chezmoi-dotfiles (link.sh, local-bin, git, claude, java, zsh)"
```

---

## Task 10: Final smoke test

- [ ] **Step 1: Test bootstrap from scratch in a subshell**

```bash
bash -n ~/Dev/repos/nonatorw-dotfiles/bootstrap.sh
```

Expected: no syntax errors. Then verify no unknown args cause silent failure:

```bash
bash ~/Dev/repos/nonatorw-dotfiles/bootstrap.sh --unknown 2>&1 | head -3
```

Expected: error message and non-zero exit (the `error()` function calls `exit 1`).

- [ ] **Step 2: Verify module function name convention still works**

The bootstrap sources each module and calls `install_<name>`. Verify the naming:

```bash
grep -h "^install_" ~/Dev/repos/nonatorw-dotfiles/install/*.sh
```

Expected:

```text
install_packages()
install_shell()
install_chezmoi()
install_python()
install_java()
install_node()
install_ai()
install_containers()
```

- [ ] **Step 3: Push**

```bash
git push origin main
```

---

## Verification Checklist

- [ ] `bootstrap.sh` has no `--install`, `--link`, `--reinstall` flags, no `DO_INSTALL`/`DO_LINK`/`DO_REINSTALL` variables
- [ ] Module sequence: 00 packages, 01 shell, 02 chezmoi, 03 python, 04 java, 05 node, 06 ai, 07 containers
- [ ] `install/02_chezmoi.sh` exists and is executable
- [ ] `install/03_python.sh` includes `_install_uv()` called from `install_python()`
- [ ] `install/03_python.sh` uses `GIT_CONFIG_NOSYSTEM=1 HOME=/tmp git clone` for pyenv
- [ ] `install/04_java.sh` calls `sdk install java 25.0.3.fx-zulu` (Azul Zulu LTS)
- [ ] `install/05_node.sh` uses `GIT_CONFIG_NOSYSTEM=1 HOME=/tmp git clone` for NVM
- [ ] `install/05_node.sh` has no `$DO_REINSTALL` reference
- [ ] `install/01_shell.sh` uses `GIT_CONFIG_NOSYSTEM=1 HOME=/tmp git clone` for p10k and plugins
- [ ] `install/06_ai.sh` creates `~/Dev/tools/ai/gemini-config/projects.json` (not `~/.gemini`)
- [ ] `link.sh`, `local-bin/`, `git/`, `claude/`, `java/`, `zsh/` all deleted
- [ ] `bash -n bootstrap.sh` passes
- [ ] All commits pushed to `origin main`
