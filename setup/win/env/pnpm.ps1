if (Get-Command pnpm -ErrorAction SilentlyContinue) {
  Write-Host "  [setup pnpm] pnpm is already installed. (skipped)" -ForegroundColor Yellow
} else {
  Write-Host "  [setup pnpm] installing pnpm..." -ForegroundColor Cyan
  iwr https://get.pnpm.io/install.ps1 -useb | iex
}
