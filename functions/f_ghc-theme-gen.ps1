# Generate themes.
function f_ghc-theme-gen {
  $script_path = "$env:XDG_CONFIG_HOME\guanghechen\config\theme\gen_themes.mjs"
  if (Test-Path -Path $script_path) {
    node "$script_path"
  } else {
    Write-Host "Cannot find the script file: $script_path." -ForegroundColor Red
  }
}
