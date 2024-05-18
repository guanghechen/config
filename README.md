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

    If encounter the `error: linking with cc failed`, try put below content into the `~/.cargo/config` (see https://stackoverflow.com/a/65698711/15760674):

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
    ```


### FAQ

* multiple configs

  ```zsh
  alias nvchad='NVIM_APPNAME=nvim-nvchad nvim'
  ```


