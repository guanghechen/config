$condaExecutable = Join-Path $env:APP_HOME_MINIFORGE "Scripts\conda.exe"
if (-not (Test-Path -LiteralPath $condaExecutable -PathType Leaf)) {
  throw "[setup nvim] conda executable does not exist: $condaExecutable"
}
$condaHook = (& $condaExecutable "shell.powershell" "hook") | Out-String
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($condaHook)) {
  throw "[setup nvim] failed to initialize conda."
}
Invoke-Expression -Command $condaHook -ErrorAction Stop
conda activate $env:GHC_APP_PYTHON_ENV
if ($LASTEXITCODE -ne 0) {
  throw "[setup nvim] failed to activate $env:GHC_APP_PYTHON_ENV (exit code: $LASTEXITCODE)."
}
fnm use $env:GHC_APP_EDITION_NODE

$reporoot = "$env:XDG_CONFIG_HOME"
$previousNvimAppName = $env:NVIM_APPNAME
try {
  foreach ($nvim_appname in @("nvim", "nvim-stable")) {
    $nvim_repopath = Join-Path $reporoot $nvim_appname
    if ($nvim_appname -ne "nvim" -and -not (Test-Path -LiteralPath $nvim_repopath -PathType Container)) {
      Write-Host "Skipping ${nvim_appname}: configuration directory not found" -ForegroundColor Yellow
      continue
    }

    Write-Host "Setting up $nvim_appname" -ForegroundColor Cyan
    $env:NVIM_APPNAME = $nvim_appname
    node "$nvim_repopath/script/build.mjs"
    if ($LASTEXITCODE -ne 0) {
      throw "[setup $nvim_appname] failed to build native module (exit code: $LASTEXITCODE)."
    }

    nvim --headless -u "$nvim_repopath/init-update.lua"
    if ($LASTEXITCODE -ne 0) {
      throw "[setup $nvim_appname] failed to update Neovim (exit code: $LASTEXITCODE)."
    }
  }
} finally {
  $env:NVIM_APPNAME = $previousNvimAppName
}
