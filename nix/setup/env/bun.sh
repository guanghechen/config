#! /usr/bin/env bash

source $HOME/.config/guanghechen/nix/setup/path.sh

if command -v bun &>/dev/null; then
  printf "\e[96m  [setup bun] bun is already installed, upgrading...\e[0m\n"
  bun upgrade
else
  printf "\e[96m  [setup bun] installing bun...\e[0m\n"
  curl -fsSL https://bun.sh/install | bash
fi
