#! /usr/bin/env bash

source "$HOME/.config/guanghechen/setup/nix/bot/env.bash"

if command -v pnpm &>/dev/null; then
  printf "\e[93m  [setup pnpm] pnpm is already installed. (skipped)\e[0m\n"
else
  printf "\e[96m  [setup pnpm] installing pnpm...\e[0m\n"
  curl -fsSL https://get.pnpm.io/install.sh | sh -
fi
