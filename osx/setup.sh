#! /usr/bin/env bash

source $HOME/.config/guanghechen/nix/setup/path.sh

## Download core configurations
CONFIG_ROOT_DIR="$HOME/.config/guanghechen"
if [ -d "$CONFIG_ROOT_DIR/.git" ]; then
  git -C "$CONFIG_ROOT_DIR" pull origin guanghechen
else
  mkdir -p "$CONFIG_ROOT_DIR"
  git clone https://github.com/guanghechen/config.git --single-branch --branch=guanghechen "$CONFIG_ROOT_DIR"
fi

## Setup app configs
printf "\n\e[32m  [setup config] preparing...\e[0m\n"
source ~/.config/guanghechen/nix/setup/config.sh
printf "\e[32m  [setup config] done.\e[0m\n"

## Setup rust envrionment
printf "\n\e[32m  [setup rust] preparing...\e[0m\n"
source ~/.config/guanghechen/nix/setup/rust.sh
printf "\e[32m  [setup rust] done.\e[0m\n"

## Setup python encironment
printf "\n\e[32m  [setup miniforge] preparing...\e[0m\n"
source ~/.config/guanghechen/nix/setup/miniforge.sh
printf "\n\e[32m  [setup miniforge] done.\e[0m\n"

## Install font
printf "\n\e[32m  [setup font] preparing...\e[0m\n"
source ~/.config/guanghechen/osx/setup/font.sh
printf "\e[32m  [setup font] done.\e[0m\n"

## Install apps
if [ -z "$HOME_HOMEBREW" ] && [ -w "$HOME_HOMEBREW" ]; then
  printf "\n\e[32m  [setup homebrew] preparing...\e[0m\n"
  source ~/.config/guanghechen/nix/setup/homebrew.sh
  source ~/.config/guanghechen/osx/setup/homebrew-patch.sh
  printf "\n\e[32m  [setup homebrew] done.\e[0m\n"
fi

## Setup fish
printf "\n\e[32m  [setup fish] preparing...\e[0m\n"
source ~/.config/guanghechen/nix/setup/fish.sh
printf "\n\e[32m  [setup fish] done.\e[0m\n"

## Setup node
printf "\n\e[32m  [setup node] preparing...\e[0m\n"
source ~/.config/guanghechen/nix/setup/node.sh
printf "\n\e[32m  [setup node] done.\e[0m\n"

## Setup nvim
printf "\n\e[32m  [setup nvim] preparing...\e[0m\n"
source ~/.config/guanghechen/nix/setup/nvim.sh
printf "\n\e[32m  [setup nvim] done.\e[0m\n"

## Setup themes
printf "\n\e[32m  [setup theme] preparing...\e[0m\n"
source ~/.config/guanghechen/nix/setup/theme.sh
printf "\n\e[32m  [setup theme] done.\e[0m\n"
