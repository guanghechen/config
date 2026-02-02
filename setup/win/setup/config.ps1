Write-Host "`n  [setup config] preparing..." -ForegroundColor Cyan

if (-not $env:GHC_CONFIG_ROOT) {
  $env:GHC_CONFIG_ROOT = Join-Path $env:XDG_CONFIG_HOME "guanghechen"
}
$repomain = $env:GHC_CONFIG_ROOT
Write-Host "  [setup config] syncing configs..." -ForegroundColor Cyan
node "$env:GHC_CONFIG_ROOT\cli\setting.mjs" --set-edition win
node "$env:GHC_CONFIG_ROOT\cli\sync-xdg-config.mjs"

# Define the source and destination paths
Write-Host "  [setup config] copying pwsh profile.ps1..." -ForegroundColor Cyan
$source = "$env:XDG_CONFIG_HOME\pwsh\profile.ps1"
Copy-Item -Path $source -Destination $PROFILE -Force

# Setup nvim
Write-Host "  [setup config] setup nvim..." -ForegroundColor Cyan
Set-Location -Path $repomain
. .\setup\win\setup\app\nvim.ps1

# Setup rust
$cargo_config_path = Join-Path "$env:USERPROFILE" ".cargo\config.toml"
if (Test-Path $cargo_config_path) {
  Write-Host "  [setup config] cargo config already exists. (skipped)" -ForegroundColor Yellow
} else {
  Write-Host "  [setup config] copying cargo.toml..." -ForegroundColor Cyan
  $source = Join-Path $env:GHC_CONFIG_ROOT "asset\conf\cargo.toml"
  $target = $cargo_config_path
  Copy-Item -Path $source -Destination $target -Force
}

Write-Host "  [setup config] done." -ForegroundColor Green
