# Generate themes.
function ghc-theme-gen {
  $script_path = "$env:XDG_CONFIG_HOME\guanghechen\cli\theme.mjs"
  if (Test-Path -Path $script_path) {
    node "$script_path" gen
  } else {
    Write-Host "  Cannot find $script_path." -ForegroundColor Red
  }
}
