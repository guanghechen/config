if (fnm list | Select-String -Quiet "v20") {
  Write-Host "[setup node] node@20 is already installed. (skipped)" -ForegroundColor DarkYellow
} else {
  fnm install 20
  npm install -g npm bun pm2 yarn prettier
}

# Setup yozora
Write-Host "[setup node] setup yozora..." -ForegroundColor DarkBlue
$yozora_repo_path = Join-Path $config_root_dir "yozora"
pwsh -Command "cd '$yozora_repo_path'; yarn install"
