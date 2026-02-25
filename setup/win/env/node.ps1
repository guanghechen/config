if (fnm list | Select-String -Quiet "v$env:GHC_APP_EDITION_NODE") {
  Write-Host "`n  [setup node] node@$env:GHC_APP_EDITION_NODE is already installed. (skipped)" -ForegroundColor Yellow
} else {
  Write-Host "`n  [setup node] installing node@$env:GHC_APP_EDITION_NODE..." -ForegroundColor Cyan
  fnm install $env:GHC_APP_EDITION_NODE
}

fnm use $env:GHC_APP_EDITION_NODE
fnm default $env:GHC_APP_EDITION_NODE

Write-Host "  [setup node] installing npm pm2 yarn prettier" -ForegroundColor Cyan
npm install -g npm pm2 yarn prettier

Write-Host "  [setup node] installing @guanghechen/kit" -ForegroundColor Cyan
npm install -g @guanghechen/kit

## Setup agents
foreach ($pkg in @("@anthropic-ai/claude-code", "@google/gemini-cli", "@openai/codex", "@github/copilot")) {
  if (npm list -g $pkg 2>$null) {
    Write-Host "  [setup node] $pkg is already installed. (skipped)" -ForegroundColor Yellow
  } else {
    Write-Host "  [setup node] installing $pkg..." -ForegroundColor Cyan
    npm install -g $pkg
  }
}

