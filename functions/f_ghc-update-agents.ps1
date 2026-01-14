# Update AI coding agents globally
function f_ghc-update-agents {
  $agents = @(
    "@anthropic-ai/claude-code"
    "@google/gemini-cli"
    "@openai/codex"
    "@github/copilot"
    "opencode-ai"
  )

  foreach ($agent in $agents) {
    Write-Host "  Installing $agent..." -ForegroundColor Cyan
    npm install -g $agent | Out-Null
    $pkg_ver = (npm list -g $agent --depth=0 2>$null | Select-String $agent) -replace '.*@', ''
    Write-Host "  $agent installed: v$pkg_ver`n" -ForegroundColor Green
  }

  Write-Host "  Patching Claude Code..." -ForegroundColor Cyan
  ghc-patch-claude
}
