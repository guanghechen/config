if (-not (Test-Path -LiteralPath $env:CODEX_HOME -PathType Container)) {
  throw "[setup codex] CODEX_HOME does not exist: $env:CODEX_HOME"
}

Write-Host "  [setup codex] installing or updating Codex..." -ForegroundColor Cyan
$codexNonInteractive = $env:CODEX_NON_INTERACTIVE
try {
  $env:CODEX_NON_INTERACTIVE = "1"
  irm https://chatgpt.com/codex/install.ps1 | iex
} finally {
  if ($null -eq $codexNonInteractive) {
    Remove-Item Env:CODEX_NON_INTERACTIVE -ErrorAction SilentlyContinue
  } else {
    $env:CODEX_NON_INTERACTIVE = $codexNonInteractive
  }
}
