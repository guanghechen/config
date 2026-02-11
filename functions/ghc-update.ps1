function ghc-update {
  $script_path = Join-Path $env:XDG_CONFIG_HOME "guanghechen/cli/sync-xdg-config.mjs"
  if (Test-Path $script_path) {
    node $script_path
  } else {
    Write-Host " Cannot find $script_path." -ForegroundColor Red
  }
}
