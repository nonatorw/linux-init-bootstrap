#!/usr/bin/env bash
# ============================================================
# 05_node.sh — NVM + Node.js LTS
# ============================================================

# Capture original env value before overriding path
_ORIG_NVM_DIR="${NVM_DIR:-}"

# Always use the path defined by this script, ignoring external env vars
NVM_DIR="$HOME/Dev/tools/node/nvm"

install_node() {
  step_header "${_BOOTSTRAP_STEP_N}" "${_BOOTSTRAP_STEP_TOTAL}" \
    "Node.js" "NVM · Node.js LTS"

  _install_nvm
  _install_node_lts
}

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
    skip "NVM"
  else
    step "Resolving latest NVM release..."
    local latest
    latest=$(curl -s "https://api.github.com/repos/nvm-sh/nvm/releases/latest" \
      | grep '"tag_name"' | sed -E 's/.*"(v[^"]+)".*/\1/')
    step "Installing NVM $latest to ${DIM}$NVM_DIR${RESET}..."
    # Manual install via git clone — the NVM-recommended method for non-default
    # directories. Avoids the installer script, which modifies shell profiles and
    # behaves unpredictably with INSTALL_DIR when it detects previous installations.
    GIT_CONFIG_NOSYSTEM=1 HOME=/tmp git clone --depth=1 --branch "$latest" https://github.com/nvm-sh/nvm.git "$NVM_DIR"
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

_install_node_lts() {
  set +u
  if nvm current 2>/dev/null | grep -qv "none\|N/A"; then
    skip "Node.js $(nvm current)"
    nvm alias default 'lts/*'
    set -u
    return 0
  fi
  step "Installing Node.js LTS..."
  nvm install --lts
  nvm alias default 'lts/*'
  set -u
  ok "Node.js $(node --version)"
}
