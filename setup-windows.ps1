# ─────────────────────────────────────────────────────────────────────────────
# setup-windows.ps1 — Phase 1: Windows prerequisites (non-admin)
# Auto-invoked by bootstrap.sh on WSL2. Can also be run manually from PowerShell:
#   powershell.exe -ExecutionPolicy Bypass -File setup-windows.ps1
# Does NOT require elevation. For admin prerequisites (ssh-agent), run
# setup-windows-admin.ps1 manually.
# ─────────────────────────────────────────────────────────────────────────────

param(
  [string]$StateFile = ""
)

$ErrorActionPreference = "Continue"

# ─────────────────────────────────────────────
# Summary: return $true if stdin is connected to an interactive console
# Used to guard Read-Host calls — throws a terminating exception under -NonInteractive
# ─────────────────────────────────────────────
function Test-Interactive {
  try { $null = [Console]::KeyAvailable; return $true } catch { return $false }
}

$WinLog = "$env:USERPROFILE\linux-init-bootstrap_win.log"

# ─────────────────────────────────────────────
# Summary: append a structured log line to the Windows log file
# Args:    $Level — log level label; $Msg — message text
# ─────────────────────────────────────────────
function Write-Log {
  param([string]$Level, [string]$Msg)
  $ts     = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss.ffffff")
  $procId = $PID
  $caller = (Get-PSCallStack)[1].FunctionName
  $line   = "[$ts - $procId - $caller] $Level  $Msg"
  Add-Content -Path $WinLog -Value $line -Encoding UTF8
}

# Output helpers — symbols and colours match the bash side
function Write-Step  { param($msg) Write-Log "STEP" $msg;    Write-Host "  $([char]0x2192) $msg" -ForegroundColor Blue }
function Write-Ok    { param($msg) Write-Log "OK" $msg;      Write-Host "  $([char]0x2713) installed        $msg" -ForegroundColor Green }
function Write-Skip  { param($msg) Write-Log "SKIP" $msg;    Write-Host "  $([char]0x2299) already installed  $msg" -ForegroundColor DarkGreen }
function Write-Warn  { param($msg) Write-Log "WARN" $msg;    Write-Host "  $([char]0x26A0) $msg" -ForegroundColor Yellow }
function Write-Info  { param($msg) Write-Log "INFO" $msg;    Write-Host "  $([char]0x2139)  $msg" -ForegroundColor Cyan }
function Write-Err   { param($msg) Write-Log "ERROR" $msg;   Write-Host "  $([char]0x2716) $msg" -ForegroundColor Red }
function Write-Header { param($msg)
  Write-Log "HEADER" $msg
  $line = [string]::new([char]0x2501, 73)
  Write-Host ""
  Write-Host $line -ForegroundColor Magenta
  Write-Host "  $msg" -ForegroundColor Magenta
  Write-Host $line -ForegroundColor Magenta
}

Write-Header "Phase 1 — Windows prerequisites (non-admin)"

$Issues = @()

# 1. winget availability
Write-Step "Checking winget..."
$winget = Get-Command winget -ErrorAction SilentlyContinue
if ($winget) {
  Write-Ok "winget available: $($winget.Source)"
} else {
  Write-Warn "winget not found — install 'App Installer' from the Microsoft Store"
  $Issues += "winget missing"
}

# 2. Windows OpenSSH client (ssh.exe)
Write-Step "Checking Windows OpenSSH client (ssh.exe)..."
$sshExe = Get-Command ssh.exe -ErrorAction SilentlyContinue
if ($sshExe) {
  Write-Ok "ssh.exe: $($sshExe.Source)"
} else {
  Write-Warn "ssh.exe not found — run setup-windows-admin.ps1 (as Administrator) to enable it"
  $Issues += "ssh.exe missing (requires admin — see setup-windows-admin.ps1)"
}

# 3. ssh-agent service — must be disabled; 1Password manages the agent pipe
Write-Step "Checking ssh-agent service is disabled..."
$sshAgent = Get-Service -Name ssh-agent -ErrorAction SilentlyContinue
if (-not $sshAgent) {
  Write-Ok "ssh-agent service not present"
} elseif ($sshAgent.StartType -eq "Disabled" -and $sshAgent.Status -ne "Running") {
  Write-Ok "ssh-agent service is disabled (correct — 1Password manages the agent)"
} else {
  Write-Warn "ssh-agent service is active — it may conflict with 1Password SSH agent"
  Write-Warn "Run setup-windows-admin.ps1 (as Administrator) to disable it"
  $Issues += "ssh-agent service active (requires admin — see setup-windows-admin.ps1)"
}

# 4. 1Password Desktop
Write-Step "Checking 1Password Desktop..."
$opExe = Get-Command op.exe -ErrorAction SilentlyContinue
$op1P  = Get-Command "1password.exe" -ErrorAction SilentlyContinue
if ($opExe -or $op1P) {
  Write-Ok "1Password CLI / Desktop found"
} else {
  $opPaths = @(
    "$env:LOCALAPPDATA\1Password\app\8\1password.exe",
    "${env:ProgramFiles}\1Password\app\8\1password.exe"
  )
  $found = $opPaths | Where-Object { Test-Path $_ }
  if ($found) {
    Write-Ok "1Password Desktop found: $($found[0])"
  } else {
    Write-Warn "1Password Desktop not found"
    Write-Warn "Download from: https://1password.com/downloads/"
    $Issues += "1Password Desktop not installed"
  }
}

