## Requirements

* Install Xcode Command Line Tools to provide the `git` command:

  ```bash
  xcode-select --install
  ```

## Bootstrap

* Debian/Ubuntu (including WSL): [Nix Setup](./setup/nix/README.md)

  ```bash
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/guanghechen/config/refs/heads/guanghechen/setup/nix/setup.bash)"
  ```

* Debian/Ubuntu (including WSL, remote): [Nix-Remote Setup](./setup/nix-remote/README.md)

  ```bash
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/guanghechen/config/refs/heads/guanghechen/setup/nix-remote/setup.bash)"
  ```

* Macos:

  ```bash
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/guanghechen/config/refs/heads/guanghechen/setup/osx/setup.bash)"
  ```

* Windows: [Windows Setup](./setup/win/README.md)

  ```powershell
  pwsh -NoProfile -Command {
    $headers = @{
      "Cache-Control" = "no-cache"
      "Pragma" = "no-cache"
      "Expires" = "0"
    }
    $setupScript = (Invoke-WebRequest -Uri "https://raw.githubusercontent.com/guanghechen/config/refs/heads/guanghechen/setup/win/setup.ps1" -Headers $headers).Content
    Invoke-Expression $setupScript
  }
  ```

* Wsl:

  - Install wsl

     ```pwsh
      wsl --install
     ```

  - Disable the Windows path on wsl.

    ```wsl
    # edit /etc/wsl.conf

    # see the asset/conf/wsl.conf
    # example: sudo cp ~/.config/guanghechen/asset/conf/wsl.conf /etc/wsl.conf
    ```
  
  - Bootstrap

    ```bash
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/guanghechen/config/refs/heads/guanghechen/setup/nix/setup.bash)"
    ```

## APP

* **Neovim**: Build from Source (nightly): see https://github.com/neovim/neovim/blob/master/BUILD.md

  - nix

    ```bash
    # git clone https://github.com/neovim/neovim && cd neovim
    git fetch origin --tags --force && git checkout nightly
    make CMAKE_BUILD_TYPE=RelWithDebInfo CMAKE_INSTALL_PREFIX="$HOME/.app/neovim/"
    rm -rf "$HOME/.app/neovim/"
    make install
    ```

  - macos

    ```bash
    # git clone https://github.com/neovim/neovim && cd neovim
    git fetch origin --tags --force && git checkout nightly
    make CMAKE_BUILD_TYPE=RelWithDebInfo CMAKE_INSTALL_PREFIX="/opt/me/app/neovim/"
    rm -rf /opt/me/app/neovim/
    make install
    ```

  - Win

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

## FAQ

* bat

  ```shell
  # Update the binary cache
  bat cache --build
  ```

* treesitter

  Don't forget to install the tree-sitter-cli which the nvim-treesitter depend on.

  ```bash
  cargo install tree-sitter-cli
  ```
