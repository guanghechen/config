#! /usr/bin/env bash

## @see https://mason-registry.dev/registry/list
source $HOME/.config/guanghechen/nix/setup/path.sh

rustup component add rust-analyzer # [lsp] rust
cargo install taplo-cli --locked   # [lsp] rust/cargo
cargo install stylua               # [formatter] lua
