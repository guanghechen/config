conda activate $env:GHC_APP_PYTHON_ENV
fnm use $env:GHC_APP_EDITION_NODE

$reporoot = "$env:XDG_CONFIG_HOME"
$nvim_repopath = Join-Path $reporoot "nvim"
node "$nvim_repopath/script/build.mjs"
if ($LASTEXITCODE -ne 0) {
  throw "[setup nvim] failed to build native module (exit code: $LASTEXITCODE)."
}

nvim --headless -u "$nvim_repopath/init-update.lua"
if ($LASTEXITCODE -ne 0) {
  throw "[setup nvim] failed to update Neovim (exit code: $LASTEXITCODE)."
}
