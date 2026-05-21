#!/usr/bin/env bash
# ============================================================
# 06_ai.sh — Claude Code + Gemini CLI
# Instalados em ~/Dev/tools/ai/ via npm --prefix
# Depende do Node.js (05_node.sh) estar instalado
# ============================================================

CLAUDE_HOME="${CLAUDE_HOME:-$HOME/Dev/tools/ai/claude}"
GEMINI_HOME="${GEMINI_HOME:-$HOME/Dev/tools/ai/gemini}"

install_ai() {
  step_header "${_BOOTSTRAP_STEP_N}" "${_BOOTSTRAP_STEP_TOTAL}" \
    "AI Tools" "Claude Code · Gemini CLI"

  if ! has node; then
    warn "Node.js not found — skipping AI tools (run 05_node.sh first)"
    return 1
  fi

  _install_claude_code
  _install_gemini_cli
  _init_gemini_dir
}

_install_claude_code() {
  if [[ -f "$CLAUDE_HOME/bin/claude" ]]; then
    skip "Claude Code  ${DIM}($("$CLAUDE_HOME/bin/claude" --version 2>/dev/null || echo 'installed'))${RESET}"
    return 0
  fi
  step "Installing Claude Code to ${DIM}$CLAUDE_HOME${RESET}..."
  mkdir -p "$CLAUDE_HOME"
  npm install --prefix "$CLAUDE_HOME" @anthropic-ai/claude-code
  mkdir -p "$CLAUDE_HOME/bin"
  ln -sf "../node_modules/.bin/claude" "$CLAUDE_HOME/bin/claude"
  ok "Claude Code installed"
}

_install_gemini_cli() {
  if [[ -f "$GEMINI_HOME/bin/gemini" ]]; then
    skip "Gemini CLI"
    return 0
  fi
  step "Installing Gemini CLI to ${DIM}$GEMINI_HOME${RESET}..."
  mkdir -p "$GEMINI_HOME"
  npm install --prefix "$GEMINI_HOME" @google/gemini-cli

  # Gemini does not create bin/ under the prefix — create symlink to keep consistent structure
  mkdir -p "$GEMINI_HOME/bin"
  ln -sf "../node_modules/.bin/gemini" "$GEMINI_HOME/bin/gemini"
  ok "Gemini CLI installed"
}

_init_gemini_dir() {
  local gemini_config_dir="$HOME/Dev/tools/ai/gemini-config"
  mkdir -p "$gemini_config_dir"
  if [[ ! -f "$gemini_config_dir/projects.json" ]]; then
    echo '{"projects":[]}' > "$gemini_config_dir/projects.json"
  fi
  step "Gemini config dir: ${DIM}$gemini_config_dir${RESET}"
}


