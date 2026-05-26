#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# Phase 2 — Linux prerequisites entry point
# Downloads and runs setup/phase2-setup-prereqs-linux.sh (standalone — no repo
# clone needed). Run on any Linux system before phase3-setup-bootstrap.sh
# (WSL2 or standalone).
#
# Run inside WSL or Linux:
#   curl -fsSL https://raw.githubusercontent.com/nonatorw/linux-init-bootstrap/main/gist/linux-init-phase2-linux-prereqs.sh | bash
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

RAW="https://raw.githubusercontent.com/nonatorw/linux-init-bootstrap/main"
DEST="$(mktemp -d)"

echo "  → Downloading setup/phase2-setup-prereqs-linux.sh..."
curl -fsSL "$RAW/setup/phase2-setup-prereqs-linux.sh" -o "$DEST/phase2-setup-prereqs-linux.sh"

bash "$DEST/phase2-setup-prereqs-linux.sh"
