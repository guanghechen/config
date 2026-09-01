if (Get-Command bun -ErrorAction SilentlyContinue) {
  Write-Host "Bun is already installed (skipped)" -ForegroundColor Yellow
} else {
  Write-Host "installing Bun..." -ForegroundColor Cyan
  irm bun.sh/install.ps1 | iex
}
