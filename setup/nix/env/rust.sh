#! /usr/bin/env bash
# shellcheck disable=SC1091


# shellcheck source=setup/nix/path.sh
source "$HOME/.config/guanghechen/setup/nix/path.sh"

if command -v rustc &>/dev/null; then
  printf "\e[93m  [setup rust] rust is already installed. (skipped)\e[0m\n"
else
  ### Install rust
  printf "\e[96m  [setup rust] installing...\e[0m\n"
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
fi

### Setup cargo
if [ -f "$HOME/.cargo/config.toml" ]; then
  printf "\e[93m  [setup rust] ~/.cargo/config.toml already exists. (skipped)\e[0m\n"
else
  printf "\e[96m  [setup rust] setting up ~/.cargo/config.toml...\e[0m\n"
  cp "$HOME/.config/guanghechen/asset/conf/cargo.toml" "$HOME/.cargo/config.toml"

  cargo install inferno
fi
