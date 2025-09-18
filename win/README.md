## Requirements

* Set windows code pages with UTF-8

  https://learn.microsoft.com/en-us/windows/apps/design/globalizing/use-utf8-code-page


  > GDI doesn't currently support setting the ActiveCodePage property per process. Instead,
  > GDI defaults to the active system codepage. To configure your app to render UTF-8 text
  > via GDI, go to Windows Settings > Time & language > Language & region > Administrative
  > language settings > Change system locale, and check Beta: Use Unicode UTF-8 for
  > worldwide language support. Then reboot the PC for the change to take effect.

* Install rust

  - Download exe from https://www.rust-lang.org/tools/install
  - FAQ
    * `error: linker `link.exe` not found`

      - Install [Visual Studio C++ Build tools](https://visualstudio.microsoft.com/visual-cpp-build-tools/)
        
        Need to install the Development C++ toolchain


      --- or use `stable-x86_64-pc-windows-gnu` ---

      ```pwsh
      # https://stackoverflow.com/a/62817909
      rustup toolchain install stable-x86_64-pc-windows-gnu
      rustup default stable-x86_64-pc-windows-gnu
      ```

* Install font
  - Maple
    - https://github.com/guanghechen/mirror/releases/download/font/MapleMonoNormalNL-NF-CN-unhinted.zip
    - "Maple Mono Normal NL NF CN"
  - RobotoMono
    - https://github.com/guanghechen/mirror/releases/download/font/RobotoMono.zip
    - "RobotoMono Nerd Font"

* Install miniforge

  - Download exe from  https://github.com/conda-forge/miniforge?tab=readme-ov-file#download

## Setup

* Bootstrap

  ```powershell
  Invoke-Expression ((Invoke-WebRequest -Uri "https://raw.githubusercontent.com/guanghechen/config/refs/heads/guanghechen/win/setup.ps1" -Headers @{ 'Cache-Control' = 'no-cache'; 'Pragma' = 'no-cache'; 'Expires' = '0' }).Content)
  ```

* Setup pwsh

  - Edit the profile by `nvim $PROFILE` or `notepad $PROFILE`
  - Copy the preset config from ./config/pwsh/profile.ps1

* Setup wsl
  - Install wsl

     ```pwsh
      wsl --install
     ```

  - Disable the Windows path on wsl.

    ```wsl
    # edit /etc/wsl.conf

    # see the win/config/wsl.conf
    ```

* Setup neovim

  - No c compiler found! "cc", "gcc", "clang", "cl", "zig" are not executable.

    - Install msys2.

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

