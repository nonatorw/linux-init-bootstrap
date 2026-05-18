#!/usr/bin/env bash
# ============================================================
# 03_python.sh — pyenv + Python (latest stable 3.x) + Poetry
# ============================================================

# Captura valores originais do ambiente antes de forçar os paths padrão
# (necessário para detectar instalações em locais não-padrão)
_ORIG_PYENV_ROOT="${PYENV_ROOT:-}"
_ORIG_POETRY_HOME="${POETRY_HOME:-}"

# pyenv root deve ser chamado ANTES de sobrescrever PYENV_ROOT — se chamado
# depois, apenas reflete a variável que já definimos (inútil para detecção).
# Sem PYENV_ROOT definido, pyenv root deriva o path a partir da localização
# do binário, cobrindo casos onde PYENV_ROOT não estava no ambiente.
if command -v pyenv &>/dev/null; then
  _PYENV_REPORTED_ROOT="$(pyenv root 2>/dev/null || true)"
else
  _PYENV_REPORTED_ROOT=""
fi

# Sempre usa o path padrão do script, ignorando variáveis de ambiente externas
PYENV_ROOT="$HOME/Dev/tools/python/pyenv"
POETRY_HOME="$HOME/Dev/tools/python/poetry"

install_python() {
  echo "[python] Configuring Python environment..."
  _install_pyenv
  _install_python_version
  _install_poetry
  _install_uv
}

_install_pyenv() {
  # Remove instalações em paths não-padrão antes de instalar
  # Candidatos: path histórico padrão (~/.pyenv), env var original (_ORIG_PYENV_ROOT)
  # e root reportado pelo binário antes de PYENV_ROOT ser sobrescrito (_PYENV_REPORTED_ROOT)
  local candidates=("$HOME/.pyenv")
  [[ -n "$_ORIG_PYENV_ROOT" ]]      && candidates+=("$_ORIG_PYENV_ROOT")
  [[ -n "$_PYENV_REPORTED_ROOT" ]]  && candidates+=("$_PYENV_REPORTED_ROOT")
  for loc in "${candidates[@]}"; do
    [[ "$loc" != "$PYENV_ROOT" && -d "$loc" ]] && {
      echo "[python] Removing pyenv from non-standard location: $loc..."
      rm -rf "$loc"
    }
  done

  if [[ -d "$PYENV_ROOT/.git" ]]; then
    echo "[python] pyenv already installed — skipping"
    return 0
  fi
  echo "[python] Installing pyenv to $PYENV_ROOT..."
  rm -rf "$PYENV_ROOT"
  GIT_CONFIG_NOSYSTEM=1 HOME=/tmp git clone https://github.com/pyenv/pyenv.git "$PYENV_ROOT"

  # Compila extensão para melhor performance
  cd "$PYENV_ROOT" && src/configure && make -C src 2>/dev/null; cd - >/dev/null
}

_install_python_version() {
  # Exporta PYENV_ROOT explicitamente para que subprocessos (pyenv-install,
  # python-build) herdem o path correto; sem export, usariam o default ~/.pyenv
  export PYENV_ROOT
  export PATH="$PYENV_ROOT/bin:$PATH"
  eval "$(pyenv init - bash)"

  # Encontra a versão mais recente estável 3.x
  local latest
  latest=$(pyenv install --list | grep -E "^\s+3\.[0-9]+\.[0-9]+$" | tail -1 | tr -d ' ')

  if pyenv versions --bare | grep -qx "$latest"; then
    echo "[python] Python $latest already installed — setting as global"
  else
    echo "[python] Installing Python $latest..."
    pyenv install "$latest"
  fi

  pyenv global "$latest"
  echo "[python] Active Python: $(python --version)"
}

_install_poetry() {
  # Remove instalações em paths não-padrão antes de instalar
  local candidates=("$HOME/.poetry" "$HOME/.local/share/pypoetry")
  [[ -n "$_ORIG_POETRY_HOME" ]] && candidates+=("$_ORIG_POETRY_HOME")
  for loc in "${candidates[@]}"; do
    [[ "$loc" != "$POETRY_HOME" && -d "$loc" ]] && {
      echo "[python] Removing Poetry from non-standard location: $loc..."
      rm -rf "$loc"
    }
  done

  if [[ -f "$POETRY_HOME/bin/poetry" ]]; then
    echo "[python] Poetry already installed — skipping"
    return 0
  fi
  echo "[python] Installing Poetry to $POETRY_HOME..."
  rm -rf "$POETRY_HOME"
  export POETRY_HOME
  curl -sSL https://install.python-poetry.org | python3 -
  "$POETRY_HOME/bin/poetry" config virtualenvs.in-project true
  echo "[python] Poetry: $("$POETRY_HOME/bin/poetry" --version)"
}

_install_uv() {
  if has uv; then
    echo "[python] uv already installed: $(uv --version)"
    return 0
  fi
  echo "[python] Installing uv..."
  curl -LsSf https://astral.sh/uv/install.sh | sh
  echo "[python] uv: $(uv --version)"
}
