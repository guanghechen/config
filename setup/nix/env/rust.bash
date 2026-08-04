#! /usr/bin/env bash

source "$HOME/.config/guanghechen/setup/nix/bot/env.bash"

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
  mkdir -p "$HOME/.cargo"
  cp "$HOME/.config/guanghechen/asset/conf/cargo.toml" "$HOME/.cargo/config.toml"
fi

if command -v cargo-watch &>/dev/null; then
  printf "\e[93m  [setup rust] cargo-watch is already installed. (skipped)\e[0m\n"
else
  printf "\e[96m  [setup rust] installing cargo-watch...\e[0m\n"
  cargo install cargo-watch
fi
