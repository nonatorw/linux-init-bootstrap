#!/usr/bin/env bash
# Phase 2 — WSL prerequisites entry point
# Run inside WSL: curl -fsSL <gist-url> | bash
set -euo pipefail

REPO="https://raw.githubusercontent.com/nonatorw/linux-init-bootstrap/main"
DEST="$HOME/Dev/repos/linux-init-bootstrap"

if [[ -d "$DEST/.git" ]]; then
  echo "Repo already cloned at $DEST — running setup-wsl.sh directly"
else
  echo "Cloning linux-init-bootstrap..."
  git clone https://github.com/nonatorw/linux-init-bootstrap.git "$DEST"
fi

bash "$DEST/setup-wsl.sh"
