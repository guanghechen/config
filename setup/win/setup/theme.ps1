if (fnm list | Select-String -Quiet "v20") {
  Write-Host "`n  [setup config] reload theme..." -ForegroundColor Cyan
  if (-not $env:GHC_CONFIG_ROOT) {
    $env:GHC_CONFIG_ROOT = Join-Path $env:XDG_CONFIG_HOME "guanghechen"
  }
  node "$env:GHC_CONFIG_ROOT\cli\theme-apply.mjs"
}
