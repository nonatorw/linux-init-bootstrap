#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# lib/ssh.sh
# SSH host-key setup helper — populates ~/.ssh/known_hosts before any git
# operation so clone calls are not interrupted by host-key prompts.
# ─────────────────────────────────────────────────────────────────────────────

# ─────────────────────────────────────────────
# Summary: fetch ed25519 host keys for GitHub, GitLab, and Bitbucket into ~/.ssh/known_hosts
# Returns: 0 always
# ─────────────────────────────────────────────
_setup_ssh_known_hosts() {
  local hosts=("github.com" "gitlab.com" "bitbucket.org")
  local known="$HOME/.ssh/known_hosts"
  local added=0

  for host in "${hosts[@]}"; do
    if grep -q "^$host " "$known" 2>/dev/null; then
      skip "known_hosts: $host"
    else
      step "Fetching host key for $host..."
      ssh-keyscan -t ed25519 "$host" >> "$known" 2>/dev/null || true
      ok "known_hosts: $host"
      (( added++ )) || true
    fi
  done

  [[ $added -gt 0 ]] && chmod 600 "$known"
  return 0
}
