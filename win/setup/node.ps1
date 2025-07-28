if (fnm list | Select-String -Quiet "v20") {
  Write-Host "[setup node] node@20 is already installed. (skipped)" -ForegroundColor DarkYellow
} else {
  fnm install 20
  npm install -g npm bun pm2 yarn prettier
  npm install -g @anthropic-ai/claude-code @google/gemini-cli
}

# Setup yozora
$yozora_repopath = Join-Path "$env:XDG_CONFIG_HOME" "yozora"
if (Test-Path $yozora_repopath) {
    Write-Host "[setup node] setup yozora..." -ForegroundColor DarkBlue
    pwsh -Command "cd '$yozora_repopath'; yarn install"
}
