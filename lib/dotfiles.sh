#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# lib/dotfiles.sh
# Dotfile management helpers: SSH signing key resolution and chezmoi apply.
# Depends on lib/state.sh (state_get, state_set) and lib/output.sh.
# ─────────────────────────────────────────────────────────────────────────────

# ─────────────────────────────────────────────
# Summary: resolve the SSH signing key from state cache or the 1Password agent
# Outputs: signing key public string on stdout; all prompts written to stderr
# Returns: 0 on success, 1 if cancelled or no key available
# ─────────────────────────────────────────────
_resolve_signing_key() {
  # All UI output goes to stderr — stdout is reserved for the key value only.

  # 1. Already captured by setup-windows.ps1 or a previous run
  local cached
  cached="$(state_get "signing_key")"
  if [[ -n "$cached" ]]; then
    ok "signing_key loaded from state file" >&2
    echo "$cached"
    return 0
  fi

  # 2. Try to read from the SSH agent (1Password via ssh-add / ssh-add.exe)
  local ssh_add_bin="ssh-add"
  if [[ "$PLATFORM" == "wsl2" ]]; then
    if command -v ssh-add.exe &>/dev/null; then
      ssh_add_bin="ssh-add.exe"
    else
      warn "Windows interop not available — ssh-add.exe not found" >&2
      warn "Run setup-windows.ps1 from PowerShell to capture the signing key, then re-run bootstrap" >&2
      return 1
    fi
  fi

  local -a keys=()
  local key_count=0

  while true; do
    local raw
    raw="$("$ssh_add_bin" -L 2>/dev/null)" || raw=""
    mapfile -t keys < <(echo "$raw" | tr -d '\r' | grep -E "^(sk-)?(ssh-|ecdsa-)" || true)
    key_count="${#keys[@]}"

    if [[ "$key_count" -gt 0 ]]; then
      break
    fi

    warn "No SSH keys found in 1Password agent." >&2
    echo "" >&2
    info "Configure 1Password Desktop before continuing:" >&2
    info "  1. Open 1Password → Settings → Developer" >&2
    info "       - Enable 'Use the SSH agent'" >&2
    info "       - Enable 'Integrate with 1Password CLI'" >&2
    info "  2. Your SSH key must be a native SSH Key item" >&2
    info "       (New Item → SSH Key → import private key file)" >&2
    echo "" >&2
    printf "  [R]etry / [C]ancel: " >&2
    local choice
    read -r choice </dev/tty
    if [[ "$choice" =~ ^[Cc] ]]; then
      warn "Cancelled by user — dotfiles not applied" >&2
      warn "Re-run bootstrap after configuring 1Password SSH agent: bash bootstrap.sh" >&2
      return 1
    elif [[ ! "$choice" =~ ^[Rr] ]]; then
      warn "Invalid choice — enter R to retry or C to cancel." >&2
    fi
  done

  local signing_key
  if [[ "$key_count" -eq 1 ]]; then
    signing_key="${keys[0]}"
    ok "SSH signing key detected automatically" >&2
  else
    echo "" >&2
    info "Multiple SSH keys found — select the signing key:" >&2
    local i
    for (( i=0; i<key_count; i++ )); do
      printf "    [%d] %.70s...\n" $(( i+1 )) "${keys[$i]}" >&2
    done
    echo "" >&2
    local sel
    while true; do
      printf "  Enter number (1-%d) or [C]ancel: " "$key_count" >&2
      read -r sel </dev/tty
      if [[ "$sel" =~ ^[Cc] ]]; then
        warn "Cancelled by user — dotfiles not applied" >&2
        warn "Re-run bootstrap after selecting a signing key: bash bootstrap.sh" >&2
        return 1
      fi
      if [[ "$sel" =~ ^[0-9]+$ ]] && (( sel >= 1 && sel <= key_count )); then
        signing_key="${keys[$(( sel-1 ))]}"
        break
      fi
      warn "Invalid selection — enter a number between 1 and $key_count, or C to cancel" >&2
    done
    ok "SSH signing key selected" >&2
  fi

  state_set "signing_key" "$signing_key"
  echo "$signing_key"
}

# ─────────────────────────────────────────────
# Summary: clone chezmoi-dotfiles and apply dotfiles via chezmoi
# Returns: 0 on success, 1 if clone or apply fails
# ─────────────────────────────────────────────
_apply_dotfiles() {
  # Clone uses HTTPS (no auth required for public repo) because the SSH agent
  # is not yet active at this point in the bootstrap. It becomes available
  # after the first terminal restart via the aliases defined in aliases.sh.
  local repo="https://github.com/nonatorw/chezmoi-dotfiles.git"
  local dest="$HOME/Dev/repos/chezmoi-dotfiles"
  local chezmoi_bin
  chezmoi_bin="$(command -v chezmoi 2>/dev/null || echo "$HOME/.local/bin/chezmoi")"

  section_header "Dotfiles"

  if [[ -d "$dest/.git" ]]; then
    skip "chezmoi-dotfiles  ${DIM}($dest)${RESET}"
  else
    step "Cloning chezmoi-dotfiles to ${DIM}$dest${RESET}..."
    if ! GIT_CONFIG_NOSYSTEM=1 HOME=/tmp git clone "$repo" "$dest"; then
      warn "Failed to clone $repo"
      warn "Check: repo exists and is public, or run manually: git clone $repo $dest"
      return 1
    fi
    ok "chezmoi-dotfiles cloned"
  fi

  local toml="$HOME/.config/chezmoi/chezmoi.toml"
  if [[ -f "$toml" ]]; then
    # Validate that the toml is readable by chezmoi before skipping init
    if "$chezmoi_bin" cat-config >/dev/null 2>&1; then
      skip "chezmoi.toml already exists — skipping init"
      step "Applying dotfiles..."
      if ! "$chezmoi_bin" apply --force; then
        warn "chezmoi apply failed — dotfiles may be partially applied"
        warn "Run manually: $chezmoi_bin apply --force"
        return 1
      fi
      ok "Dotfiles applied"
      return 0
    else
      warn "chezmoi.toml exists but is invalid — regenerating"
      rm -f "$toml"
    fi
  fi

  # chezmoi.toml does not exist — resolve signing key, write toml, then apply
  step "Resolving SSH signing key..."
  local signing_key
  if ! signing_key="$(_resolve_signing_key)"; then
    warn "SSH signing key not resolved — dotfiles not applied"
    warn "Fix 1Password SSH agent setup and re-run: bash bootstrap.sh"
    return 1
  fi

  # Write chezmoi.toml with signingKey before init so promptStringOnce finds it
  # and does not prompt the user interactively.
  mkdir -p "$HOME/.config/chezmoi"
  cat > "$toml" <<EOF
sourceDir = "$dest"

[data]
  signingKey = "$signing_key"
EOF
  ok "chezmoi.toml created with signingKey"

  step "Applying dotfiles (source: ${DIM}$dest${RESET})..."
  if ! "$chezmoi_bin" apply --force; then
    warn "chezmoi apply failed — dotfiles may be partially applied"
    warn "Run manually: $chezmoi_bin apply --force"
    return 1
  fi
  ok "Dotfiles applied"
}
