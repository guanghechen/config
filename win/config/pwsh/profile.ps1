Set-PSReadLineOption -EditMode Vi
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

## Setup on-my-posh
oh-my-posh init pwsh --config "$env:POSH_THEMES_PATH/catppuccin_mocha.omp.json" | Invoke-Expression

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
