Set-PSReadLineOption -EditMode Vi

## Setup fnm
fnm env --use-on-cd --shell power-shell | Out-String | Invoke-Expression

## Setup zoxide
Invoke-Expression (& { (zoxide init powershell | Out-String) })

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

