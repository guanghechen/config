### Requirements

* GNU sed (macos only)
  ```zsh
  brew install gnu-sed
  ```

* fd: https://github.com/sharkdp/fd?tab=readme-ov-file#installation
  - macos
    ```zsh
    brew install fd
    ```

* rg: https://github.com/BurntSushi/ripgrep?tab=readme-ov-file#installation
  - macos
    ```zsh
    $ brew install ripgrep
    ```

* nvim-oxi: https://github.com/noib3/nvim-oxi, https://github.com/nvim-pack/nvim-spectre?tab=readme-ov-file#replace-method
  - macos
    ```zsh
    cd ~/.local/share/nvim/lazy/nvim-spectre
    ./build.sh
    ```

    If encounter the `error: linking with cc failed`, try put below content into the `~/.cargo/config.toml` (see https://stackoverflow.com/a/65698711/15760674):

    ```conf
    [target.x86_64-apple-darwin]
    rustflags = [
    "-C", "link-arg=-undefined",
    "-C", "link-arg=dynamic_lookup",
    ]

    [target.aarch64-apple-darwin]
    rustflags = [
    "-C", "link-arg=-undefined",
    "-C", "link-arg=dynamic_lookup",
    ]

    [target.x86_64-pc-windows-msvc]
    rustflags = [
      "-C", "link-arg=/FORCE:UNRESOLVED",
    ]

    [target.aarch64-pc-windows-msvc]
    rustflags = [
      "-C", "link-arg=/FORCE:UNRESOLVED",
    ]
    ```

  - windows
    ```zsh
    cd <nvim-data>/lazy/nvim-spectre/spectre_oxi
    cargo build --release
    cp ./target/release/spectre_oxi.dll ../lua/
    ```

    If failed, try:

    - rustup
      ```powershell
      rustup update # https://stackoverflow.com/a/74132269/15760674
      ```
    - Upgrade the `nvim-oxi` to latest by edit the `<nvim-data>/lazy/nvim-spectre/spectre_oxi/cargo.toml`
    - install clang / llvm
      a) open cmd.exe with admin
      b) run `choco install llvm`



### FAQ

* multiple configs

  ```zsh
  alias nvchad='NVIM_APPNAME=nvim-nvchad nvim'
  ```


