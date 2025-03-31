if (fnm list | Select-String -Quiet "v20") {
  $THEME = if ($env:GUANGHECHEN_PREFER_THEME) { $env:GUANGHECHEN_PREFER_THEME } else { "catppuccin-mocha" }
  Write-Host "[setup config] set default theme ($THEME)..." -ForegroundColor DarkBlue
  node "$env:XDG_CONFIG_HOME\guanghechen\config\theme\apply_theme.mjs" $THEME
}
