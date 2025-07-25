# Apply a given theme.
function ghc-theme-apply {
  $script_path = "$env:XDG_CONFIG_HOME\guanghechen\config\theme\apply_theme.mjs"
  if (Test-Path -Path $script_path) {
    $first_arg = if ($args -and $args.Count -gt 0) {
      $args[0].ToString().Trim() -replace '^\s+|\s+$', '' -replace '([A-Z])', { $_.Value.ToLower() }
    } else {
      ""
    }
    node $script_path $first_arg
  } else {
    Write-Host "Cannot find the script file: $script_path." -foregroundcolor Red
  }
}

# Toggle theme.
function ghc-theme-toggle {
  $script_path = "$env:XDG_CONFIG_HOME\guanghechen\config\theme\toggle_theme.mjs"
  if (Test-Path -Path $script_path) {
    $first_arg = if ($args -and $args.Count -gt 0) {
      $args[0].ToString().Trim() -replace '^\s+|\s+$', '' -replace '([A-Z])', { $_.Value.ToLower() }
    } else {
      ""
    }
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


