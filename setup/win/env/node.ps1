if (fnm list | Select-String -Quiet "v$env:PREFER_NODE_VERSION") {
  Write-Host "`n  [setup node] node@$env:PREFER_NODE_VERSION is already installed. (skipped)" -ForegroundColor Yellow
} else {
  Write-Host "`n  [setup node] installing node@$env:PREFER_NODE_VERSION..." -ForegroundColor Cyan
  fnm install $env:PREFER_NODE_VERSION
}

fnm use $env:PREFER_NODE_VERSION
fnm default $env:PREFER_NODE_VERSION

Write-Host "  [setup node] installing npm pm2 yarn prettier" -ForegroundColor Cyan
npm install -g npm pm2 yarn prettier

Write-Host "  [setup node] installing kit" -ForegroundColor Cyan
npm install -g @guanghechen/kit @guanghechen/kit-copilot @guanghechen/kit-copy @guanghechen/kit-file @guanghechen/kit-paste @guanghechen/kit-pm

## Setup agents
foreach ($pkg in @("@anthropic-ai/claude-code", "@google/gemini-cli", "@openai/codex", "@github/copilot")) {
  if (npm list -g $pkg 2>$null) {
    Write-Host "  [setup node] $pkg is already installed. (skipped)" -ForegroundColor Yellow
  } else {
    Write-Host "  [setup node] installing $pkg..." -ForegroundColor Cyan
    npm install -g $pkg
  }
}

# Setup ora
$ora_repopath = Join-Path "$env:XDG_CONFIG_HOME" "ora"
if (Test-Path $ora_repopath) {
    Write-Host "  [setup node] setup ora..." -ForegroundColor Cyan
    pwsh -Command "cd '$ora_repopath'; yarn install"
}

# Setup yoz
$yoz_repopath = Join-Path "$env:XDG_CONFIG_HOME" "yoz"
if (Test-Path $yoz_repopath) {
    Write-Host "  [setup node] setup yoz..." -ForegroundColor Cyan
    pwsh -Command "cd '$yoz_repopath'; yarn install"
}
