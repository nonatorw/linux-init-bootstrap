# ─────────────────────────────────────────────────────────────────────────────
# Phase 1 — LOCAL VALIDATION VERSION (do not publish to Gist)
# Uses scripts from the local repo instead of downloading from GitHub.
#
# Optional parameter:
#   -LogDest <path>   Copy the Windows-side log to this file after the run.
#                     If omitted, the log stays at %USERPROFILE%\linux-init-bootstrap_win.log.
# ─────────────────────────────────────────────────────────────────────────────
param([string]$LogDest = "")

$ErrorActionPreference = "Continue"
$repoRoot = Split-Path -Parent $PSScriptRoot
$dest = "$env:TEMP\linux-init-bootstrap"

New-Item -ItemType Directory -Force -Path $dest | Out-Null

Write-Host "  → Copying setup/phase1-setup-windows.ps1 from local repo..." -ForegroundColor Blue
Copy-Item "$repoRoot\setup\phase1-setup-windows.ps1" -Destination "$dest\phase1-setup-windows.ps1" -Force

Write-Host "  → Copying setup/phase1-setup-windows-admin.ps1 from local repo..." -ForegroundColor Blue
Copy-Item "$repoRoot\setup\phase1-setup-windows-admin.ps1" -Destination "$dest\phase1-setup-windows-admin.ps1" -Force

Write-Host ""
powershell.exe -ExecutionPolicy Bypass -File "$dest\phase1-setup-windows.ps1"

Write-Host ""
Write-Host "  ⚠ Admin script saved to: $dest\phase1-setup-windows-admin.ps1" -ForegroundColor Yellow
Write-Host "    Run it from an elevated PowerShell to configure OpenSSH and disable ssh-agent:" -ForegroundColor Yellow
Write-Host "      Set-ExecutionPolicy Bypass -Scope Process -Force" -ForegroundColor DarkGray
Write-Host "      & '$dest\phase1-setup-windows-admin.ps1'" -ForegroundColor DarkGray

# Copy Windows-side log to LogDest if requested
$winLog = "$env:USERPROFILE\linux-init-bootstrap_win.log"
if ($LogDest -ne "" -and (Test-Path $winLog)) {
    Copy-Item $winLog -Destination $LogDest -Force
    Write-Host ""
    Write-Host "  → Windows log copied to: $LogDest" -ForegroundColor DarkGray
}
