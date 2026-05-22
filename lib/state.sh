#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# lib/state.sh
# Bootstrap state tracking via ~/.bootstrap-state.
# Format: key=value (one per line, pure bash — no jq dependency).
# Values: complete | failed | in_progress | skipped
# Module keys: module_00_packages … module_07_containers
# Phase keys:  phase_windows | phase_wsl | phase_tools | phase_dotfiles
# ─────────────────────────────────────────────────────────────────────────────

STATE_FILE="$HOME/.bootstrap-state"

# ─────────────────────────────────────────────
# Summary: create the state file if it does not exist
# ─────────────────────────────────────────────
state_init() { touch "$STATE_FILE"; }

# ─────────────────────────────────────────────
# Summary: read the value for a state key
# Args:    $1 — key name
# Outputs: value string on stdout; empty string if key not found
# ─────────────────────────────────────────────
state_get() {
  grep -m1 "^${1}=" "$STATE_FILE" 2>/dev/null | cut -d= -f2- | tr -d '\r'
}

# ─────────────────────────────────────────────
# Summary: write or replace a key/value pair in the state file
# Args:    $1 — key name, $2 — value
# ─────────────────────────────────────────────
state_set() {
  sed -i "/^${1}=/d" "$STATE_FILE" 2>/dev/null || true
  echo "${1}=${2}" >> "$STATE_FILE"
}

# ─────────────────────────────────────────────
# Summary: test whether a key matches an expected value
# Args:    $1 — key name, $2 — expected value
# Returns: 0 if match, 1 if not
# ─────────────────────────────────────────────
state_is() {
  [[ "$(state_get "$1")" == "$2" ]]
}

# ─────────────────────────────────────────────
# Summary: remove a key and its value from the state file
# Args:    $1 — key name
# ─────────────────────────────────────────────
state_unset() {
  sed -i "/^${1}=/d" "$STATE_FILE" 2>/dev/null || true
}
