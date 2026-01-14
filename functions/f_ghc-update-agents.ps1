# Update AI coding agents globally
function f_ghc-update-agents {
  Write-Host "Updating AI coding agents..." -ForegroundColor Cyan
  npm install -g @anthropic-ai/claude-code @google/gemini-cli @openai/codex @github/copilot

  Write-Host "Patching Claude Code..." -ForegroundColor Cyan
  ghc-patch-claude
}
