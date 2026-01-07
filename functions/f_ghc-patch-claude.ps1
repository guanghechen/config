# Patch Claude Code with custom modifications
function f_ghc-patch-claude {
  $scriptDir = Join-Path $env:XDG_CONFIG_HOME "claude/script"
  $scripts = @("limit-128k.mjs", "image-paste.mjs")

  # Check if claude is installed
  if (-not (Get-Command claude -ErrorAction SilentlyContinue)) {
    Write-Host "❌ Claude Code not installed" -ForegroundColor Red
    return
  }

  # Run each patch script
  foreach ($script in $scripts) {
    $scriptPath = Join-Path $scriptDir $script
    if (-not (Test-Path $scriptPath)) {
      Write-Host "⚠ Script not found: $script" -ForegroundColor Yellow
      continue
    }
    Write-Host "→ Running $script" -ForegroundColor Blue
    node $scriptPath
    Write-Host
  }
}
