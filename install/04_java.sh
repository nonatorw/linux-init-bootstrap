#!/usr/bin/env bash
# ============================================================
# 04_java.sh — SDKman + Java LTS (Zulu 25.0.3.fx) + Maven + Gradle
# ============================================================

# Capture original env values before overriding paths
_ORIG_SDKMAN_DIR="${SDKMAN_DIR:-}"

# Always use the paths defined by this script, ignoring external env vars
SDKMAN_DIR="$HOME/Dev/tools/java/sdkman"
GRADLE_USER_HOME="$HOME/Dev/tools/java/gradle"
MAVEN_LOCAL_REPO="$HOME/Dev/tools/java/m2"

install_java() {
  step_header "${_BOOTSTRAP_STEP_N}" "${_BOOTSTRAP_STEP_TOTAL}" \
    "Java" "SDKman · Zulu JDK 25 · Maven · Gradle"

  _install_sdkman

  # sdk and its internal scripts use optional positional parameters ($3, etc.)
  # that become unbound in bash with set -u; disable temporarily for all sdk calls
  set +u
  _install_java_lts
  _install_maven
  _install_gradle
  set -u
  _configure_gradle
  _configure_maven
}

_install_sdkman() {
  # Remove non-standard installations before installing.
  # sdk is a shell function — there is no root subcommand. The official mechanism is
  # the $SDKMAN_DIR env var, set automatically when sourcing sdkman-init.sh.
  # If bootstrap runs from a session with sdkman already loaded (via .zshrc),
  # $SDKMAN_DIR will already be in the environment — captured in $_ORIG_SDKMAN_DIR.
  # Historical default path (~/.sdkman) is also checked.
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
    # Remove empty directory to prevent false detection by the installer
    [[ -d "$SDKMAN_DIR" && -z "$(ls -A "$SDKMAN_DIR")" ]] && rm -rf "$SDKMAN_DIR"
    export SDKMAN_DIR
    curl -s "https://get.sdkman.io" | bash
    ok "SDKman installed"
  fi

  # Load SDKman into the current session.
  # sdkman-init.sh uses optional variables (ZSH_VERSION, etc.) that may be unbound
  # in bash; disable -u temporarily to avoid failure
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
  # GRADLE_USER_HOME is exported via dev_configs.sh — nothing else needed here
}

_configure_maven() {
  step "Configuring Maven local repository → ${DIM}$MAVEN_LOCAL_REPO${RESET}"
  mkdir -p "$MAVEN_LOCAL_REPO"
  mkdir -p "$HOME/.m2"
  # settings.xml is deployed by chezmoi-dotfiles via chezmoi apply
  # MAVEN_OPTS with -Dmaven.repo.local is exported via dev_configs.sh
}
