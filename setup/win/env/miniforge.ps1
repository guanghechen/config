# Setting up conda
Write-Host "`n  [setup miniforge] setting up conda..." -ForegroundColor Cyan

$pythonEnv = $env:GHC_APP_PYTHON_ENV
if ([string]::IsNullOrWhiteSpace($pythonEnv)) {
  throw "[setup miniforge] GHC_APP_PYTHON_ENV is not configured."
}

# Source conda environment script
$condaExecutable = "$env:APP_HOME_MINIFORGE\Scripts\conda.exe"
if (-not (Test-Path -LiteralPath $condaExecutable -PathType Leaf)) {
  throw "[setup miniforge] conda executable does not exist: $condaExecutable"
}
(& $condaExecutable "shell.powershell" "hook") | Out-String | ?{$_} | Invoke-Expression

# Disable auto activation of base environment
conda config --set auto_activate_base false

# Check if the configured environment exists
$pythonEnvPattern = "^$([regex]::Escape($pythonEnv))\s"
if (conda env list | Select-String -Pattern $pythonEnvPattern) {
    Write-Host "  [setup miniforge] the '$pythonEnv' env is already created. (skipped)" -ForegroundColor Yellow
} else {
    Write-Host "  [setup miniforge] creating '$pythonEnv' env with conda..." -ForegroundColor Cyan
    conda create --yes --name $pythonEnv python=3.12
    conda activate $pythonEnv
    pip install debugpy httpie ipython yt-dlp
}

# Setup ipython configuration
$ipythonConfigPath = "$env:USERPROFILE\.ipython\profile_default\ipython_config.py"
if (Test-Path $ipythonConfigPath) {
    Write-Host "  [setup miniforge] $ipythonConfigPath already exists. (skipped)" -ForegroundColor Yellow
} else {
    Write-Host "  [setup miniforge] setting up ipython..." -ForegroundColor Cyan
    conda run --name $pythonEnv ipython profile create
    Add-Content $ipythonConfigPath "`nc.TerminalInteractiveShell.editing_mode = 'vi'"
}

Write-Host "  [setup miniforge] done." -ForegroundColor Green
