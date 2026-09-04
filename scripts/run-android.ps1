Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "  Launching Zero-Trace P2P Android Application" -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Cyan

Set-Location "$PSScriptRoot\..\client-mobile"

Write-Host "Checking connected Android devices & emulators..." -ForegroundColor Yellow
flutter devices

Write-Host "`nLaunching app on target device (Hot-Reload Enabled)..." -ForegroundColor Yellow
flutter run
