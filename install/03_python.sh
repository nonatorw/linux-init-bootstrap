#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# install/03_python.sh
# Python environment: uv (package manager + Python installer).
# ─────────────────────────────────────────────────────────────────────────────

UV_INSTALL_DIR="${UV_INSTALL_DIR:-$HOME/Dev/tools/python/uv/bin}"
UV_PYTHON_INSTALL_DIR="${UV_PYTHON_INSTALL_DIR:-$HOME/Dev/tools/python/versions}"

_REINSTALL_HINT="To reinstall, run: bash setup/phase3-setup-bootstrap.sh --clean-tools"

# ─────────────────────────────────────────────
# Summary: install uv and optionally Python LTS
# ─────────────────────────────────────────────
install_python() {
  step_header "${_BOOTSTRAP_STEP_N}" "${_BOOTSTRAP_STEP_TOTAL}" \
    "Python" "uv · Python LTS"

  _install_uv
  _install_python_lts
}

# ─────────────────────────────────────────────
# Summary: install uv to ~/Dev/tools/python/uv/bin; always installed, no prompt
# ─────────────────────────────────────────────
_install_uv() {
  local uv_bin="$UV_INSTALL_DIR/uv"
  if [[ -x "$uv_bin" ]]; then
    skip "$("$uv_bin" --version)  ${DIM}${_REINSTALL_HINT}${RESET}"
    export PATH="$UV_INSTALL_DIR:$PATH"
    return 0
  fi
  step "Installing uv to ${DIM}$UV_INSTALL_DIR${RESET}..."
  mkdir -p "$UV_INSTALL_DIR"
  local uv_log
  export UV_INSTALL_DIR
  uv_log="$(curl -LsSf https://astral.sh/uv/install.sh | sh 2>&1)" \
    && echo "$uv_log" >> "$BOOTSTRAP_LOG" \
    || { echo "$uv_log" >> "$BOOTSTRAP_LOG"; warn "uv installer failed — check $BOOTSTRAP_LOG"; return 1; }
  export PATH="$UV_INSTALL_DIR:$PATH"
  ok "$("$uv_bin" --version)"
}

# ─────────────────────────────────────────────
# Summary: install Python LTS via uv if confirmed by user
# State key: module_03_python_lts (complete|skipped)
# ─────────────────────────────────────────────
_install_python_lts() {
  local state_key="module_03_python_lts"

  if state_is "$state_key" "complete"; then
    local ver
    ver="$(UV_PYTHON_INSTALL_DIR="$UV_PYTHON_INSTALL_DIR" uv python list --only-installed 2>/dev/null \
      | grep -E 'cpython-3\.' | head -1 | awk '{print $1}' || echo 'Python LTS')"
    skip "${ver}  ${DIM}${_REINSTALL_HINT}${RESET}"
    return 0
  fi

  if ! _confirm "Install Python LTS?"; then
    warn "Python LTS skipped"
    state_set "$state_key" "skipped"
    return 0
  fi

  step "Installing Python LTS to ${DIM}$UV_PYTHON_INSTALL_DIR${RESET}..."
  if ! UV_PYTHON_INSTALL_DIR="$UV_PYTHON_INSTALL_DIR" uv python install; then
    warn "Python LTS installation failed — check $BOOTSTRAP_LOG"
    return 1
  fi
  local ver
  ver="$(UV_PYTHON_INSTALL_DIR="$UV_PYTHON_INSTALL_DIR" uv python list --only-installed 2>/dev/null \
    | grep -E 'cpython-3\.' | head -1 | awk '{print $1}' || echo 'Python LTS')"
  ok "${ver} installed"
  state_set "$state_key" "complete"
}
