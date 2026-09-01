if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
  throw "[setup config] node is unavailable; cannot reload theme."
}

Write-Host "reloading theme..." -ForegroundColor Cyan
$repomain = Join-Path $env:USERPROFILE ".config\guanghechen"
node "$repomain\cli\theme.mjs" apply
if ($LASTEXITCODE -ne 0) {
  throw "[setup config] failed to reload theme (exit code: $LASTEXITCODE)."
}
