#! /usr/bin/env bash

## Update system
sudo apt update
sudo apt dist-upgrade -y
sudo apt remove -y tmux vim
sudo apt install -y curl file fontconfig gcc git locales vim wget
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

## Install fonts
printf "\n\e[32m  [setup fonts] preparing...\e[0m\n"
source ~/.config/guanghechen/nix/setup/fonts.sh
printf "\e[32m  [setup fonts] done.\e[0m\n"

## Install apps
printf "\n\e[32m  [setup homebrew] preparing...\e[0m\n"
source ~/.config/guanghechen/nix/setup/homebrew.sh
printf "\n\e[32m  [setup homebrew] done.\e[0m\n"
