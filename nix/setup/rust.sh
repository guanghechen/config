#! /usr/bin/env bash

### Install rust
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y

### Setup cargo
cp -f $HOME/.config/guanghechen/config/cargo.toml $HOME/.cargo/config.toml
