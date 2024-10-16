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
echo -e "\n\e[32m  [setup config] preparing...\e[0m"
source ~/.config/guanghechen/nix/setup/config.sh
echo -e "\e[32m  [setup config] done.\e[0m"

## Setup rust envrionment
echo -e "\n\e[32m  [setup rust] preparing...\e[0m"
source ~/.config/guanghechen/nix/setup/rust.sh
echo -e "\e[32m  [setup rust] done.\e[0m"

## Setup python encironment
echo -e "\n\e[32m  [setup miniforge] preparing...\e[0m"
source ~/.config/guanghechen/nix/setup/miniforge.sh
echo -e "\n\e[32m  [setup miniforge] done.\e[0m"

## Install fonts
echo -e "\n\e[32m  [setup fonts] preparing...\e[0m"
source ~/.config/guanghechen/nix/setup/fonts.sh
echo -e "\e[32m  [setup fonts] done.\e[0m"

## Install apps
echo -e "\n\e[32m  [setup homebrew] preparing...\e[0m"
source ~/.config/guanghechen/nix/setup/homebrew.sh
echo -e "\n\e[32m  [setup homebrew] done.\e[0m"
