#!/usr/bin/env bash
# Phase 3 — Main bootstrap entry point
# Run inside WSL: curl -fsSL <gist-url> | bash
# Accepts all bootstrap.sh flags, e.g.: curl ... | bash -s -- --clean-install
set -euo pipefail

DEST="$HOME/Dev/repos/linux-init-bootstrap"

if [[ -d "$DEST/.git" ]]; then
  echo "Repo already cloned at $DEST"
else
  echo "Cloning linux-init-bootstrap..."
  git clone https://github.com/nonatorw/linux-init-bootstrap.git "$DEST"
fi

bash "$DEST/bootstrap.sh" "$@"
