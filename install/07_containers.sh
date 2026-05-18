#!/usr/bin/env bash
# ============================================================
# 07_containers.sh — Podman
# ============================================================

install_containers() {
  echo "[containers] Configuring container runtime..."

  if has podman; then
    echo "[containers] Podman already installed: $(podman --version)"
    return 0
  fi

  echo "[containers] Installing Podman..."
  case "$PLATFORM" in
    wsl2)
      pkg_install podman
      ;;
    silverblue)
      # Podman já faz parte da imagem base do Silverblue
      echo "[containers] On Silverblue, Podman is part of the base image."
      echo "[containers] If missing, run: rpm-ostree install podman && systemctl reboot"
      ;;
    macos)
      brew install podman
      echo "[containers] Run 'podman machine init && podman machine start' to initialize"
      ;;
    linux)
      pkg_install podman
      ;;
  esac
}
