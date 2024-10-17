## Install

* Install through winget

  ```pwsh
  winget install -e --source winget --id Microsoft.WindowsTerminal.Preview
  winget install -e --source winget --id Microsoft.PowerShell
  winget install -e --source winget --id JesseDuffield.lazygit
  winget install -e --source winget --id Neovim.Neovim
  winget install -e --source winget --id sharkdp.fd
  winget install -e --source winget --id Schniz.fnm
  winget install -e --source winget --id BurntSushi.ripgrep.MSVC
  winget install -e --source winget --id dandavison.delta
  winget install -e --source winget --id JanDeDobbeleer.OhMyPosh
  winget install -e --source winget --id lsd-rs.lsd
  winget install -e --source winget --id ajeetdsouza.zoxide
  winget install -e --source winget fzf
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
  Invoke-Expression (& { (zoxide init powershell | Out-String) })
  
  oh-my-posh init pwsh --config "$env:POSH_THEMES_PATH/catppuccin_mocha.omp.json" | Invoke-Expression
  
  #region conda initialize
  # !! Contents within this block are managed by 'conda init' !!
  If (Test-Path "C:\app\anaconda\Scripts\conda.exe") {
    (& "C:\app\anaconda\Scripts\conda.exe" "shell.powershell" "hook") | Out-String | ?{$_} | Invoke-Expression
  }
  #endregion
  
  Set-Alias nvchad "C:\app\nvim\bin\nvim.exe"
  ```
