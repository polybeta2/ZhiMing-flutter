$ErrorActionPreference = 'Stop'
$env:PATH = "D:\flutter\bin;$env:PATH"

$ProjectRoot = Split-Path -Parent $PSScriptRoot
Push-Location $ProjectRoot
try {
  $ShotDir = Join-Path $ProjectRoot "build\ios_preview_shots"
  New-Item -ItemType Directory -Force -Path $ShotDir | Out-Null
  Write-Host "Capturing iOS preview screenshots into $ShotDir ..." -ForegroundColor Cyan
  flutter test test\ios_preview_test.dart --dart-define=CAPTURE_IOS_SHOTS=true --reporter expanded
  Write-Host "Done. Captured files:" -ForegroundColor Green
  Get-ChildItem $ShotDir -Filter "*.png" | ForEach-Object { Write-Host " - $($_.FullName)" }
}
finally {
  Pop-Location
}
