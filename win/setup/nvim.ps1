conda activate $env:PREFER_PYTHON_ENV
fnm use $env:PREFER_NODE_VERSION

$reporoot = "$env:XDG_CONFIG_HOME"
$nvim_repopath = Join-Path $reporoot "nvim"
. "$nvim_repopath/rust/nvim_tools/build.ps1"
nvim --headless -u "$nvim_repopath/init-update.lua"
