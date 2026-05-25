#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# lib/output.sh
# Colour definitions, log-file setup, and all output helper functions used by
# bootstrap.sh and every install/ module.
# ─────────────────────────────────────────────────────────────────────────────

BOOTSTRAP_LOG="${BOOTSTRAP_LOG:-$HOME/.linux-init-bootstrap.log}"
VERBOSE="${VERBOSE:-false}"

# ─────────────────────────────────────────────
# Summary: build a log-line prefix with timestamp, PID, and caller function name
# Outputs: prefix string on stdout
# ─────────────────────────────────────────────
_log_prefix() {
  printf '[%s - %s - %s]' "$(date '+%Y-%m-%d %H:%M:%S.%6N')" "$$" "${FUNCNAME[2]:-bootstrap}"
}

# ─────────────────────────────────────────────
# Summary: run an external command, always appending stdout+stderr to BOOTSTRAP_LOG
# Args:    $1 — human label shown in the verbose block header; $2+ — command and arguments
# Outputs: delimited block to terminal when VERBOSE=true; always written to log
# ─────────────────────────────────────────────
run_cmd() {
  local label="$1"; shift
  local ts_prefix
  ts_prefix="$(_log_prefix)"
  {
    echo ""
    echo "${ts_prefix} run_cmd: ${label}"
    echo "${ts_prefix} cmd: $*"
  } >> "$BOOTSTRAP_LOG"

  if [[ "$VERBOSE" == "true" ]]; then
    echo -e "  ${DIM}┌─ ${label} $(printf '%.0s─' $(seq 1 $(( 44 - ${#label} ))))${RESET}"
    "$@" 2>&1 | tee -a "$BOOTSTRAP_LOG" | sed 's/^/  │ /'
    echo -e "  ${DIM}└$(printf '%.0s─' {1..50})${RESET}"
  else
    "$@" >> "$BOOTSTRAP_LOG" 2>&1
  fi
}

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BLUE='\033[0;34m'
BOLD='\033[1m'
DIM='\033[2m'
RESET='\033[0m'

# ─────────────────────────────────────────────
# Summary: print a top-level section header with ━━━ border lines in magenta
# Args:    $1 — title text
# ─────────────────────────────────────────────
section_header() {
  local title="$1"
  local line
  line="$(printf '%.0s━' {1..73})"
  echo -e ""
  echo -e "${MAGENTA}${line}${RESET}"
  echo -e "${MAGENTA}  ${title}${RESET}"
  echo -e "${MAGENTA}${line}${RESET}"
}

# ─────────────────────────────────────────────
# Summary: print a subsection header — [N/M] Title · tools — with a ─── underline in cyan
# Args:    $1 — step number, $2 — total steps, $3 — title, $4 — tool list string
# ─────────────────────────────────────────────
step_header() {
  local n="$1" total="$2" title="$3" tools="$4"
  local first_line="  [${n}/${total}] ${title}  ·  ${tools}"
  local line_len=${#first_line}
  local underline
  underline="  $(printf '%.0s─' $(seq 1 $(( line_len - 2 ))))"
  echo -e ""
  echo -e "${CYAN}${first_line}${RESET}"
  echo -e "${CYAN}${underline}${RESET}"
}

# ─────────────────────────────────────────────
# Summary: append a prefixed log entry to BOOTSTRAP_LOG
# Args:    $* — message text
# ─────────────────────────────────────────────
_log() { echo "$(_log_prefix) $*" >> "$BOOTSTRAP_LOG"; }

info()    { _log "INFO    $*";  echo -e "  ${CYAN}ℹ${RESET}  $*"; }
step()    { _log "STEP    $*";  echo -e "  ${BLUE}→${RESET} $*"; }
ok()      { _log "OK      $*";  echo -e "  ${GREEN}✓${RESET} installed        $*"; }
skip()    { _log "SKIP    $*";  echo -e "  ${DIM}${GREEN}⊙${RESET}${DIM} already installed  $*${RESET}"; }
warn()    { _log "WARN    $*";  echo -e "  ${YELLOW}⚠${RESET} $*"; }
error()   { _log "ERROR   $*";  echo -e "  ${RED}✖${RESET} $*"; exit 1; }
success() { _log "SUCCESS $*";  echo -e "\n${GREEN}${BOLD}✔  $*${RESET}"; }

# ─────────────────────────────────────────────
# Summary: prompt user for Y/n confirmation; returns 0 on Y/Enter, 1 on n
# In non-interactive mode (no TTY on stdin), defaults to Y without prompting.
# Args: $1 — prompt text (without the [Y/n] suffix)
# ─────────────────────────────────────────────
_confirm() {
  local prompt="$1"
  _log "CONFIRM $prompt"
  if ! { true </dev/tty; } 2>/dev/null; then
    echo -e "  ${BLUE}→${RESET} ${prompt} ${DIM}[Y/n] — non-interactive, defaulting to Y${RESET}"
    return 0
  fi
  printf "  %s [Y/n]: " "$prompt"
  local reply
  read -r reply </dev/tty
  _log "CONFIRM reply: ${reply:-<enter>}"
  [[ -z "$reply" || "$reply" =~ ^[Yy] ]]
}
