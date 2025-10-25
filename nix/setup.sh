#! /usr/bin/env bash

source $HOME/.config/guanghechen/nix/setup/prepare.sh

## Setup app configs
printf "\n\e[94m  [setup config] preparing...\e[0m\n"
source ~/.config/guanghechen/nix/setup/config.sh
printf "\e[96m  [setup config] done.\e[0m\n"

## Setup rust envrionment
printf "\n\e[94m  [setup rust] preparing...\e[0m\n"
source ~/.config/guanghechen/nix/setup/rust.sh
printf "\e[96m  [setup rust] done.\e[0m\n"

## Setup python encironment
printf "\n\e[94m  [setup miniforge] preparing...\e[0m\n"
source ~/.config/guanghechen/nix/setup/miniforge.sh
printf "\n\e[96m  [setup miniforge] done.\e[0m\n"

## Install font
#if ! grep -qEi "(Microsoft|WSL)" /proc/version; then
printf "\n\e[94m  [setup font] preparing...\e[0m\n"
source ~/.config/guanghechen/nix/setup/font-maple.sh
# source ~/.config/guanghechen/nix/setup/font-roboto.sh
printf "\e[96m  [setup font] done.\e[0m\n"
#fi

## Install apps
if [ -z "$HOME_HOMEBREW" ] || [ -w "$HOME_HOMEBREW/var/homebrew/locks" ]; then
  printf "\n\e[94m  [setup homebrew] preparing...\e[0m\n"
  source ~/.config/guanghechen/nix/setup/homebrew.sh
  printf "\n\e[96m  [setup homebrew] done.\e[0m\n"
fi

## Setup fish
printf "\n\e[94m  [setup fish] preparing...\e[0m\n"
source ~/.config/guanghechen/nix/setup/fish.sh
printf "\n\e[96m  [setup fish] done.\e[0m\n"

## Setup node
printf "\n\e[94m  [setup node] preparing...\e[0m\n"
source ~/.config/guanghechen/nix/setup/node.sh
printf "\n\e[96m  [setup node] done.\e[0m\n"

## Setup nvim
printf "\n\e[94m  [setup nvim] preparing...\e[0m\n"
source ~/.config/guanghechen/nix/setup/nvim.sh
printf "\n\e[96m  [setup nvim] done.\e[0m\n"

## Setup tmux
printf "\n\e[94m  [setup tmux] preparing...\e[0m\n"
source ~/.config/guanghechen/nix/setup/tmux.sh
printf "\n\e[96m  [setup tmux] done.\e[0m\n"

## Setup themes
printf "\n\e[94m  [setup theme] preparing...\e[0m\n"
source ~/.config/guanghechen/nix/setup/theme.sh
printf "\n\e[96m  [setup theme] done.\e[0m\n"

## Setup apps
printf "\n\e[94m  [setup app] preparing...\e[0m\n"
source ~/.config/guanghechen/nix/setup/app.sh
printf "\n\e[96m  [setup app] done.\e[0m\n"
