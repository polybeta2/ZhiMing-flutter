$ErrorActionPreference = 'Stop'
$env:PATH = "D:\flutter\bin;$env:PATH"

$ProjectRoot = Split-Path -Parent $PSScriptRoot
Push-Location $ProjectRoot
try {
  Write-Host "Launching 织命 in Windows iOS Preview mode (IOS_PREVIEW=true)..." -ForegroundColor Cyan
  flutter run -d windows --dart-define=IOS_PREVIEW=true @args
}
finally {
  Pop-Location
}
