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
  step_header "${_BOOTSTRAP_STEP_N}" "${_BOOTSTRAP_STEP_TOTAL}" \
    "Java" "SDKman · Zulu JDK 25 · Maven · Gradle"

  _install_sdkman

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
      step "Removing SDKman from non-standard location: $loc..."
      rm -rf "$loc"
    }
  done

  if [[ -f "$SDKMAN_DIR/bin/sdkman-init.sh" ]]; then
    skip "SDKman"
  else
    step "Installing SDKman to ${DIM}$SDKMAN_DIR${RESET}..."
    # Remove diretório vazio para evitar detecção falsa pelo installer
    [[ -d "$SDKMAN_DIR" && -z "$(ls -A "$SDKMAN_DIR")" ]] && rm -rf "$SDKMAN_DIR"
    export SDKMAN_DIR
    curl -s "https://get.sdkman.io" | bash
    ok "SDKman installed"
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
    skip "Java  ${DIM}($(java --version 2>/dev/null | head -1 || echo 'Zulu 25'))${RESET}"
    return 0
  fi
  step "Installing Java LTS ${DIM}(Zulu 25.0.3.fx via SDKman)${RESET}..."
  sdk install java 25.0.3.fx-zulu
  ok "Java $(java --version 2>/dev/null | head -1)"
}

_install_maven() {
  if [[ -d "$SDKMAN_DIR/candidates/maven/current" ]]; then
    skip "Maven  ${DIM}($(mvn --version 2>/dev/null | head -1 || echo 'installed'))${RESET}"
    return 0
  fi
  step "Installing Maven..."
  sdk install maven
  ok "Maven $(mvn --version 2>/dev/null | head -1)"
}

_install_gradle() {
  if [[ -d "$SDKMAN_DIR/candidates/gradle/current" ]]; then
    skip "Gradle  ${DIM}($(gradle --version 2>/dev/null | grep '^Gradle' || echo 'installed'))${RESET}"
    return 0
  fi
  step "Installing Gradle..."
  sdk install gradle
  ok "Gradle $(gradle --version 2>/dev/null | grep '^Gradle' || echo 'installed')"
}

_configure_gradle() {
  step "Configuring GRADLE_USER_HOME → ${DIM}$GRADLE_USER_HOME${RESET}"
  mkdir -p "$GRADLE_USER_HOME"
  # GRADLE_USER_HOME é exportado via dev_configs.sh — nada mais necessário
}

_configure_maven() {
  step "Configuring Maven local repository → ${DIM}$MAVEN_LOCAL_REPO${RESET}"
  mkdir -p "$MAVEN_LOCAL_REPO"
  mkdir -p "$HOME/.m2"
  # settings.xml é linkado pelo chezmoi-dotfiles via chezmoi apply
  # MAVEN_OPTS com -Dmaven.repo.local é exportado via dev_configs.sh
}
