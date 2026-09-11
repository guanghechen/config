Write-Host "preparing Windows configuration..." -ForegroundColor Cyan

$repomain = Join-Path $env:USERPROFILE ".config\guanghechen"

# Define the source and destination paths
Write-Host "copying pwsh profile.ps1..." -ForegroundColor Cyan
$source = "$env:XDG_CONFIG_HOME\pwsh\profile.ps1"
$profileDir = Split-Path -Parent $PROFILE
New-Item -ItemType Directory -Path $profileDir -Force -ErrorAction Stop | Out-Null
Copy-Item -Path $source -Destination $PROFILE -Force -ErrorAction Stop

# Setup git
$gitconfig_path = Join-Path "$env:USERPROFILE" ".gitconfig"
if (Test-Path $gitconfig_path) {
  Write-Host ".gitconfig already exists (skipped)" -ForegroundColor Yellow
} else {
  Write-Host "copying .gitconfig..." -ForegroundColor Cyan
  $source = Join-Path $repomain "asset\conf\.gitconfig"
  $target = $gitconfig_path
  Copy-Item -Path $source -Destination $target -Force
}

# Setup npm
$npmrc_config_home = if ($env:XDG_CONFIG_HOME) { $env:XDG_CONFIG_HOME } else { Join-Path $env:USERPROFILE ".config" }
$npmrc_source = Join-Path $env:USERPROFILE ".npmrc"
$npmrc_path = Join-Path $npmrc_config_home ".npmrc"
if ($null -ne (Get-Item -LiteralPath $npmrc_path -Force -ErrorAction SilentlyContinue)) {
  Write-Host "$npmrc_path already exists (skipped)" -ForegroundColor Yellow
} elseif (-not (Test-Path -LiteralPath $npmrc_source -PathType Leaf)) {
  Write-Host "$npmrc_source is missing or not a file (skipped copy)" -ForegroundColor Yellow
} else {
  Write-Host "copying $npmrc_source to $npmrc_path..." -ForegroundColor Cyan
  New-Item -ItemType Directory -Path $npmrc_config_home -Force -ErrorAction Stop | Out-Null
  Copy-Item -LiteralPath $npmrc_source -Destination $npmrc_path -ErrorAction Stop
}

# Setup rust
$cargo_config_path = Join-Path "$env:USERPROFILE" ".cargo\config.toml"
if (Test-Path $cargo_config_path) {
  Write-Host "cargo config already exists (skipped)" -ForegroundColor Yellow
} else {
  Write-Host "copying cargo.toml..." -ForegroundColor Cyan
  $source = Join-Path $repomain "asset\conf\cargo.toml"
  $target = $cargo_config_path
  $cargo_config_dir = Split-Path -Parent $cargo_config_path
  New-Item -ItemType Directory -Path $cargo_config_dir -Force -ErrorAction Stop | Out-Null
  Copy-Item -Path $source -Destination $target -Force -ErrorAction Stop
}
