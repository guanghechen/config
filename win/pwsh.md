## Install

* Install through winget

  ```pwsh
  winget install --id Microsoft.WindowsTerminal.Preview -e
  winget install --id Microsoft.PowerShell --source winget
  winget install Neovim.Neovim
  winget install sharkdp.fd
  winget install Schniz.fnm
  winget install fzf
  winget install BurntSushi.ripgrep.MSVC
  winget install dandavison.delta
  winget install --id=JesseDuffield.lazygit -e
  winget install JanDeDobbeleer.OhMyPosh --source winget
  ```

* Install rust

  - Download exe from https://www.rust-lang.org/tools/install

* Install anaconda

  - Download exe from https://www.anaconda.com/download/success


## Configure

* Edit the profile by `nvim $PROFILE` or `notepad $PROFILE`

  ```powershell
  Set-PSReadLineOption -EditMode Vi
  fnm env --use-on-cd --shell power-shell | Out-String | Invoke-Expression
  
  oh-my-posh init pwsh --config "$env:POSH_THEMES_PATH/catppuccin_mocha.omp.json" | Invoke-Expression
  
  #region conda initialize
  # !! Contents within this block are managed by 'conda init' !!
  If (Test-Path "C:\app\anaconda\Scripts\conda.exe") {
    (& "C:\app\anaconda\Scripts\conda.exe" "shell.powershell" "hook") | Out-String | ?{$_} | Invoke-Expression
  }
  #endregion
  
  Set-Alias nvchad "C:\app\nvim\bin\nvim.exe"
  ```
