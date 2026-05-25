#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# install/06_ai.sh
# AI tooling: Claude Code and Gemini CLI, installed to ~/Dev/tools/ai/ via npm.
# Requires Node.js (05_node.sh) to be installed first.
# ─────────────────────────────────────────────────────────────────────────────

CLAUDE_HOME="${CLAUDE_HOME:-$HOME/Dev/tools/ai/claude}"
GEMINI_HOME="${GEMINI_HOME:-$HOME/Dev/tools/ai/gemini}"

_REINSTALL_HINT="To reinstall, run: bash bootstrap.sh --clean-tools"

# ─────────────────────────────────────────────
# Summary: install Claude Code and Gemini CLI (requires Node.js from 05_node.sh)
# Returns: 0 on success
# ─────────────────────────────────────────────
install_ai() {
  step_header "${_BOOTSTRAP_STEP_N}" "${_BOOTSTRAP_STEP_TOTAL}" \
    "AI Tools" "Claude Code · Gemini CLI · GitHub Copilot"

  _guard_node_available || return 1
  _check_gh_cli
  _install_claude_code
  _install_gemini_cli
  _init_gemini_dir
  _show_copilot_instructions
}

# ─────────────────────────────────────────────
# Summary: ensure Node.js is available; offer to install via NVM if absent
# Returns: 1 if Node.js is still not available after the prompt
# ─────────────────────────────────────────────
_guard_node_available() {
  if has node; then
    return 0
  fi

  warn "Node.js not found — AI tools require Node.js"

  local nvm_sh="$HOME/Dev/tools/node/nvm/nvm.sh"
  if [[ -f "$nvm_sh" ]]; then
    set +u
    # shellcheck source=/dev/null
    \. "$nvm_sh"
    set -u
    if has node; then
      return 0
    fi
  fi

  if ! _confirm "Node.js is required for AI tools. Install Node.js LTS now?"; then
    warn "AI tools skipped — Node.js not installed"
    return 1
  fi

  set +u
  if [[ -f "$nvm_sh" ]]; then
    \. "$nvm_sh"
    nvm install --lts && nvm alias default 'lts/*'
  else
    warn "NVM not found — run --modules node first, then re-run --modules ai"
    set -u
    return 1
  fi
  set -u

  if ! has node; then
    warn "Node.js installation failed — skipping AI tools"
    return 1
  fi

  state_set "module_05_node_lts" "complete"
  ok "Node.js $(node --version)"
}

# ─────────────────────────────────────────────
# Summary: check gh CLI availability; warn if absent (required for Copilot)
# ─────────────────────────────────────────────
_check_gh_cli() {
  if has gh; then
    return 0
  fi
  warn "gh CLI not found — GitHub Copilot requires it. Install gh CLI and re-run to enable Copilot."
}

# ─────────────────────────────────────────────
# Summary: install @anthropic-ai/claude-code via npm to ~/Dev/tools/ai/claude
# State key: module_06_ai_claude (complete|skipped)
# ─────────────────────────────────────────────
_install_claude_code() {
  local state_key="module_06_ai_claude"

  if state_is "$state_key" "complete"; then
    local ver
    ver="$("$CLAUDE_HOME/bin/claude" --version 2>/dev/null || echo 'installed')"
    skip "Claude Code ${ver}  ${DIM}${_REINSTALL_HINT}${RESET}"
    return 0
  fi

  if ! _confirm "Install Claude Code?"; then
    warn "Claude Code skipped"
    state_set "$state_key" "skipped"
    return 0
  fi

  step "Installing Claude Code to ${DIM}$CLAUDE_HOME${RESET}..."
  mkdir -p "$CLAUDE_HOME"
  npm install --prefix "$CLAUDE_HOME" @anthropic-ai/claude-code
  mkdir -p "$CLAUDE_HOME/bin"
  ln -sf "../node_modules/.bin/claude" "$CLAUDE_HOME/bin/claude"
  ok "Claude Code $("$CLAUDE_HOME/bin/claude" --version 2>/dev/null || echo 'installed')"
  state_set "$state_key" "complete"
}

# ─────────────────────────────────────────────
# Summary: install @google/gemini-cli via npm to ~/Dev/tools/ai/gemini
# State key: module_06_ai_gemini (complete|skipped)
# ─────────────────────────────────────────────
_install_gemini_cli() {
  local state_key="module_06_ai_gemini"

  if state_is "$state_key" "complete"; then
    skip "Gemini CLI  ${DIM}${_REINSTALL_HINT}${RESET}"
    return 0
  fi

  if ! _confirm "Install Gemini CLI?"; then
    warn "Gemini CLI skipped"
    state_set "$state_key" "skipped"
    return 0
  fi

  step "Installing Gemini CLI to ${DIM}$GEMINI_HOME${RESET}..."
  mkdir -p "$GEMINI_HOME"
  npm install --prefix "$GEMINI_HOME" @google/gemini-cli

  # Gemini does not create bin/ under the prefix — create symlink to keep consistent structure
  mkdir -p "$GEMINI_HOME/bin"
  ln -sf "../node_modules/.bin/gemini" "$GEMINI_HOME/bin/gemini"
  ok "Gemini CLI installed"
  state_set "$state_key" "complete"
}

# ─────────────────────────────────────────────
# Summary: initialise Gemini config directory with an empty projects.json if not present
# ─────────────────────────────────────────────
_init_gemini_dir() {
  local gemini_config_dir="$HOME/Dev/tools/ai/gemini-config"
  mkdir -p "$gemini_config_dir"
  if [[ ! -f "$gemini_config_dir/projects.json" ]]; then
    echo '{"projects":[]}' > "$gemini_config_dir/projects.json"
  fi
  step "Gemini config dir: ${DIM}$gemini_config_dir${RESET}"
}

# ─────────────────────────────────────────────
# Summary: print GitHub Copilot setup instructions (no installation — requires user config)
# ─────────────────────────────────────────────
_show_copilot_instructions() {
  if ! has gh; then
    return 0
  fi

  echo -e ""
  echo -e "  ${CYAN}ℹ${RESET}  ${BOLD}GitHub Copilot CLI${RESET} — manual setup required:"
  echo -e "  ${DIM}  1. Authenticate with GitHub:${RESET}"
  echo -e "  ${DIM}     gh auth login${RESET}"
  echo -e "  ${DIM}  2. Install the Copilot extension:${RESET}"
  echo -e "  ${DIM}     gh extension install github/gh-copilot${RESET}"
  echo -e "  ${DIM}  3. Start using it:${RESET}"
  echo -e "  ${DIM}     gh copilot suggest \"how do I list files recursively\"${RESET}"
}
