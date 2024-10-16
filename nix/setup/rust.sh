#! /usr/bin/env bash

### Install rust
echo -e "\e[34m  [setup rust] installing...\e[0m"
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y

### Setup cargo
echo -e "\n\e[34m  [setup rust] setting up cargo...\e[0m"
cp -f $HOME/.config/guanghechen/config/cargo.toml $HOME/.cargo/config.toml

echo -e "\e[32m  [setup rust] done.\e[0m"
