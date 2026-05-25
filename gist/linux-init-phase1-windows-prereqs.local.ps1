# ─────────────────────────────────────────────────────────────────────────────
# Phase 1 — LOCAL VALIDATION VERSION (do not publish to Gist)
# Uses scripts from the local repo instead of downloading from GitHub.
# ─────────────────────────────────────────────────────────────────────────────

$ErrorActionPreference = "Continue"
$repoRoot = Split-Path -Parent $PSScriptRoot
$dest = "$env:TEMP\linux-init-bootstrap"

New-Item -ItemType Directory -Force -Path $dest | Out-Null

Write-Host "  → Copying setup-windows.ps1 from local repo..." -ForegroundColor Blue
Copy-Item "$repoRoot\setup-windows.ps1" -Destination "$dest\setup-windows.ps1" -Force

Write-Host "  → Copying setup-windows-admin.ps1 from local repo..." -ForegroundColor Blue
Copy-Item "$repoRoot\setup-windows-admin.ps1" -Destination "$dest\setup-windows-admin.ps1" -Force

Write-Host ""
powershell.exe -ExecutionPolicy Bypass -File "$dest\setup-windows.ps1"

Write-Host ""
Write-Host "  ⚠ Admin script saved to: $dest\setup-windows-admin.ps1" -ForegroundColor Yellow
Write-Host "    Run it from an elevated PowerShell to configure OpenSSH and disable ssh-agent:" -ForegroundColor Yellow
Write-Host "      Set-ExecutionPolicy Bypass -Scope Process -Force" -ForegroundColor DarkGray
Write-Host "      & '$dest\setup-windows-admin.ps1'" -ForegroundColor DarkGray