# 5. 1Password SSH agent pipe (confirms agent is active)
Write-Step "Checking 1Password SSH agent pipe..."
$pipe = "\\.\pipe\openssh-ssh-agent"
if (Test-Path $pipe) {
  Write-Ok "1Password SSH agent pipe active"
} else {
  Write-Warn "1Password SSH agent pipe not found"
  Write-Warn "In 1Password -> Settings -> Developer:"
  Write-Warn "  - Enable 'Use the SSH agent'"
  Write-Warn "  - Enable 'Integrate with 1Password CLI'"
  $Issues += "1Password SSH agent not enabled"
}

# 6. Capture SSH signing keys from 1Password agent → write to bootstrap state
Write-Step "Capturing SSH keys from 1Password agent..."

# StateFile is passed as a Windows UNC path by bootstrap.sh (wslpath -w).
# If not provided (manual run), fall back to writing via wsl.exe default distro.
$stateFileWin = $StateFile

# ─────────────────────────────────────────────
# Summary: list public keys from the 1Password SSH agent via ssh-add.exe -L
# Returns: string[] of key lines, or empty array if agent is unavailable
# ─────────────────────────────────────────────
function Get-SshKeys {
  $raw = & ssh-add.exe -L 2>&1
  if ($LASTEXITCODE -ne 0 -or ($raw -join "") -match "error|could not") { return [string[]]@() }
  # Cast each match to string explicitly to avoid char-array collapse on single results
  [string[]]($raw | Where-Object { $_ -match "^(sk-)?(ssh-|ecdsa-)" })
}

$maxRetries = 3
$attempt    = 0
$keys       = @()

while ($attempt -lt $maxRetries) {
  $keys = @(Get-SshKeys)
  if ($keys.Count -gt 0) { break }

  $attempt++
  Write-Warn "No SSH keys found in 1Password agent (attempt $attempt/$maxRetries)"
  Write-Host ""
  Write-Info "Ensure 1Password Desktop is configured:"
  Write-Info "  1. Open 1Password -> Settings -> Developer"
  Write-Info "       - Enable 'Use the SSH agent'"
  Write-Info "       - Enable 'Integrate with 1Password CLI'"
  Write-Info "  2. Your SSH key must be stored as a native SSH Key item"
  Write-Info "       (New Item -> SSH Key -> import private key file)"
  Write-Host ""

  if ($attempt -ge $maxRetries) { break }

  $choice = Read-Host "  [R]etry / [C]ancel"
  if ($choice -notmatch "^[Rr]") {
    Write-Warn "Skipping SSH key capture — run bootstrap.sh to retry interactively"
    break
  }
}

# ─────────────────────────────────────────────
# Summary: write or replace a key=value entry in the bootstrap state file
# Args:    $Key — state key name; $Value — value to write
# ─────────────────────────────────────────────
function Write-StateKey {
  param([string]$Key, [string]$Value)
  if (-not $stateFileWin) {
    Write-Warn "StateFile path not provided — signing_key not persisted (bootstrap.sh will prompt)"
    return $false
  }
  if (-not (Test-Path $stateFileWin)) {
    Write-Warn "State file does not exist — signing_key not persisted (bootstrap.sh will prompt)"
    return $false
  }
  # Read existing lines (split by newline to avoid char-array issue), filter key, append new entry
  $existing = (Get-Content -Raw $stateFileWin) -split "`n" |
              ForEach-Object { $_.TrimEnd("`r") } |
              Where-Object { $_ -notmatch "^${Key}=" -and $_ -ne "" }
  $existing += "${Key}=${Value}"
  # Write without BOM — preserves Linux file ownership set by bootstrap.sh
  [System.IO.File]::WriteAllLines($stateFileWin, $existing, [System.Text.UTF8Encoding]::new($false))
  return $true
}

if ($keys.Count -eq 0) {
  Write-Warn "SSH signing key not captured — bootstrap.sh will prompt interactively"
} elseif ($keys.Count -eq 1) {
  $signingKey = [string]$keys[0]
  $preview = $signingKey.Substring(0, [Math]::Min(60, $signingKey.Length))
  Write-Ok "SSH signing key captured: $preview..."
  if (Write-StateKey "signing_key" $signingKey) {
    Write-Ok "signing_key written to bootstrap state"
  }
} else {
  Write-Host ""
  Write-Info "Multiple SSH keys found — select the signing key:"
  for ($i = 0; $i -lt $keys.Count; $i++) {
    $k = [string]$keys[$i]
    $preview = $k.Substring(0, [Math]::Min(60, $k.Length))
    Write-Host "    [$($i+1)] $preview..." -ForegroundColor White
  }
  Write-Host ""
  $signingKey = $null
  while ($true) {
    $sel = Read-Host "  Enter number (1-$($keys.Count)) or [C]ancel"
    if ($sel -match "^[Cc]") {
      Write-Warn "Cancelled — bootstrap.sh will prompt interactively"
      break
    }
    $idx = 0
    if ([int]::TryParse($sel, [ref]$idx)) {
      $idx = $idx - 1
      if ($idx -ge 0 -and $idx -lt $keys.Count) {
        $signingKey = [string]$keys[$idx]
        break
      }
    }
    Write-Warn "Invalid selection — enter a number between 1 and $($keys.Count), or C to cancel"
  }
  if ($signingKey) {
    if (Write-StateKey "signing_key" $signingKey) {
      Write-Ok "signing_key written to bootstrap state"
    }
  }
}

Write-Host ""
if ($Issues.Count -eq 0) {
  Write-Ok "All Windows prerequisites satisfied."
} else {
  Write-Warn "Action required before bootstrap will fully work:"
  foreach ($issue in $Issues) {
    Write-Warn "  - $issue"
  }
  Write-Host ""
  Write-Info "Admin items: run setup-windows-admin.ps1 from an elevated PowerShell."
}
Write-Host ""

# Exit 0 always — failures are warnings, not blockers for the WSL bootstrap
exit 0
