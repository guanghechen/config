#! /usr/bin/env bash

## Update system
sudo apt update
sudo apt dist-upgrade -y
sudo apt remove -y tmux vim
sudo apt install -y curl file fontconfig gcc git vim wget
sudo apt autoremove
sudo apt autoclean

## Fix locale issues
sudo locale-gen en_US.UTF-8
sudo update-locale LANG=en_US.UTF-8

## Setup app configurations
CONFIG_ROOT_DIR="$HOME/.config/guanghechen"
if [ -d "$CONFIG_ROOT_DIR/.git" ]; then
  git -C "$CONFIG_ROOT_DIR" pull origin guanghechen
else
  mkdir -p "$CONFIG_ROOT_DIR"
  git clone https://github.com/guanghechen/config.git --single-branch --branch=guanghechen "$CONFIG_ROOT_DIR"
fi

## Setup rust envrionment
echo -e "\n\n"
source ~/.config/guanghechen/nix/setup/rust.sh

## Setup python encironment
echo -e "\n\n"
source ~/.config/guanghechen/nix/setup/miniforge.sh

## Install fonts
echo -e "\n\n"
source ~/.config/guanghechen/nix/setup/fonts.sh

## Install apps
echo -e "\n\n"
source ~/.config/guanghechen/nix/setup/homebrew.sh
