#! /usr/bin/env bash

if command -v rustc &>/dev/null; then
  printf "\n\e[38;5;214m  [setup rust] rust is already installed. (skipped)\e[0m\n"
else
  ### Install rust
  printf "\n\e[34m  [setup rust] installing...\e[0m\n"
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
fi

### Setup cargo
if [ -f "$HOME/.cargo/config.toml" ]; then
  printf "\n\e[38;5;214m  [setup rust] ~/.cargo/config.toml is already exist. (skipped)\e[0m\n"
else
  printf "\n\e[34m  [setup rust] setting up ~/.cargo/config.toml...\e[0m\n"
  cp $HOME/.config/guanghechen/osx/config/cargo.toml $HOME/.cargo/config.toml
fi
