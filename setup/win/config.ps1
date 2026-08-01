Write-Host "`n  [setup config] preparing..." -ForegroundColor Cyan

$repomain = Join-Path $env:USERPROFILE ".config\guanghechen"

# Define the source and destination paths
Write-Host "  [setup config] copying pwsh profile.ps1..." -ForegroundColor Cyan
$source = "$env:XDG_CONFIG_HOME\pwsh\profile.ps1"
$profileDir = Split-Path -Parent $PROFILE
New-Item -ItemType Directory -Path $profileDir -Force -ErrorAction Stop | Out-Null
Copy-Item -Path $source -Destination $PROFILE -Force -ErrorAction Stop

# Setup git
$gitconfig_path = Join-Path "$env:USERPROFILE" ".gitconfig"
if (Test-Path $gitconfig_path) {
  Write-Host "  [setup config] .gitconfig already exists. (skipped)" -ForegroundColor Yellow
} else {
  Write-Host "  [setup config] copying .gitconfig..." -ForegroundColor Cyan
  $source = Join-Path $repomain "asset\conf\.gitconfig"
  $target = $gitconfig_path
  Copy-Item -Path $source -Destination $target -Force
}

# Setup rust
$cargo_config_path = Join-Path "$env:USERPROFILE" ".cargo\config.toml"
if (Test-Path $cargo_config_path) {
  Write-Host "  [setup config] cargo config already exists. (skipped)" -ForegroundColor Yellow
} else {
  Write-Host "  [setup config] copying cargo.toml..." -ForegroundColor Cyan
  $source = Join-Path $repomain "asset\conf\cargo.toml"
  $target = $cargo_config_path
  Copy-Item -Path $source -Destination $target -Force
}

Write-Host "  [setup config] done." -ForegroundColor Green
