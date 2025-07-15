[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
Set-PSReadLineOption -EditMode Vi
Set-PSReadLineOption -PredictionSource History
Set-PSReadLineOption -Colors @{
  InlinePrediction        = "DarkGray"
  Command                 = "Yellow"
  Parameter               = "Cyan"
  Variable                = "Cyan"
  String                  = "Green"
  Default                 = "White"
}

. "$env:XDG_CONFIG_HOME\pwsh\config.ps1"
$localConfigPath = "$env:XDG_CONFIG_HOME\pwsh\local\config.ps1"
if (Test-Path $localConfigPath) {
  . $localConfigPath
}

## Setup conda
If (Test-Path "$env:APP_HOME_MINIFORGE\Scripts\conda.exe") {
  (& "$env:APP_HOME_MINIFORGE\Scripts\conda.exe" "shell.powershell" "hook") | Out-String | ?{$_} | Invoke-Expression

  # if (-not $env:CONDA_DEFAULT_ENV) {
  #   conda activate lemon
  # }
}

## Setup fnm
fnm env --use-on-cd --shell power-shell | Out-String | Invoke-Expression

. "$env:XDG_CONFIG_HOME\pwsh\alias.ps1"
. "$env:XDG_CONFIG_HOME\pwsh\functions\ghc.ps1"
. "$env:XDG_CONFIG_HOME\pwsh\functions\prompt.ps1"
. "$env:XDG_CONFIG_HOME\pwsh\functions\yazi.ps1"

## Setup zoxide (need ensure executed at the last line. see https://github.com/ajeetdsouza/zoxide/issues/707#issuecomment-1959685345)
zoxide init powershell | Out-String | Invoke-Expression
