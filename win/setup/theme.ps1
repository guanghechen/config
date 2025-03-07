if (fnm list | Select-String -Quiet "v20") {
  Write-Host "[setup config] set default theme..." -ForegroundColor DarkBlue
  node "$env:XDG_CONFIG_HOME\guanghechen\config\theme\apply_theme.mjs" catppuccin-mocha
}
