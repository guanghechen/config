if (fnm list | Select-String -Quiet "v$env:PREFER_NODE_VERSION") {
  Write-Host "  [setup node] node@$env:PREFER_NODE_VERSION is already installed. (skipped)" -ForegroundColor Yellow
} else {
  Write-Host "  [setup node] installing node@$env:PREFER_NODE_VERSION..." -ForegroundColor Blue
  fnm install $env:PREFER_NODE_VERSION
}

fnm use $env:PREFER_NODE_VERSION
fnm default $env:PREFER_NODE_VERSION

Write-Host "  [setup node] installing npm bun pm2 yarn prettier" -ForegroundColor Blue
npm install -g npm bun pm2 yarn prettier

Write-Host "  [setup node] installing @anthropic-ai/claude-code @google/gemini-cli @openai/codex @github/copilot" -ForegroundColor Blue
npm install -g @anthropic-ai/claude-code @google/gemini-cli @openai/codex @github/copilot

# Setup ora
$ora_repopath = Join-Path "$env:XDG_CONFIG_HOME" "ora"
if (Test-Path $ora_repopath) {
    Write-Host "  [setup node] setup ora..." -ForegroundColor Blue
    pwsh -Command "cd '$ora_repopath'; yarn install"
}

# Setup yoz
$yoz_repopath = Join-Path "$env:XDG_CONFIG_HOME" "yoz"
if (Test-Path $yoz_repopath) {
    Write-Host "  [setup node] setup yoz..." -ForegroundColor Blue
    pwsh -Command "cd '$yoz_repopath'; yarn install"
}
