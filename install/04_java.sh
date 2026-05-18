#!/usr/bin/env bash
# ============================================================
# 04_java.sh — SDKman + Java LTS (Zulu 25.0.3.fx) + Maven + Gradle
# ============================================================

# Captura valores originais do ambiente antes de forçar os paths padrão
_ORIG_SDKMAN_DIR="${SDKMAN_DIR:-}"

# Sempre usa os paths padrão do script, ignorando variáveis de ambiente externas
SDKMAN_DIR="$HOME/Dev/tools/java/sdkman"
GRADLE_USER_HOME="$HOME/Dev/tools/java/gradle"
MAVEN_LOCAL_REPO="$HOME/Dev/tools/java/m2"

install_java() {
  echo "[java] Configuring Java environment..."
  _install_sdkman

  # Se --reinstall foi usado e o usuário optou por manter o SDKman
  # (ferramenta estava no path padrão e usuário disse N),
  # os SDKs já estão instalados — não há necessidade de verificar/instalar
  if $DO_REINSTALL && [[ "${REINSTALL_JAVA:-false}" == "false" ]]; then
    echo "[java] SDKman kept — skipping SDK installs"
    _configure_gradle
    _configure_maven
    return 0
  fi

  # sdk e seus scripts internos usam parâmetros opcionais ($3, etc.) que ficam
  # unbound no bash com set -u; desliga temporariamente para todas as chamadas sdk
  set +u
  _install_java_lts
  _install_maven
  _install_gradle
  set -u
  _configure_gradle
  _configure_maven
}

_install_sdkman() {
  # Remove instalações em paths não-padrão antes de instalar
  # sdk é uma shell function — não há subcomando de root. O mecanismo oficial é a
  # env var $SDKMAN_DIR, que é definida automaticamente ao fazer source do sdkman-init.sh.
  # Quando o bootstrap é iniciado de uma sessão com sdkman carregado (via .zshrc),
  # $SDKMAN_DIR já estará no ambiente — capturado em $_ORIG_SDKMAN_DIR.
  # Complementado pelo path padrão histórico (~/.sdkman).
  local candidates=("$HOME/.sdkman")
  [[ -n "$_ORIG_SDKMAN_DIR" ]] && candidates+=("$_ORIG_SDKMAN_DIR")
  for loc in "${candidates[@]}"; do
    [[ "$loc" != "$SDKMAN_DIR" && -d "$loc" ]] && {
      echo "[java] Removing SDKman from non-standard location: $loc..."
      rm -rf "$loc"
    }
  done

  if [[ -f "$SDKMAN_DIR/bin/sdkman-init.sh" ]]; then
    echo "[java] SDKman already installed — skipping"
  else
    echo "[java] Installing SDKman to $SDKMAN_DIR..."
    # Remove diretório vazio para evitar detecção falsa pelo installer
    [[ -d "$SDKMAN_DIR" && -z "$(ls -A "$SDKMAN_DIR")" ]] && rm -rf "$SDKMAN_DIR"
    export SDKMAN_DIR
    curl -s "https://get.sdkman.io" | bash
  fi

  # Carrega SDKman na sessão atual
  # sdkman-init.sh usa variáveis opcionais (ZSH_VERSION, etc.) que podem estar unbound
  # no bash; desliga -u temporariamente para evitar falha
  # shellcheck source=/dev/null
  set +u
  source "$SDKMAN_DIR/bin/sdkman-init.sh"
  set -u
}

_install_java_lts() {
  if [[ -d "$SDKMAN_DIR/candidates/java/current" ]]; then
    echo "[java] Java LTS already installed — skipping"
    return 0
  fi
  echo "[java] Installing Java LTS (Zulu 25.0.3.fx via SDKman)..."
  sdk install java 25.0.3.fx-zulu
}

_install_maven() {
  if [[ -d "$SDKMAN_DIR/candidates/maven/current" ]]; then
    echo "[java] Maven already installed — skipping"
    return 0
  fi
  echo "[java] Installing Maven..."
  sdk install maven
}

_install_gradle() {
  if [[ -d "$SDKMAN_DIR/candidates/gradle/current" ]]; then
    echo "[java] Gradle already installed — skipping"
    return 0
  fi
  echo "[java] Installing Gradle..."
  sdk install gradle
}

_configure_gradle() {
  echo "[java] Configuring GRADLE_USER_HOME → $GRADLE_USER_HOME"
  mkdir -p "$GRADLE_USER_HOME"
  # GRADLE_USER_HOME é exportado via dev_configs.sh — nada mais necessário
}

_configure_maven() {
  echo "[java] Configuring Maven local repository → $MAVEN_LOCAL_REPO"
  mkdir -p "$MAVEN_LOCAL_REPO"
  mkdir -p "$HOME/.m2"
  # settings.xml é linkado pelo link.sh a partir do dotfiles repo
  # MAVEN_OPTS com -Dmaven.repo.local é exportado via dev_configs.sh
}
