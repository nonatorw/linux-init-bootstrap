#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# install/05_node.sh
# Node.js environment: NVM and Node.js LTS.
# ─────────────────────────────────────────────────────────────────────────────

# Capture original env value before overriding path
_ORIG_NVM_DIR="${NVM_DIR:-}"

# Always use the path defined by this script, ignoring external env vars
NVM_DIR="$HOME/Dev/tools/node/nvm"

_REINSTALL_HINT="To reinstall, run: bash setup/phase3-setup-bootstrap.sh --clean-tools"

# ─────────────────────────────────────────────
# Summary: install NVM and optionally Node.js LTS
# ─────────────────────────────────────────────
install_node() {
  step_header "${_BOOTSTRAP_STEP_N}" "${_BOOTSTRAP_STEP_TOTAL}" \
    "Node.js" "NVM · Node.js LTS"

  _install_nvm

  set +u
  _install_node_lts
  set -u
}

# ─────────────────────────────────────────────
# Summary: clone NVM to ~/Dev/tools/node/nvm via git; remove non-standard prior installations
# Returns: 0 on success, 1 if network or version resolution fails
# ─────────────────────────────────────────────
_install_nvm() {
  # Remove non-standard installations before installing.
  # nvm is a shell function — there is no root subcommand. NVM's own documentation
  # states that its location is controlled by the $NVM_DIR env var.
  # If bootstrap runs from a session with nvm already loaded (via .zshrc),
  # $NVM_DIR will already be in the environment — captured in $_ORIG_NVM_DIR.
  # The NVM installer ignores INSTALL_DIR when it detects a previous install at ~/.nvm,
  # so the prior removal is mandatory.
  local candidates=("$HOME/.nvm")
  [[ -n "$_ORIG_NVM_DIR" ]] && candidates+=("$_ORIG_NVM_DIR")
  for loc in "${candidates[@]}"; do
    [[ "$loc" != "$NVM_DIR" && -d "$loc" ]] && {
      step "Removing NVM from non-standard location: $loc..."
      rm -rf "$loc"
    }
  done

  if [[ -f "$NVM_DIR/nvm.sh" ]]; then
    local nvm_ver
    nvm_ver="$(grep -m1 '"version"' "$NVM_DIR/package.json" 2>/dev/null | sed -E 's/.*"([0-9]+\.[0-9]+\.[0-9]+)".*/\1/' || echo 'installed')"
    skip "NVM v${nvm_ver}  ${DIM}${_REINSTALL_HINT}${RESET}"
  else
    step "Resolving latest NVM release..."
    local latest
    latest=$(curl -s "https://api.github.com/repos/nvm-sh/nvm/releases/latest" \
      | grep '"tag_name"' | sed -E 's/.*"(v[^"]+)".*/\1/')
    if [[ -z "$latest" ]]; then
      warn "Failed to resolve latest NVM version — check network or GitHub API rate limit"
      return 1
    fi
    step "Installing NVM $latest to ${DIM}$NVM_DIR${RESET}..."
    # Manual install via git clone — the NVM-recommended method for non-default
    # directories. Avoids the installer script, which modifies shell profiles and
    # behaves unpredictably with INSTALL_DIR when it detects previous installations.
    if ! run_cmd "git clone nvm" git clone --depth=1 --branch "$latest" -c advice.detachedHead=false https://github.com/nvm-sh/nvm.git "$NVM_DIR"; then
      warn "Failed to clone NVM — check network connectivity"
      return 1
    fi
    ok "NVM $latest installed"
  fi

  # Load NVM into the current session.
  # nvm.sh uses optional variables that become unbound with set -u in bash
  export NVM_DIR
  set +u
  # shellcheck source=/dev/null
  \. "$NVM_DIR/nvm.sh"
  set -u
}

# ─────────────────────────────────────────────
# Summary: install Node.js LTS via NVM if confirmed by user
# State key: module_05_node_lts (complete|skipped)
# ─────────────────────────────────────────────
_install_node_lts() {
  local state_key="module_05_node_lts"

  if state_is "$state_key" "complete"; then
    skip "Node.js $(node --version 2>/dev/null || echo 'LTS')  ${DIM}${_REINSTALL_HINT}${RESET}"
    _symlink_node_to_system
    return 0
  fi

  if ! _confirm "Install Node.js LTS?"; then
    warn "Node.js LTS skipped"
    state_set "$state_key" "skipped"
    return 0
  fi

  step "Installing Node.js LTS..."
  if ! nvm install --lts; then
    warn "Failed to install Node.js LTS"
    return 1
  fi
  nvm alias default 'lts/*'
  ok "Node.js $(node --version)"
  state_set "$state_key" "complete"
  _symlink_node_to_system
}

# ─────────────────────────────────────────────
# Summary: create /usr/local/bin/node symlink so tools invoking node directly (e.g. gh extensions) work without NVM loaded
# ─────────────────────────────────────────────
_symlink_node_to_system() {
  local node_bin
  node_bin="$(command -v node 2>/dev/null || true)"
  [[ -z "$node_bin" ]] && return 0

  if [[ "$(readlink /usr/local/bin/node 2>/dev/null)" == "$node_bin" ]]; then
    return 0
  fi
  sudo ln -sf "$node_bin" /usr/local/bin/node
  ok "node symlinked to /usr/local/bin/node"
}
