# Patch Claude Code with custom modifications
function f_ghc-patch-claude {
  if (-not (Get-Command claude -ErrorAction SilentlyContinue)) {
    Write-Host "❌ Claude Code not installed" -ForegroundColor Red
    return
  }

  $scriptDir = Join-Path $env:XDG_CONFIG_HOME "claude/script"
  Write-Host "cd $scriptDir && bun src/patch/index.ts" -ForegroundColor Blue
  Push-Location $scriptDir
  try {
    bun src/patch/index.ts
  } finally {
    Pop-Location
  }
}
