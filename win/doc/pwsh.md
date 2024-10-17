## Install

* Install rust

  - Download exe from https://www.rust-lang.org/tools/install

* Install anaconda

  - Download exe from https://www.anaconda.com/download/success


## Configure

* Edit the profile by `nvim $PROFILE` or `notepad $PROFILE`

  ```powershell
  Set-PSReadLineOption -EditMode Vi
  fnm env --use-on-cd --shell power-shell | Out-String | Invoke-Expression
  Invoke-Expression (& { (zoxide init powershell | Out-String) })
  
  oh-my-posh init pwsh --config "$env:POSH_THEMES_PATH/catppuccin_mocha.omp.json" | Invoke-Expression
  
  #region conda initialize
  # !! Contents within this block are managed by 'conda init' !!
  If (Test-Path "C:\app\miniforge\Scripts\conda.exe") {
    (& "C:\app\miniforge\Scripts\conda.exe" "shell.powershell" "hook") | Out-String | ?{$_} | Invoke-Expression
  }
  #endregion
  
  Set-Alias nvchad "C:\app\nvim\bin\nvim.exe"
  ```
