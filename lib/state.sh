#!/usr/bin/env bash
# ============================================================
# lib/state.sh — bootstrap state tracking (~/.bootstrap-state)
# ============================================================
#
# State file format: key=value (one per line, pure bash — no jq dependency)
# Values: complete | failed | in_progress | skipped
#
# Module keys:   module_00_packages, module_01_shell, …, module_07_containers
# Phase keys:    phase_windows, phase_wsl, phase_tools, phase_dotfiles

STATE_FILE="$HOME/.bootstrap-state"

state_init() { touch "$STATE_FILE"; }

state_get() {
  grep -m1 "^${1}=" "$STATE_FILE" 2>/dev/null | cut -d= -f2- | tr -d '\r'
}

state_set() {
  sed -i "/^${1}=/d" "$STATE_FILE" 2>/dev/null || true
  echo "${1}=${2}" >> "$STATE_FILE"
}

state_is() {
  [[ "$(state_get "$1")" == "$2" ]]
}
