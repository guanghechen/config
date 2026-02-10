conda activate $env:GHC_APP_PYTHON_ENV
fnm use $env:GHC_APP_EDITION_NODE

$reporoot = "$env:XDG_CONFIG_HOME"
$nvim_repopath = Join-Path $reporoot "nvim"
. "$nvim_repopath/rust/build.ps1"
nvim --headless -u "$nvim_repopath/init-update.lua"
