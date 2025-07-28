#! /usr/bin/env bash

## Preparation
sudo apt update
sudo apt dist-upgrade -y
sudo apt remove -y tmux
sudo apt install -y curl git wget
sudo apt install -y clangd colordiff file fontconfig gcc locales make net-tools vim
sudo apt install -y build-essential libvips-dev unixodbc
sudo apt autoremove
sudo apt autoclean
printf "\e[32m  [preparation] done.\e[0m\n"

## Download core configurations
CONFIG_ROOT_DIR="$HOME/.config"
CONFIG_MAIN_DIR="$CONFIG_ROOT_DIR/guanghechen"
if [ -e "$CONFIG_MAIN_DIR/.git" ]; then
  git -C "$CONFIG_MAIN_DIR" fetch origin
  git -C "$CONFIG_MAIN_DIR" merge origin/guanghechen --ff-only
else
  mkdir -p "$CONFIG_MAIN_DIR"
  git clone https://github.com/guanghechen/config.git --branch=guanghechen "$CONFIG_MAIN_DIR"
fi

source $HOME/.config/guanghechen/nix/setup/path.sh

## Fix locale issues
sudo locale-gen en_US.UTF-8
sudo update-locale LANG=en_US.UTF-8

## Setup app configs
printf "\n\e[32m  [setup config] preparing...\e[0m\n"
source ~/.config/guanghechen/nix-remote/setup/config.sh
printf "\e[32m  [setup config] done.\e[0m\n"

## Setup rust envrionment
printf "\n\e[32m  [setup rust] preparing...\e[0m\n"
source ~/.config/guanghechen/nix/setup/rust.sh
printf "\e[32m  [setup rust] done.\e[0m\n"

## Setup python encironment
printf "\n\e[32m  [setup miniforge] preparing...\e[0m\n"
source ~/.config/guanghechen/nix/setup/miniforge.sh
printf "\n\e[32m  [setup miniforge] done.\e[0m\n"

## Install apps
if [ -z "$HOME_HOMEBREW" ] || [ -w "$HOME_HOMEBREW/var/homebrew/locks" ]; then
  printf "\n\e[32m  [setup homebrew] preparing...\e[0m\n"
  source ~/.config/guanghechen/nix/setup/homebrew.sh
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

## Setup tmux
printf "\n\e[32m  [setup tmux] preparing...\e[0m\n"
source ~/.config/guanghechen/nix/setup/tmux.sh
printf "\n\e[32m  [setup tmux] done.\e[0m\n"

## Setup themes
printf "\n\e[32m  [setup theme] preparing...\e[0m\n"
source ~/.config/guanghechen/nix/setup/theme.sh
printf "\n\e[32m  [setup theme] done.\e[0m\n"
