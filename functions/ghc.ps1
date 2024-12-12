# Apply a given theme.
function ghc-theme-apply {
  $script_path = "$env:XDG_CONFIG_HOME\guanghechen\config\theme\apply_theme.mjs"
  if (Test-Path -Path $script_path) {
    $first_arg = $args.Trim() -replace '^\s+|\s+$', '' -replace '([A-Z])', { $_.Value.ToLower() }
    node $script_path $first_arg
  } else {
    Write-Host "Cannot find the script file: $script_path." -foregroundcolor Red
  }
}

# Generate themes.
function ghc-theme-gen {
  $script_path = "$env:XDG_CONFIG_HOME\guanghechen\config\theme\gen_themes.mjs"
  if (Test-Path -Path $script_path) {
    node "$script_path"
  } else {
    Write-Host "Cannot find the script file: $script_path." -foregroundcolor Red
  }
}

# Upgrade dev env.
function ghc-upgrade {
  pwsh "$env:XDG_CONFIG_HOME\guanghechen\win\setup.ps1"
}

