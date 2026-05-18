#!/usr/bin/env bash
# ============================================================
# 07_containers.sh — Podman
# ============================================================

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
      # Podman já faz parte da imagem base do Silverblue
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
