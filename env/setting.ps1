# Default settings (checked in)
$env:GHC_APP_EDITION_NODE = '24'
$env:GHC_APP_EDITION_NVIM = 'manual'
$env:GHC_APP_EDITION_TMUX = 'latest'
$env:GHC_APP_PYTHON_ENV = 'lemon'
$env:GHC_THEME = 'vsc-dark-modern'

# Source local overrides if exists
$_ghcEnvDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$_ghcLocalFile = Join-Path $_ghcEnvDir 'setting.local.ps1'
if (Test-Path $_ghcLocalFile) { . $_ghcLocalFile }
Remove-Variable _ghcEnvDir, _ghcLocalFile -ErrorAction SilentlyContinue
