Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "  Starting Zero-Trace P2P Development Environment" -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Cyan

# Start Signaling Server in background job
Write-Host "[1/2] Launching Blind Signaling Server on port 8080..." -ForegroundColor Yellow
Start-Process powershell -ArgumentList "-NoExit", "-Command", "cd '$PSScriptRoot\..\signaling-server'; npm run dev"

# Start Web Client
Write-Host "[2/2] Launching Web Client on http://localhost:3000..." -ForegroundColor Yellow
Set-Location "$PSScriptRoot\..\client-web"
npm run dev
