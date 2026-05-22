#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# install/07_containers.sh
# Container tooling: Podman (platform-aware).
# ─────────────────────────────────────────────────────────────────────────────

# ─────────────────────────────────────────────
# Summary: install Podman — pkg_install on Linux/WSL2, informational on Silverblue, brew on macOS
# ─────────────────────────────────────────────
install_containers() {
  step_header "${_BOOTSTRAP_STEP_N}" "${_BOOTSTRAP_STEP_TOTAL}" \
    "Containers" "Podman"

  if has podman; then
    skip "$(podman --version)"
    return 0
  fi

  step "Installing Podman ${DIM}(platform: $PLATFORM)${RESET}..."
  case "$PLATFORM" in
    wsl2|linux)
      pkg_install podman
      ok "$(podman --version)"
      ;;
    silverblue)
      # Podman is already part of the Silverblue base image
      warn "On Silverblue, Podman is part of the base image."
      warn "If missing: ${DIM}rpm-ostree install podman && systemctl reboot${RESET}"
      ;;
    macos)
      brew install podman
      ok "$(podman --version)"
      step "Run ${DIM}podman machine init && podman machine start${RESET} to initialize the VM"
      ;;
  esac
}
