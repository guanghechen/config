# Theme management CLI
function ghc-theme {
  $script_path = "$env:XDG_CONFIG_HOME\guanghechen\cli\theme.mjs"
  if (Test-Path -Path $script_path) {
    node $script_path @args
  } else {
    Write-Host "  Cannot find $script_path." -ForegroundColor Red
    return 1
  }
}
