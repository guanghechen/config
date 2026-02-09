if (fnm list | Select-String -Quiet "v20") {
  Write-Host "`n  [setup config] reload theme..." -ForegroundColor Cyan
  $repomain = Join-Path $env:USERPROFILE ".config\guanghechen"
  node "$repomain\cli\theme.mjs" apply
}
