# Setting up conda
Write-Host "[setup miniforge] setting up conda..." -ForegroundColor Blue

# Source conda environment script
If (Test-Path "$env:APP_HOME_MINIFORGE\Scripts\conda.exe") {
  (& "$env:APP_HOME_MINIFORGE\Scripts\conda.exe" "shell.powershell" "hook") | Out-String | ?{$_} | Invoke-Expression
}

# Disable auto activation of base environment
conda config --set auto_activate_base false

# Check if 'lemon' environment exists
if (conda env list | Select-String -Pattern "^lemon\s") {
    Write-Host "[setup miniforge] the 'lemon' env is already created. (skipped)" -ForegroundColor DarkYellow
} else {
    Write-Host "[setup miniforge] creating 'lemon' env with conda..." -ForegroundColor Blue
    conda create --yes --name lemon python=3.12
}

# Activate 'lemon' environment
conda activate lemon

# Install required packages
pip install httpie ipython shell-gpt

# Setup ipython configuration
$ipythonConfigPath = "$env:USERPROFILE\.ipython\profile_default\ipython_config.py"
if (Test-Path $ipythonConfigPath) {
    Write-Host "[setup miniforge] $ipythonConfigPath already exists. (skipped)" -ForegroundColor DarkYellow
} else {
    Write-Host "[setup miniforge] setting up ipython..." -ForegroundColor Blue
    ipython profile create
    Add-Content $ipythonConfigPath "`nc.TerminalInteractiveShell.editing_mode = 'vi'"
}

Write-Host "[setup miniforge] done..." -ForegroundColor Green
