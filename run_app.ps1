# Frontend-first Palm Destiny runner (no backend required).
# Loads OpenRouter key from .secrets/openrouter.key

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $root

$keyFile = Join-Path $root '.secrets\openrouter.key'
if (-not (Test-Path $keyFile)) {
  Write-Host "Missing $keyFile"
  Write-Host "Create it with your OpenRouter key (one line), or the app will use offline demo mode."
  flutter run @args
  exit $LASTEXITCODE
}

$key = (Get-Content $keyFile -Raw).Trim()
if ([string]::IsNullOrWhiteSpace($key)) {
  Write-Host "OpenRouter key file is empty. Running offline demo mode."
  flutter run @args
  exit $LASTEXITCODE
}

$device = 'windows'
if ($args.Count -gt 0) {
  flutter run `
    --dart-define=ANALYSIS_MODE=openrouter `
    --dart-define=OPENROUTER_API_KEY=$key `
    --dart-define=OPENROUTER_MODEL=google/gemma-4-26b-a4b-it:free `
    @args
} else {
  flutter run -d $device `
    --dart-define=ANALYSIS_MODE=openrouter `
    --dart-define=OPENROUTER_API_KEY=$key `
    --dart-define=OPENROUTER_MODEL=google/gemma-4-26b-a4b-it:free
}
