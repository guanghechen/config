### Thanks

* Snacks: https://github.com/folke/snacks.nvim/blob/bc0630e43be5699bb94dadc302c0d21615421d93
* venv-selector.nvim: https://github.com/linux-cultist/venv-selector.nvim


### Requirements

* fd: https://github.com/sharkdp/fd?tab=readme-ov-file#installation
  - homebrew
    ```fish
    brew install fd
    ```

* fnm: https://github.com/Schniz/fnm
  - homebrew
    ```fish
    brew install fnm
    ```

* fzf: https://github.com/junegunn/fzf#installation
  - homebrew
    ```fish
    brew install fzf
    ```

* lazygit: https://github.com/jesseduffield/lazygit#installation
  - homebrew
    ```fish
    brew install lazygit
    ```

* rg: https://github.com/BurntSushi/ripgrep?tab=readme-ov-file#installation
  - homebrew
    ```fish
    brew install ripgrep
    ```

* rust: https://doc.rust-lang.org/book/ch01-01-installation.html#installing-rustup-on-linux-or-macos
   (*install use rustup instead of homebrew*)

  - macos
    ```fish
    curl --proto '=https' --tlsv1.2 https://sh.rustup.rs -sSf | sh
    ```

### Native module build

On macOS, `node script/build.mjs` loads `.cargo/config.macos.toml`, which defaults
`SDKROOT` to the installed Command Line Tools macOS 26.5 SDK. Builds of `yoz` with
SDK 27 currently fail dyld's LINKEDIT alignment check. An explicit `SDKROOT`
environment variable overrides this default. Linux (including WSL) and Windows
builds do not load this configuration.

For direct Cargo builds on macOS, run from the repository root:

```sh
cargo --config .cargo/config.macos.toml build --manifest-path rust/Cargo.toml --release -p yoz
```

After changing the SDK, run `node script/build.mjs --force` to avoid reusing cached
artifacts. The build checks native module loading before deploying either library.

### FAQ

* multiple configs

  ```fish
  alias nvchad='NVIM_APPNAME=nvim-nvchad nvim'
  ```

