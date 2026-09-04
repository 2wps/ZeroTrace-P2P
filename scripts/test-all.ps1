Write-Host "Running All Zero-Trace P2P Test Suites..." -ForegroundColor Cyan

Write-Host "`n[1] Testing Core Crypto Engine..." -ForegroundColor Yellow
Set-Location "$PSScriptRoot\..\core-crypto"
npm test

Write-Host "`n[2] Testing Signaling Server..." -ForegroundColor Yellow
Set-Location "$PSScriptRoot\..\signaling-server"
npm test

Write-Host "`n==========================================" -ForegroundColor Green
Write-Host "All Tests Completed Successfully!" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
