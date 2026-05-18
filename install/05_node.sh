#!/usr/bin/env bash
# ============================================================
# 05_node.sh — NVM + Node.js LTS
# ============================================================

# Captura valor original do ambiente antes de forçar o path padrão
_ORIG_NVM_DIR="${NVM_DIR:-}"

# Sempre usa o path padrão do script, ignorando variáveis de ambiente externas
NVM_DIR="$HOME/Dev/tools/node/nvm"

install_node() {
  echo "[node] Configuring Node.js environment..."
  _install_nvm
  _install_node_lts
}

_install_nvm() {
  # Remove instalações em paths não-padrão antes de instalar
  # nvm é uma shell function — não há subcomando de root. A própria documentação
  # do NVM indica que sua localização é controlada pela env var $NVM_DIR.
  # Quando o bootstrap é iniciado de uma sessão com nvm carregado (via .zshrc),
  # $NVM_DIR já estará no ambiente — capturado em $_ORIG_NVM_DIR.
  # O installer do NVM ignora INSTALL_DIR quando detecta instalação anterior em ~/.nvm,
  # por isso a remoção prévia é obrigatória.
  local candidates=("$HOME/.nvm")
  [[ -n "$_ORIG_NVM_DIR" ]] && candidates+=("$_ORIG_NVM_DIR")
  for loc in "${candidates[@]}"; do
    [[ "$loc" != "$NVM_DIR" && -d "$loc" ]] && {
      echo "[node] Removing NVM from non-standard location: $loc..."
      rm -rf "$loc"
    }
  done

  if [[ -f "$NVM_DIR/nvm.sh" ]]; then
    echo "[node] NVM already installed — skipping"
  else
    echo "[node] Installing NVM to $NVM_DIR..."
    local latest
    latest=$(curl -s "https://api.github.com/repos/nvm-sh/nvm/releases/latest" \
      | grep '"tag_name"' | sed -E 's/.*"(v[^"]+)".*/\1/')
    # Instalação manual via git clone — método recomendado pela documentação do NVM
    # para diretórios não-padrão. Evita o installer script, que modifica perfis do
    # shell e tem comportamento imprevisível quanto ao INSTALL_DIR quando detecta
    # instalações anteriores.
    GIT_CONFIG_NOSYSTEM=1 HOME=/tmp git clone --depth=1 --branch "$latest" https://github.com/nvm-sh/nvm.git "$NVM_DIR"
  fi

  # Carrega NVM na sessão atual
  # nvm.sh usa variáveis opcionais que ficam unbound com set -u no bash
  export NVM_DIR
  set +u
  # shellcheck source=/dev/null
  \. "$NVM_DIR/nvm.sh"
  set -u
}

_install_node_lts() {
  set +u
  if nvm current 2>/dev/null | grep -qv "none\|N/A"; then
    echo "[node] Node.js already installed: $(nvm current)"
    nvm alias default 'lts/*'
    set -u
    return 0
  fi
  echo "[node] Installing Node.js LTS..."
  nvm install --lts
  nvm alias default 'lts/*'
  set -u
  echo "[node] Node.js: $(node --version)"
}
