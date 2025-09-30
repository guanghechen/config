## Bootstrap

* Nix: [Nix Setup](./nix/README.md)

  ```bash
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/guanghechen/config/refs/heads/guanghechen/nix/setup.sh)"
  ```

* Nix* (remote): [Nix-Remote Setup](./nix-remote/README.md)

  ```bash
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/guanghechen/config/refs/heads/guanghechen/nix-remote/setup.sh)"
  ```

* Macos:

  ```bash
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/guanghechen/config/refs/heads/guanghechen/osx/setup.sh)"
  ```

* Windows: [Windows Setup](./win/README.md)

  ```powershell
  Invoke-Expression ((Invoke-WebRequest -Uri "https://raw.githubusercontent.com/guanghechen/config/refs/heads/guanghechen/win/setup.ps1" -Headers @{ 'Cache-Control' = 'no-cache'; 'Pragma' = 'no-cache'; 'Expires' = '0' }).Content)
  ```

* Wsl:

  - Install wsl

     ```pwsh
      wsl --install
     ```

  - Disable the Windows path on wsl.

    ```wsl
    # edit /etc/wsl.conf

    # see the win/config/wsl.conf
    ```
  
  - Bootstrap

    ```bash
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/guanghechen/config/refs/heads/guanghechen/nix/setup.sh)"
    ```

## FAQ

* bat

  ```shell
  # Update the binary cache
  bat cache --build
  ```

* treesitter
  
  Don't forget to install the tree-sitter-cli which the nvim-treesitter depend on. see nix/setup/lsp/cargo.sh
