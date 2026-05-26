# ─────────────────────────────────────────────────────────────────────────────
# setup/phase1-setup-windows-admin.ps1 — Phase 1: Windows prerequisites (admin)
# Run ONCE from an elevated PowerShell before setup/phase3-setup-bootstrap.sh.
#   Set-ExecutionPolicy Bypass -Scope Process -Force
#   .\setup\phase1-setup-windows-admin.ps1
# Enables OpenSSH client feature (ssh.exe) and disables the Windows ssh-agent
# service — 1Password manages the SSH agent pipe directly; the native service
# conflicts.
# ─────────────────────────────────────────────────────────────────────────────

#Requires -RunAsAdministrator

$ErrorActionPreference = "Stop"

$WinLog = "$env:USERPROFILE\linux-init-bootstrap_win.log"

# ─────────────────────────────────────────────
# Summary: append a structured log line to the Windows log file
# Args:    $Level — log level label; $Msg — message text
# ─────────────────────────────────────────────
function Write-Log {
  param([string]$Level, [string]$Msg)
  $ts  = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss.ffffff")
  $pid = $PID
  $caller = (Get-PSCallStack)[1].FunctionName
  $line = "[$ts - $pid - $caller] $Level  $Msg"
  Add-Content -Path $WinLog -Value $line -Encoding UTF8
}

# Output helpers — symbols and colours match the bash side
function Write-Step  { param($msg) Write-Log "STEP" $msg;    Write-Host "  `u{2192} $msg" -ForegroundColor Blue }
function Write-Ok    { param($msg) Write-Log "OK" $msg;      Write-Host "  `u{2713} installed        $msg" -ForegroundColor Green }
function Write-Skip  { param($msg) Write-Log "SKIP" $msg;    Write-Host "  `u{2299} already installed  $msg" -ForegroundColor DarkGreen }
function Write-Warn  { param($msg) Write-Log "WARN" $msg;    Write-Host "  `u{26A0} $msg" -ForegroundColor Yellow }
function Write-Err   { param($msg) Write-Log "ERROR" $msg;   Write-Host "  `u{2716} $msg" -ForegroundColor Red }
function Write-Header { param($msg)
  Write-Log "HEADER" $msg
  $line = [string]::new([char]0x2501, 73)
  Write-Host ""
  Write-Host $line -ForegroundColor Magenta
  Write-Host "  $msg" -ForegroundColor Magenta
  Write-Host $line -ForegroundColor Magenta
}

Write-Header "Phase 1 — Windows prerequisites (admin)"

# 1. Windows OpenSSH client feature
Write-Step "Checking Windows OpenSSH client feature..."
$sshFeature = Get-WindowsCapability -Online -Name "OpenSSH.Client*" -ErrorAction SilentlyContinue
if ($sshFeature -and $sshFeature.State -eq "Installed") {
  Write-Skip "OpenSSH client already installed"
} else {
  Write-Step "Installing OpenSSH client feature..."
  Add-WindowsCapability -Online -Name "OpenSSH.Client~~~~0.0.1.0"
  Write-Ok "OpenSSH client installed"
}

# 2. ssh-agent service — disable; 1Password manages the agent pipe directly
Write-Step "Disabling Windows ssh-agent service (1Password manages the agent)..."
$sshAgent = Get-Service -Name ssh-agent -ErrorAction SilentlyContinue
if (-not $sshAgent) {
  Write-Skip "ssh-agent service not found — nothing to disable"
} else {
  if ($sshAgent.Status -eq "Running") {
    Stop-Service -Name ssh-agent -Force
    Write-Ok "ssh-agent service stopped"
  }
  if ($sshAgent.StartType -ne "Disabled") {
    Set-Service -Name ssh-agent -StartupType Disabled
    Write-Ok "ssh-agent service disabled"
  } else {
    Write-Skip "ssh-agent already disabled"
  }
}

Write-Host ""
Write-Ok "Admin prerequisites configured."
Write-Info "Next steps:"
Write-Info "  1. Open 1Password -> Settings -> Developer:"
Write-Info "       - Enable 'Use the SSH agent'"
Write-Info "       - Enable 'Integrate with 1Password CLI'"
Write-Info "  2. Ensure your SSH key is stored as a native SSH Key item in 1Password"
Write-Info "       (New Item -> SSH Key -> import private key file)"
Write-Info "  3. Run setup/phase1-setup-windows.ps1 to verify all prerequisites are met"
Write-Info "  4. Open WSL and run: bash setup/phase3-setup-bootstrap.sh"
Write-Host ""
