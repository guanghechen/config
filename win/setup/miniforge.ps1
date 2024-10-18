function Write-ColoredMessage {
    param (
        [string]$Message,
        [string]$ColorCode
    )
    Write-Host "`n$Message" -ForegroundColor $ColorCode
}

# Setting up conda
Write-ColoredMessage "[setup miniforge] setting up conda..." Blue

# Source conda environment script
If (Test-Path "$env:APP_HOME_MINIFORGE\Scripts\conda.exe") {
  (& "$env:APP_HOME_MINIFORGE\Scripts\conda.exe" "shell.powershell" "hook") | Out-String | ?{$_} | Invoke-Expression
}

# Disable auto activation of base environment
conda config --set auto_activate_base false

# Check if 'lemon' environment exists
if (conda env list | Select-String -Pattern "^lemon\s") {
    Write-ColoredMessage "[setup miniforge] the 'lemon' env is already created. (skipped)" DarkYellow
} else {
    Write-ColoredMessage "[setup miniforge] creating 'lemon' env with conda..." Blue
    conda create --yes --name lemon python=3.12
}

# Activate 'lemon' environment
conda activate lemon

# Install required packages
pip install ipython shell-gpt

# Setup ipython configuration
$ipythonConfigPath = "$env:USERPROFILE\.ipython\profile_default\ipython_config.py"
if (Test-Path $ipythonConfigPath) {
    Write-ColoredMessage "[setup miniforge] $ipythonConfigPath already exists. (skipped)" DarkYellow
} else {
    Write-ColoredMessage "[setup miniforge] setting up ipython..." Blue
    ipython profile create
    Add-Content $ipythonConfigPath "`nc.TerminalInteractiveShell.editing_mode = 'vi'"
}

Write-ColoredMessage "[setup miniforge] done..." Green
