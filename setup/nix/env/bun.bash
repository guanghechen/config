#! /usr/bin/env bash

source "$HOME/.config/guanghechen/setup/nix/bot/env.bash"

if command -v bun &>/dev/null; then
  printf "\e[93m  [setup bun] bun is already installed. (skipped)\e[0m\n"
else
  printf "\e[96m  [setup bun] installing bun...\e[0m\n"
  curl -fsSL https://bun.sh/install | bash
fi
