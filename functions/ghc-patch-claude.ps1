# Patch Claude Code with custom modifications
function ghc-patch-claude {
  if (-not (Get-Command claude -ErrorAction SilentlyContinue)) {
    Write-Host "  Claude Code not installed" -ForegroundColor Red
    return
  }

  $scriptDir = Join-Path $env:XDG_CONFIG_HOME "claude/script"
  Write-Host "  cd $scriptDir && bun src/patch/index.ts" -ForegroundColor Cyan
  Push-Location $scriptDir
  try {
    bun src/patch/index.ts
  } finally {
    Pop-Location
  }
}
