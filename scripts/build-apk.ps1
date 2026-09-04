Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "  Building Zero-Trace P2P Android APK" -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Cyan

Set-Location "$PSScriptRoot\..\client-mobile"

Write-Host "Building APK..." -ForegroundColor Yellow
flutter build apk --debug

Write-Host "`nAPK Generated at: d:\DEV\amr\client-mobile\build\app\outputs\flutter-apk\app-debug.apk" -ForegroundColor Green
