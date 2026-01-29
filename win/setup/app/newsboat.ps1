$newsboat_config_dir = Join-Path $env:XDG_CONFIG_HOME "newsboat"
if (Test-Path $newsboat_config_dir) {
  $newsboat_platform_link = Join-Path $newsboat_config_dir "local\platform"
  $newsboat_platform_dir = Join-Path $newsboat_config_dir "conf\platform"
  $newsboat_local_dir = Join-Path $newsboat_config_dir "local"

  if (-not (Test-Path $newsboat_local_dir)) {
    New-Item -ItemType Directory -Path $newsboat_local_dir -Force | Out-Null
  }

  $newsboat_platform_source = Join-Path $newsboat_platform_dir "win"
  if (Test-Path $newsboat_platform_source) {
    Write-Host "  [setup newsboat] setting up platform symlink (win)..." -ForegroundColor Cyan
    if (Test-Path $newsboat_platform_link) {
      Remove-Item $newsboat_platform_link -Force
    }
    New-Item -ItemType SymbolicLink -Path $newsboat_platform_link -Target $newsboat_platform_source -Force | Out-Null
  }
}
