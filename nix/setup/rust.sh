#! /usr/bin/env bash

if command -v rustc &>/dev/null; then
  echo -e "\n\e[38;5;214m  [setup rust] rust is already installed. (skipped)\e[0m"
else
  ### Install rust
  echo -e "\n\e[34m  [setup rust] installing...\e[0m"
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
fi

### Setup cargo
if [ -f "$HOME/.cargo/config.toml" ]; then
  echo -e "\n\e[38;5;214m  [setup rust] ~/.cargo/config.toml is already exist. (skipped)\e[0m"
else
  echo -e "\n\e[34m  [setup rust] setting up ~/.cargo/config.toml...\e[0m"
  cp $HOME/.config/guanghechen/config/cargo.toml $HOME/.cargo/config.toml
fi
