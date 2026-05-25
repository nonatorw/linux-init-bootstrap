#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# install/00_packages.sh
# Base system packages: build tools, zsh, eza, bat, jq, GitHub CLI.
# ─────────────────────────────────────────────────────────────────────────────

# ─────────────────────────────────────────────
# Summary: install base system packages (build tools, zsh, eza, bat, jq, gh CLI)
# ─────────────────────────────────────────────
install_packages() {
  step_header "${_BOOTSTRAP_STEP_N}" "${_BOOTSTRAP_STEP_TOTAL}" \
    "Packages" "build-essential · zsh · eza · bat · jq · gh"

  if [[ "$PKG_MANAGER" == "brew" ]]; then
    step "Ensuring Homebrew is available..."
    ensure_brew
    ok "Homebrew ready"
  fi

  if [[ "$PKG_MANAGER" == "apt" ]]; then
    step "Updating apt package index..."
    run_cmd "apt update" sudo apt update -y
    step "Installing build dependencies and base tools..."
    pkg_install build-essential  \
                curl             \
                git              \
                libssl-dev       \
                zlib1g-dev       \
                libbz2-dev       \
                libreadline-dev  \
                libsqlite3-dev   \
                libncursesw5-dev \
                xz-utils         \
                tk-dev           \
                libxml2-dev      \
                libxmlsec1-dev   \
                libffi-dev       \
                liblzma-dev      \
                eza              \
                bat              \
                jq               \
                unzip            \
                zip
  elif [[ "$PKG_MANAGER" == "dnf" ]]; then
    step "Upgrading system packages..."
    run_cmd "dnf5 check-upgrade" sudo dnf5 check-upgrade || true
    run_cmd "dnf5 upgrade" sudo dnf5 upgrade -y
    step "Installing system tool groups..."
    run_cmd "dnf5 group install" sudo dnf5 group install -y system-tools admin-tools
    step "Installing build dependencies and base tools..."
    pkg_install gcc             \
                make            \
                patch           \
                gawk            \
                curl            \
                git             \
                zlib-devel      \
                bzip2           \
                bzip2-devel     \
                readline-devel  \
                sqlite          \
                sqlite-devel    \
                openssl-devel   \
                tk-devel        \
                libffi-devel    \
                xz-devel        \
                libuuid-devel   \
                gdbm-libs       \
                eza             \
                bat             \
                jq              \
                unzip           \
                zip
  else
    step "Installing base tools via Homebrew..."
    pkg_install curl            \
                git             \
                openssl         \
                readline        \
                sqlite3         \
                xz              \
                libyaml         \
                eza             \
                bat             \
                jq              \
                unzip           \
                zip
  fi
  ok "Base packages installed"

  _install_gh

  # Locale: ensure en_US.UTF-8 is generated — required by .zshrc which exports LC_ALL=en_US.UTF-8
  if [[ "$PKG_MANAGER" == "apt" ]]; then
    if locale -a 2>/dev/null | grep -q "en_US.utf8"; then
      skip "locale en_US.UTF-8"
    else
      step "Generating locale en_US.UTF-8..."
      sudo locale-gen en_US.UTF-8
      sudo update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8
      ok "Locale en_US.UTF-8 generated"
    fi
  fi

  # zsh: install and set as default shell only if needed.
  # Compare by binary name — avoids false negative when $SHELL and
  # command -v zsh point to different paths for the same executable.
  local zsh_path
  zsh_path="$(command -v zsh 2>/dev/null || true)"

  local current_shell
  current_shell="$(getent passwd "$USER" | cut -d: -f7)"
  if [[ -n "$zsh_path" && "$current_shell" == "$zsh_path" ]]; then
    skip "$(zsh --version)"
  else
    if [[ -z "$zsh_path" ]]; then
      step "Installing zsh..."
      pkg_install zsh
      zsh_path="$(command -v zsh)"
      ok "zsh installed: $(zsh --version)"
    fi
    step "Setting zsh as default shell..."
    grep -qxF "$zsh_path" /etc/shells || echo "$zsh_path" | sudo tee -a /etc/shells
    while true; do
      if chsh -s "$zsh_path"; then
        ok "Default shell set to $zsh_path ${DIM}(restart terminal to apply)${RESET}"
        break
      fi
      warn "chsh failed (wrong password or PAM error)"
      printf "  [R]etry / [S]kip (set shell manually later): "
      local choice
      read -r choice </dev/tty
      case "$choice" in
        [Rr]) ;;
        [Ss]) warn "Skipping — set default shell manually: chsh -s $zsh_path"; break ;;
        *)    warn "Invalid choice — enter R to retry or S to skip." ;;
      esac
    done
  fi
}

# ─────────────────────────────────────────────
# Summary: install GitHub CLI via the official apt/dnf repository or brew
# ─────────────────────────────────────────────
_install_gh() {
  if has gh; then
    skip "$(gh --version | head -1)"
    return 0
  fi

  case "$PKG_MANAGER" in
    apt)
      step "Adding GitHub CLI apt repository..."
      if [[ ! -f /etc/apt/sources.list.d/github-cli.list ]]; then
        sudo mkdir -p /usr/share/keyrings
        curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
          | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg >> "$BOOTSTRAP_LOG" 2>&1
        sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
          | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
        run_cmd "apt update" sudo apt update -y
      fi
      pkg_install gh
      ;;
    dnf)
      step "Adding GitHub CLI dnf repository..."
      if [[ ! -f /etc/yum.repos.d/gh-cli.repo ]]; then
        # dnf5 (Fedora 41+) changed config-manager syntax: --add-repo was removed.
        # Use addrepo --from-repofile= instead; fall back to legacy --add-repo for dnf4.
        if sudo dnf5 config-manager addrepo --from-repofile=https://cli.github.com/packages/rpm/gh-cli.repo 2>/dev/null \
          || sudo dnf config-manager --add-repo https://cli.github.com/packages/rpm/gh-cli.repo 2>/dev/null; then
          : # repo added
        else
          warn "Failed to add GitHub CLI repo — gh may not install correctly"
        fi
      fi
      pkg_install gh
      ;;
    brew)
      pkg_install gh
      ;;
  esac
  ok "$(gh --version | head -1)"
}
