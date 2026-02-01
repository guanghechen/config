# Apply a given theme.
function ghc-theme-apply {
  $script_path = "$env:XDG_CONFIG_HOME\guanghechen\cli\theme-apply.mjs"
  if (Test-Path -Path $script_path) {
    $first_arg = if ($args -and $args.Count -gt 0) {
      $args[0].ToString().Trim() -replace '^\s+|\s+$', '' -replace '([A-Z])', { $_.Value.ToLower() }
    } else {
      ""
    }
    node $script_path $first_arg
  } else {
    Write-Host "  Cannot find $script_path." -ForegroundColor Red
  }
}
