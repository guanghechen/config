Set-PSReadLineOption -EditMode Vi
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

## Setup conda
If (Test-Path "$env:APP_HOME_MINIFORGE\Scripts\conda.exe") {
  (& "$env:APP_HOME_MINIFORGE\Scripts\conda.exe" "shell.powershell" "hook") | Out-String | ?{$_} | Invoke-Expression

  #  conda config --set auto_activate_base false
  #  if (conda env list | Select-String -Pattern "^lemon\s") {
  #    conda activate lemon
  #  }
}

## Setup fnm
fnm env --use-on-cd --shell power-shell | Out-String | Invoke-Expression

## Setup zoxide (need move to the last line. see https://github.com/ajeetdsouza/zoxide/issues/707#issuecomment-1959685345)
Invoke-Expression (& { (zoxide init powershell | Out-String) })

. "$env:XDG_CONFIG_HOME\pwsh\functions\prompt.ps1"
. "$env:XDG_CONFIG_HOME\pwsh\functions\ghc.ps1"
