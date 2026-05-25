#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# Phase 2 — LOCAL VALIDATION VERSION (do not publish to Gist)
# Uses setup-prereqs-linux.sh from the local repo instead of downloading.
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "  → Using setup-prereqs-linux.sh from local repo..."
bash "$REPO_ROOT/setup-prereqs-linux.sh"
