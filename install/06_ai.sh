#!/usr/bin/env bash
# ============================================================
# 06_ai.sh — Claude Code + Gemini CLI
# Instalados em ~/Dev/tools/ai/ via npm --prefix
# Depende do Node.js (05_node.sh) estar instalado
# ============================================================

CLAUDE_HOME="${CLAUDE_HOME:-$HOME/Dev/tools/ai/claude}"
GEMINI_HOME="${GEMINI_HOME:-$HOME/Dev/tools/ai/gemini}"

install_ai() {
  echo "[ai] Installing AI tools..."

  if ! has node; then
    echo "[ai] ERROR: Node.js not found. Run 05_node.sh first."
    return 1
  fi

  _install_claude_code
  _install_gemini_cli
  _init_gemini_dir
}

_install_claude_code() {
  if [[ -f "$CLAUDE_HOME/bin/claude" ]]; then
    echo "[ai] Claude Code already installed: $("$CLAUDE_HOME/bin/claude" --version)"
    return 0
  fi
  echo "[ai] Installing Claude Code to $CLAUDE_HOME..."
  mkdir -p "$CLAUDE_HOME"
  npm install --prefix "$CLAUDE_HOME" @anthropic-ai/claude-code
}

_install_gemini_cli() {
  if [[ -f "$GEMINI_HOME/bin/gemini" ]]; then
    echo "[ai] Gemini CLI already installed"
    return 0
  fi
  echo "[ai] Installing Gemini CLI to $GEMINI_HOME..."
  mkdir -p "$GEMINI_HOME"
  npm install --prefix "$GEMINI_HOME" @google/gemini-cli

  # Gemini não cria bin/ no prefix — cria symlink para manter estrutura consistente
  mkdir -p "$GEMINI_HOME/bin"
  ln -sf "../node_modules/.bin/gemini" "$GEMINI_HOME/bin/gemini"
}

_init_gemini_dir() {
  local gemini_config_dir="$HOME/Dev/tools/ai/gemini-config"
  mkdir -p "$gemini_config_dir"
  if [[ ! -f "$gemini_config_dir/projects.json" ]]; then
    echo '{"projects":[]}' > "$gemini_config_dir/projects.json"
  fi
}
