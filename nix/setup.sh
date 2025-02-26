#! /usr/bin/env bash

source $HOME/.config/guanghechen/nix/setup/path.sh

## Update system
sudo apt update
sudo apt dist-upgrade -y
sudo apt remove -y tmux
sudo apt install -y colordiff curl file fontconfig gcc git locales make net-tools vim wget
sudo apt install -y build-essential libvips-dev unixodbc
sudo apt autoremove
sudo apt autoclean

## Fix locale issues
sudo locale-gen en_US.UTF-8
sudo update-locale LANG=en_US.UTF-8

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
#if ! grep -qEi "(Microsoft|WSL)" /proc/version; then
printf "\n\e[32m  [setup font] preparing...\e[0m\n"
source ~/.config/guanghechen/nix/setup/font-maple.sh
# source ~/.config/guanghechen/nix/setup/font-roboto.sh
printf "\e[32m  [setup font] done.\e[0m\n"
#fi

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

## Setup themes
printf "\n\e[32m  [setup theme] preparing...\e[0m\n"
source ~/.config/guanghechen/nix/setup/theme.sh
printf "\n\e[32m  [setup theme] done.\e[0m\n"

## Setup apps
printf "\n\e[32m  [setup app] preparing...\e[0m\n"
source ~/.config/guanghechen/nix/setup/app.sh
printf "\n\e[32m  [setup app] done.\e[0m\n"
