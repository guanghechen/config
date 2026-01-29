if (Get-Command bun -ErrorAction SilentlyContinue) {
  Write-Host "  [setup bun] bun is already installed, upgrading..." -ForegroundColor Cyan
  bun upgrade
} else {
  Write-Host "  [setup bun] installing bun..." -ForegroundColor Cyan
  irm bun.sh/install.ps1 | iex
}
