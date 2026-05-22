#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# install/03_python.sh
# Python environment: pyenv, latest stable Python 3.x, Poetry, and uv.
# ─────────────────────────────────────────────────────────────────────────────

# Capture original env values before overriding paths
# (needed to detect and remove non-standard installations)
_ORIG_PYENV_ROOT="${PYENV_ROOT:-}"
_ORIG_POETRY_HOME="${POETRY_HOME:-}"

# pyenv root must be called BEFORE overwriting PYENV_ROOT — if called after,
# it only reflects the variable we just set (useless for detection).
# Without PYENV_ROOT set, pyenv root derives the path from the binary location,
# covering cases where PYENV_ROOT was not in the environment.
if command -v pyenv &>/dev/null; then
  _PYENV_REPORTED_ROOT="$(pyenv root 2>/dev/null || true)"
else
  _PYENV_REPORTED_ROOT=""
fi

# Always use the paths defined by this script, ignoring external env vars
PYENV_ROOT="$HOME/Dev/tools/python/pyenv"
POETRY_HOME="$HOME/Dev/tools/python/poetry"

# ─────────────────────────────────────────────
# Summary: install pyenv, latest stable Python 3.x, Poetry, and uv
# ─────────────────────────────────────────────
install_python() {
  step_header "${_BOOTSTRAP_STEP_N}" "${_BOOTSTRAP_STEP_TOTAL}" \
    "Python" "pyenv · Python 3.x · Poetry · uv"

  _install_pyenv
  _install_python_version
  _install_poetry
  _install_uv
}

# ─────────────────────────────────────────────
# Summary: clone pyenv to ~/Dev/tools/python/pyenv; remove non-standard prior installations
# ─────────────────────────────────────────────
_install_pyenv() {
  # Remove non-standard installations before installing.
  # Candidates: historical default (~/.pyenv), original env var (_ORIG_PYENV_ROOT),
  # and root reported by the binary before PYENV_ROOT was overwritten (_PYENV_REPORTED_ROOT)
  local candidates=("$HOME/.pyenv")
  [[ -n "$_ORIG_PYENV_ROOT" ]]      && candidates+=("$_ORIG_PYENV_ROOT")
  [[ -n "$_PYENV_REPORTED_ROOT" ]]  && candidates+=("$_PYENV_REPORTED_ROOT")
  for loc in "${candidates[@]}"; do
    [[ "$loc" != "$PYENV_ROOT" && -d "$loc" ]] && {
      step "Removing pyenv from non-standard location: $loc..."
      rm -rf "$loc"
    }
  done

  if [[ -d "$PYENV_ROOT/.git" ]]; then
    skip "pyenv  ${DIM}($(pyenv --version 2>/dev/null || echo 'unknown'))${RESET}"
  else
    step "Installing pyenv to ${DIM}$PYENV_ROOT${RESET}..."
    rm -rf "$PYENV_ROOT"
    run_cmd "git clone pyenv" GIT_CONFIG_NOSYSTEM=1 HOME=/tmp git clone https://github.com/pyenv/pyenv.git "$PYENV_ROOT"

    step "  Compiling pyenv native extension..."
    cd "$PYENV_ROOT" && src/configure && make -C src 2>/dev/null; cd - >/dev/null
    ok "pyenv installed"
  fi

  _install_pyenv_plugins
}

# ─────────────────────────────────────────────
# Summary: clone pyenv-doctor and pyenv-update into the pyenv plugins directory
# ─────────────────────────────────────────────
_install_pyenv_plugins() {
  declare -A pyenv_plugins=(
    ["pyenv-doctor"]="https://github.com/pyenv/pyenv-doctor"
    ["pyenv-update"]="https://github.com/pyenv/pyenv-update"
  )

  for plugin in "${!pyenv_plugins[@]}"; do
    local plugin_dir="$PYENV_ROOT/plugins/$plugin"
    if [[ -d "$plugin_dir/.git" ]]; then
      skip "  $plugin"
    else
      [[ -d "$plugin_dir" ]] && rm -rf "$plugin_dir"
      step "  Installing $plugin..."
      run_cmd "git clone $plugin" GIT_CONFIG_NOSYSTEM=1 HOME=/tmp git clone "${pyenv_plugins[$plugin]}" "$plugin_dir"
      ok "  $plugin"
    fi
  done
}

# ─────────────────────────────────────────────
# Summary: install the latest stable Python 3.x via pyenv and set it as the global version
# ─────────────────────────────────────────────
_install_python_version() {
  # Export PYENV_ROOT explicitly so subprocesses (pyenv-install, python-build)
  # inherit the correct path; without export they would default to ~/.pyenv
  export PYENV_ROOT
  export PATH="$PYENV_ROOT/bin:$PATH"
  eval "$(pyenv init - bash)"

  # Find the latest stable 3.x version
  local latest
  latest=$(pyenv install --list | grep -E "^\s+3\.[0-9]+\.[0-9]+$" | tail -1 | tr -d ' ')

  if pyenv versions --bare | grep -qx "$latest"; then
    skip "Python $latest"
  else
    step "Installing Python $latest ${DIM}(this may take a few minutes)${RESET}..."
    pyenv install "$latest"
    ok "Python $latest installed"
  fi

  pyenv global "$latest"
  ok "Active Python: $(python --version)"
}

# ─────────────────────────────────────────────
# Summary: install Poetry to ~/Dev/tools/python/poetry; remove non-standard prior installations
# ─────────────────────────────────────────────
_install_poetry() {
  # Remove non-standard installations before installing
  local candidates=("$HOME/.poetry" "$HOME/.local/share/pypoetry")
  [[ -n "$_ORIG_POETRY_HOME" ]] && candidates+=("$_ORIG_POETRY_HOME")
  for loc in "${candidates[@]}"; do
    [[ "$loc" != "$POETRY_HOME" && -d "$loc" ]] && {
      step "Removing Poetry from non-standard location: $loc..."
      rm -rf "$loc"
    }
  done

  if [[ -f "$POETRY_HOME/bin/poetry" ]]; then
    skip "$("$POETRY_HOME/bin/poetry" --version)"
    return 0
  fi
  step "Installing Poetry to ${DIM}$POETRY_HOME${RESET}..."
  rm -rf "$POETRY_HOME"
  export POETRY_HOME
  run_cmd "poetry install" curl -sSL https://install.python-poetry.org | python3 -
  "$POETRY_HOME/bin/poetry" config virtualenvs.in-project true
  ok "$("$POETRY_HOME/bin/poetry" --version)  ${DIM}(virtualenvs.in-project = true)${RESET}"
}

# ─────────────────────────────────────────────
# Summary: install uv (fast Python package manager) to ~/.local/bin
# ─────────────────────────────────────────────
_install_uv() {
  local uv_bin="${UV_INSTALL_DIR:-$HOME/.local/bin}/uv"
  if [[ -x "$uv_bin" ]]; then
    skip "$("$uv_bin" --version)"
    return 0
  fi
  step "Installing uv..."
  run_cmd "uv install" curl -LsSf https://astral.sh/uv/install.sh | sh
  # Ensure the newly installed binary is in the session PATH
  export PATH="$HOME/.local/bin:$PATH"
  ok "$("$uv_bin" --version)"
}
