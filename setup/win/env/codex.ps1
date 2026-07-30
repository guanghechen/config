if (-not (Test-Path -LiteralPath $env:CODEX_HOME -PathType Container)) {
  throw "[setup codex] CODEX_HOME does not exist: $env:CODEX_HOME"
}

Write-Host "  [setup codex] installing or updating Codex..." -ForegroundColor Cyan
irm https://chatgpt.com/codex/install.ps1 | iex
