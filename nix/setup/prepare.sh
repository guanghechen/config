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
printf "\e[96m  [preparation] done.\e[0m\n"

## Download core configurations
reporoot="$HOME/.config"
repomain="$reporoot/guanghechen"
if [ -e "$repomain/.git" ]; then
  git -C "$repomain" fetch origin
  git -C "$repomain" merge origin/guanghechen --ff-only
else
  mkdir -p "$repomain"
  git clone https://github.com/guanghechen/config.git --branch=guanghechen "$repomain"
fi

source $HOME/.config/guanghechen/nix/setup/path.sh

## Fix locale issues
sudo locale-gen en_US.UTF-8
sudo update-locale LANG=en_US.UTF-8
