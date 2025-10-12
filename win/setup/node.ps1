if (fnm list | Select-String -Quiet "v20") {
  Write-Host "  [setup node] node@20 is already installed. (skipped)" -ForegroundColor Yellow
} else {
  fnm install $env:PREFER_NODE_VERSION
  fnm use $env:PREFER_NODE_VERSION
  npm install -g npm bun pm2 yarn prettier
  npm install -g @anthropic-ai/claude-code @google/gemini-cli
}

fnm use $env:PREFER_NODE_VERSION

# Setup ora
$ora_repopath = Join-Path "$env:XDG_CONFIG_HOME" "ora"
if (Test-Path $ora_repopath) {
    Write-Host "  [setup node] setup ora..." -ForegroundColor Cyan
    pwsh -Command "cd '$ora_repopath'; yarn install"
}

# Setup yoz
$yoz_repopath = Join-Path "$env:XDG_CONFIG_HOME" "yoz"
if (Test-Path $yoz_repopath) {
    Write-Host "  [setup node] setup yoz..." -ForegroundColor Cyan
    pwsh -Command "cd '$yoz_repopath'; yarn install"
}
