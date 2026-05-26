#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# Phase 3 — LOCAL VALIDATION VERSION (do not publish to Gist)
# Uses setup/phase3-setup-bootstrap.sh from the local repo instead of cloning from GitHub.
# All flags are forwarded.
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "  → Using setup/phase3-setup-bootstrap.sh from local repo at $REPO_ROOT"
bash "$REPO_ROOT/setup/phase3-setup-bootstrap.sh" "$@"
