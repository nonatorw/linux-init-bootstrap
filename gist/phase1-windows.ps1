# Phase 1 — Windows prerequisites entry point
# Paste this into a PowerShell window (no elevation needed).
# For admin setup (ssh-agent service), run the admin script separately.
#
# curl equivalent for PowerShell:
#   irm https://raw.githubusercontent.com/nonatorw/linux-init-bootstrap/main/gist/phase1-windows.ps1 | iex

$ErrorActionPreference = "Continue"
$repo = "https://raw.githubusercontent.com/nonatorw/linux-init-bootstrap/main"
$dest = "$env:TEMP\linux-init-bootstrap"

New-Item -ItemType Directory -Force -Path $dest | Out-Null

Write-Host "Downloading setup-windows.ps1..." -ForegroundColor Cyan
Invoke-WebRequest "$repo/setup-windows.ps1" -OutFile "$dest\setup-windows.ps1"

Write-Host "Downloading setup-windows-admin.ps1..." -ForegroundColor Cyan
Invoke-WebRequest "$repo/setup-windows-admin.ps1" -OutFile "$dest\setup-windows-admin.ps1"

Write-Host ""
Write-Host "Running non-admin prerequisite checks..." -ForegroundColor Cyan
& powershell.exe -NonInteractive -ExecutionPolicy Bypass -File "$dest\setup-windows.ps1"

Write-Host ""
Write-Host "Admin script saved to: $dest\setup-windows-admin.ps1" -ForegroundColor Yellow
Write-Host "Run it from an elevated PowerShell to configure ssh-agent and OpenSSH." -ForegroundColor Yellow
