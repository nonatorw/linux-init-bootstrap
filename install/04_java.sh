#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# install/04_java.sh
# Java environment: SDKman, Zulu JDK 25 LTS, Maven, and Gradle.
# ─────────────────────────────────────────────────────────────────────────────

_ORIG_SDKMAN_DIR="${SDKMAN_DIR:-}"

SDKMAN_DIR="$HOME/Dev/tools/java/sdkman"
GRADLE_USER_HOME="$HOME/Dev/tools/java/gradle"
MAVEN_LOCAL_REPO="$HOME/Dev/tools/java/m2"

_REINSTALL_HINT="To reinstall, run: bash bootstrap.sh --clean-tools"

# ─────────────────────────────────────────────
# Summary: install SDKman and optionally JDK, Maven, and Gradle
# ─────────────────────────────────────────────
install_java() {
  step_header "${_BOOTSTRAP_STEP_N}" "${_BOOTSTRAP_STEP_TOTAL}" \
    "Java" "SDKman · Zulu JDK 25 · Maven · Gradle"

  _install_sdkman

  set +u
  _install_java_lts
  _install_maven
  _install_gradle
  set -u
  _configure_gradle
  _configure_maven
}

# ─────────────────────────────────────────────
# Summary: install SDKman to ~/Dev/tools/java/sdkman; always installed, no prompt
# ─────────────────────────────────────────────
_install_sdkman() {
  local candidates=("$HOME/.sdkman")
  [[ -n "$_ORIG_SDKMAN_DIR" ]] && candidates+=("$_ORIG_SDKMAN_DIR")
  for loc in "${candidates[@]}"; do
    [[ "$loc" != "$SDKMAN_DIR" && -d "$loc" ]] && {
      step "Removing SDKman from non-standard location: $loc..."
      rm -rf "$loc"
    }
  done

  if [[ -f "$SDKMAN_DIR/bin/sdkman-init.sh" ]]; then
    skip "SDKman  ${DIM}${_REINSTALL_HINT}${RESET}"
  else
    step "Installing SDKman to ${DIM}$SDKMAN_DIR${RESET}..."
    [[ -d "$SDKMAN_DIR" && -z "$(ls -A "$SDKMAN_DIR")" ]] && rm -rf "$SDKMAN_DIR"
    export SDKMAN_DIR
    local installer_log
    installer_log="$(curl -s "https://get.sdkman.io" | bash 2>&1)" \
      && echo "$installer_log" >> "$BOOTSTRAP_LOG" \
      || { echo "$installer_log" >> "$BOOTSTRAP_LOG"; warn "SDKman installer failed — check $BOOTSTRAP_LOG"; return 1; }
    ok "SDKman installed"
  fi

  set +u
  # shellcheck source=/dev/null
  source "$SDKMAN_DIR/bin/sdkman-init.sh"
  set -u
}

# ─────────────────────────────────────────────
# Summary: install Zulu JDK 25 via SDKman if confirmed by user
# State key: module_04_java_jdk (complete|skipped)
# ─────────────────────────────────────────────
_install_java_lts() {
  local state_key="module_04_java_jdk"

  if state_is "$state_key" "complete"; then
    skip "Java $(java --version 2>/dev/null | head -1 || echo 'Zulu 25')  ${DIM}${_REINSTALL_HINT}${RESET}"
    return 0
  fi

  if ! _confirm "Install JDK 25 (Zulu)?"; then
    warn "JDK skipped"
    state_set "$state_key" "skipped"
    return 0
  fi

  step "Installing Java LTS ${DIM}(Zulu 25.0.3.fx via SDKman)${RESET}..."
  sdk install java 25.0.3.fx-zulu
  ok "Java $(java --version 2>/dev/null | head -1)"
  state_set "$state_key" "complete"
}

# ─────────────────────────────────────────────
# Summary: install Maven via SDKman if confirmed by user
# State key: module_04_java_maven (complete|skipped)
# ─────────────────────────────────────────────
_install_maven() {
  local state_key="module_04_java_maven"

  if state_is "$state_key" "complete"; then
    skip "Maven $(mvn --version 2>/dev/null | head -1 || echo 'installed')  ${DIM}${_REINSTALL_HINT}${RESET}"
    return 0
  fi

  if ! _confirm "Install Maven?"; then
    warn "Maven skipped"
    state_set "$state_key" "skipped"
    return 0
  fi

  step "Installing Maven..."
  sdk install maven
  ok "Maven $(mvn --version 2>/dev/null | head -1)"
  state_set "$state_key" "complete"
}

# ─────────────────────────────────────────────
# Summary: install Gradle via SDKman if confirmed by user
# State key: module_04_java_gradle (complete|skipped)
# ─────────────────────────────────────────────
_install_gradle() {
  local state_key="module_04_java_gradle"

  if state_is "$state_key" "complete"; then
    skip "Gradle $(gradle --version 2>/dev/null | grep '^Gradle' || echo 'installed')  ${DIM}${_REINSTALL_HINT}${RESET}"
    return 0
  fi

  if ! _confirm "Install Gradle?"; then
    warn "Gradle skipped"
    state_set "$state_key" "skipped"
    return 0
  fi

  step "Installing Gradle..."
  sdk install gradle
  ok "Gradle $(gradle --version 2>/dev/null | grep '^Gradle' || echo 'installed')"
  state_set "$state_key" "complete"
}

# ─────────────────────────────────────────────
# Summary: create GRADLE_USER_HOME directory
# ─────────────────────────────────────────────
_configure_gradle() {
  step "Configuring GRADLE_USER_HOME → ${DIM}$GRADLE_USER_HOME${RESET}"
  mkdir -p "$GRADLE_USER_HOME"
}

# ─────────────────────────────────────────────
# Summary: create Maven local repository directory
# ─────────────────────────────────────────────
_configure_maven() {
  step "Configuring Maven local repository → ${DIM}$MAVEN_LOCAL_REPO${RESET}"
  mkdir -p "$MAVEN_LOCAL_REPO"
  mkdir -p "$HOME/.m2"
}
