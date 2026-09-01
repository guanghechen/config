# Setting up conda
Write-Host "setting up conda..." -ForegroundColor Cyan

$pythonEnv = $env:GHC_APP_PYTHON_ENV
if ([string]::IsNullOrWhiteSpace($pythonEnv)) {
  throw "[setup miniforge] GHC_APP_PYTHON_ENV is not configured."
}

# Source conda environment script
$condaExecutable = "$env:APP_HOME_MINIFORGE\Scripts\conda.exe"
if (-not (Test-Path -LiteralPath $condaExecutable -PathType Leaf)) {
  throw "[setup miniforge] conda executable does not exist: $condaExecutable"
}
$condaHook = (& $condaExecutable "shell.powershell" "hook") | Out-String
if ($LASTEXITCODE -ne 0) {
  throw "[setup miniforge] failed to generate the conda PowerShell hook (exit code: $LASTEXITCODE)."
}
if ([string]::IsNullOrWhiteSpace($condaHook)) {
  throw "[setup miniforge] conda returned an empty PowerShell hook."
}
Invoke-Expression -Command $condaHook -ErrorAction Stop

# Disable auto activation of base environment
conda config --set auto_activate_base false
if ($LASTEXITCODE -ne 0) {
  throw "[setup miniforge] failed to disable base environment auto-activation (exit code: $LASTEXITCODE)."
}

# Check if the configured environment exists
$pythonEnvPattern = "^$([regex]::Escape($pythonEnv))\s"
$condaEnvList = conda env list
if ($LASTEXITCODE -ne 0) {
  throw "[setup miniforge] failed to list conda environments (exit code: $LASTEXITCODE)."
}
if ($condaEnvList | Select-String -Pattern $pythonEnvPattern) {
    Write-Host "the '$pythonEnv' env already exists (skipped)" -ForegroundColor Yellow
} else {
    Write-Host "creating '$pythonEnv' env with conda..." -ForegroundColor Cyan
    conda create --yes --name $pythonEnv python=3.12
    if ($LASTEXITCODE -ne 0) {
      throw "[setup miniforge] failed to create the '$pythonEnv' environment (exit code: $LASTEXITCODE)."
    }

    conda activate $pythonEnv
    if ($LASTEXITCODE -ne 0) {
      throw "[setup miniforge] failed to activate the '$pythonEnv' environment (exit code: $LASTEXITCODE)."
    }

    pip install debugpy httpie ipython yt-dlp
    if ($LASTEXITCODE -ne 0) {
      throw "[setup miniforge] failed to install Python packages into '$pythonEnv' (exit code: $LASTEXITCODE)."
    }
}

# Setup ipython configuration
$ipythonConfigPath = "$env:USERPROFILE\.ipython\profile_default\ipython_config.py"
if (Test-Path $ipythonConfigPath) {
    Write-Host "$ipythonConfigPath already exists (skipped)" -ForegroundColor Yellow
} else {
    Write-Host "setting up IPython..." -ForegroundColor Cyan
    conda run --name $pythonEnv ipython profile create
    if ($LASTEXITCODE -ne 0) {
      throw "[setup miniforge] failed to create the IPython profile in '$pythonEnv' (exit code: $LASTEXITCODE)."
    }

    Add-Content $ipythonConfigPath "`nc.TerminalInteractiveShell.editing_mode = 'vi'" -ErrorAction Stop
}
