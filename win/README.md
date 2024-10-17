## Requirements

* Install rust

  - Download exe from https://www.rust-lang.org/tools/install

* Install miniforge

  - Download exe from  https://github.com/conda-forge/miniforge?tab=readme-ov-file#download

## Setup

* Bootstrap

  ```powershell
  Invoke-Expression ((Invoke-WebRequest -Uri "https://raw.githubusercontent.com/guanghechen/config/refs/heads/guanghechen/win/setup.ps1" -Headers @{ 'Cache-Control' = 'no-cache'; 'Pragma' = 'no-cache'; 'Expires' = '0' }).Content)
  ```

* Setup pwsh

  Edit the profile by `nvim $PROFILE` or `notepad $PROFILE`

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

* Setup neovim

  - No c compiler found! "cc", "gcc", "clang", "cl", "zig" are not executable.

    - Install mysy2.

      ```powershell
      winget install -e --source winget --id MSYS2.MSYS2
      ```

    - Start MSYS2 UCRT64 from Windows start menu, then run the following command on the prompt opened.

      1. update the package manager inside MSYS2.
      
          ```shell
          pacman -Syu
          ```
      2. Install `gcc`.

          ```shell
          pacman -S base-devel mingw-w64-x86_64-toolchain
          ```

          Choose the gcc toolchain if there are multiple options to select.

      3. Add `C:\msys64\mingw64\bin` to the system path.

* Setup docker

  - Install the Docker Desktop follow

    - https://docs.docker.com/desktop/wsl/
    - https://learn.microsoft.com/en-us/windows/wsl/tutorials/wsl-containers

  - Install the Docker client on wsl

    ```fish
    sudo apt-get update
    apt-cache policy docker-ce
    sudo apt-get install -y docker-ce
    sudo apt-get install -y docker-compose
    sudo apt-get upgrade
    sudo usermod -a -G docker $USER
    ```

