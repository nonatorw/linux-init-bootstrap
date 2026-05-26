#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# Phase 3 — Tool install + dotfiles entry point
# Clones the full repo (required — phase3-setup-bootstrap.sh sources lib/ and install/)
# then runs setup/phase3-setup-bootstrap.sh. All flags are forwarded.
#
# Run inside WSL or native Linux:
#   curl -fsSL https://raw.githubusercontent.com/nonatorw/linux-init-bootstrap/main/gist/linux-init-phase3-bootstrap.sh | bash
#   # with flags:
#   curl -fsSL ... | bash -s -- --verbose
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

DEST="$HOME/Dev/repos/linux-init-bootstrap"

if [[ -d "$DEST/.git" ]]; then
  echo "  → Repo already cloned at $DEST"
else
  echo "  → Cloning linux-init-bootstrap..."
  git clone https://github.com/nonatorw/linux-init-bootstrap.git "$DEST"
fi

bash "$DEST/setup/phase3-setup-bootstrap.sh" "$@"
