# ─────────────────────────────────────────────────────────────────────────────
# Phase 1 — Windows prerequisites entry point
# Downloads and runs setup-windows.ps1 (non-admin checks + 1Password SSH key
# capture). Also saves setup-windows-admin.ps1 locally for the elevated step.
#
# Run from a normal PowerShell window:
#   $tmp = "$env:TEMP\linux-init-phase1.ps1"
#   Invoke-WebRequest "https://raw.githubusercontent.com/nonatorw/linux-init-bootstrap/main/gist/linux-init-phase1-windows-prereqs.ps1" -OutFile $tmp
#   powershell.exe -ExecutionPolicy Bypass -File $tmp
# ─────────────────────────────────────────────────────────────────────────────

$ErrorActionPreference = "Continue"
$raw = "https://raw.githubusercontent.com/nonatorw/linux-init-bootstrap/main"
$dest = "$env:TEMP\linux-init-bootstrap"

New-Item -ItemType Directory -Force -Path $dest | Out-Null

Write-Host "  → Downloading setup-windows.ps1..." -ForegroundColor Blue
Invoke-WebRequest "$raw/setup-windows.ps1" -OutFile "$dest\setup-windows.ps1"

Write-Host "  → Downloading setup-windows-admin.ps1..." -ForegroundColor Blue
Invoke-WebRequest "$raw/setup-windows-admin.ps1" -OutFile "$dest\setup-windows-admin.ps1"

Write-Host ""
powershell.exe -ExecutionPolicy Bypass -File "$dest\setup-windows.ps1"

Write-Host ""
Write-Host "  ⚠ Admin script saved to: $dest\setup-windows-admin.ps1" -ForegroundColor Yellow
Write-Host "    Run it from an elevated PowerShell to configure OpenSSH and disable ssh-agent:" -ForegroundColor Yellow
Write-Host "      Set-ExecutionPolicy Bypass -Scope Process -Force" -ForegroundColor DarkGray
Write-Host "      & '$dest\setup-windows-admin.ps1'" -ForegroundColor DarkGray
