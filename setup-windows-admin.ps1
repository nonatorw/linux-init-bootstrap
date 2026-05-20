# ============================================================
# setup-windows-admin.ps1 — Phase 1: Windows prerequisites (admin)
# ============================================================
#
# Run this ONCE from an elevated PowerShell before running bootstrap.sh.
# Right-click PowerShell -> "Run as Administrator", then:
#
#   Set-ExecutionPolicy Bypass -Scope Process -Force
#   .\setup-windows-admin.ps1
#
# What this does:
#   1. Enables the Windows OpenSSH client optional feature (installs ssh.exe)
#   2. Disables the Windows ssh-agent service — 1Password manages the SSH agent
#      pipe (\\.\pipe\openssh-ssh-agent) directly; the native service conflicts

#Requires -RunAsAdministrator

$ErrorActionPreference = "Stop"

function Write-Step  { param($msg) Write-Host "  -> $msg" -ForegroundColor Cyan }
function Write-Ok    { param($msg) Write-Host "  OK $msg" -ForegroundColor Green }
function Write-Skip  { param($msg) Write-Host "  -- $msg (already configured)" -ForegroundColor DarkGray }
function Write-Warn  { param($msg) Write-Host "  !! $msg" -ForegroundColor Yellow }
function Write-Header { param($msg)
  Write-Host ""
  Write-Host "*==========================================================================*" -ForegroundColor Magenta
  Write-Host "*  $msg" -ForegroundColor Magenta
  Write-Host "*==========================================================================*" -ForegroundColor Magenta
}

Write-Header "Phase 1 — Windows prerequisites (admin)"

# ---------------------------------------------------------------------------
# 1. Windows OpenSSH client feature
# ---------------------------------------------------------------------------
Write-Step "Checking Windows OpenSSH client feature..."
$sshFeature = Get-WindowsCapability -Online -Name "OpenSSH.Client*" -ErrorAction SilentlyContinue
if ($sshFeature -and $sshFeature.State -eq "Installed") {
  Write-Skip "OpenSSH client already installed"
} else {
  Write-Step "Installing OpenSSH client feature..."
  Add-WindowsCapability -Online -Name "OpenSSH.Client~~~~0.0.1.0"
  Write-Ok "OpenSSH client installed"
}

# ---------------------------------------------------------------------------
# 2. ssh-agent service: disable — 1Password manages the agent pipe directly
# ---------------------------------------------------------------------------
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

# ---------------------------------------------------------------------------
# Done
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "  Admin prerequisites configured." -ForegroundColor Green
Write-Host "  Next steps:" -ForegroundColor Cyan
Write-Host "    1. Open 1Password -> Settings -> Developer:" -ForegroundColor Cyan
Write-Host "         - Enable 'Use the SSH agent'" -ForegroundColor Cyan
Write-Host "         - Enable 'Integrate with 1Password CLI'" -ForegroundColor Cyan
Write-Host "    2. Ensure your SSH key is stored as a native SSH Key item in 1Password" -ForegroundColor Cyan
Write-Host "         (New Item -> SSH Key -> import private key file)" -ForegroundColor Cyan
Write-Host "    3. Run setup-windows.ps1 to verify all prerequisites are met" -ForegroundColor Cyan
Write-Host "    4. Open WSL and run: bash bootstrap.sh" -ForegroundColor Cyan
Write-Host ""
