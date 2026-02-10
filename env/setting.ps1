# Default settings (checked in)
$env:GHC_APP_EDITION_NODE = '24'
$env:GHC_APP_EDITION_NVIM = 'manual'
$env:GHC_APP_EDITION_TMUX = 'latest'
$env:GHC_APP_PYTHON_ENV = 'lemon'
$env:GHC_EDITION = 'nix'
$env:GHC_THEME = 'vsc-dark-modern'

# Source local overrides if exists
$localFile = $MyInvocation.MyCommand.Path -replace '\.ps1$', '.local.ps1'
if (Test-Path $localFile) { . $localFile }
