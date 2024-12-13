if (fnm list | Select-String -Quiet "v20") {
  Write-Host "[setup node] node@20 is already installed. (skipped)" -ForegroundColor DarkYellow
} else {
  fnm install 20
  npm install -g npm yarn
}
