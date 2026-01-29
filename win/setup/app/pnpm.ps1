if (Get-Command pnpm -ErrorAction SilentlyContinue) {
  Write-Host "  [setup pnpm] pnpm is already installed, upgrading..." -ForegroundColor Cyan
  pnpm self-update
} else {
  Write-Host "  [setup pnpm] installing pnpm..." -ForegroundColor Cyan
  iwr https://get.pnpm.io/install.ps1 -useb | iex
}
