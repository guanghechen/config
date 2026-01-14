if (fnm list | Select-String -Quiet "v20") {
  Write-Host "`n  [setup config] reload theme..." -ForegroundColor Cyan
  node "$env:XDG_CONFIG_HOME\guanghechen\config\theme\apply_theme.mjs"
}
