#! /usr/bin/env bash

## Update system
sudo apt update
sudo apt dist-upgrade -y
sudo apt remove -y tmux vim
sudo apt install -y clangd curl fontconfig gcc git vim wget
sudo apt autoremove
sudo apt autoclean

## Fix locale issues
sudo locale-gen en_US.UTF-8
sudo update-locale LANG=en_US.UTF-8

## Fetch app configurations
mkdir -p ~/.config
git clone https://github.com/guanghechen/config.git --single-branch --branch=alacritty ~/.config/alacritty
git clone https://github.com/guanghechen/config.git --single-branch --branch=btop ~/.config/btop
git clone https://github.com/guanghechen/config.git --single-branch --branch=fish ~/.config/fish
git clone https://github.com/guanghechen/config.git --single-branch --branch=fzf ~/.config/fzf
git clone https://github.com/guanghechen/config.git --single-branch --branch=guanghechen ~/.config/guanghechen
git clone https://github.com/guanghechen/config.git --single-branch --branch=helix ~/.config/helix
git clone https://github.com/guanghechen/config.git --single-branch --branch=lazygit ~/.config/lazygit
git clone https://github.com/guanghechen/config.git --single-branch --branch=lsd ~/.config/lsd
git clone https://github.com/guanghechen/config.git --single-branch --branch=nvim ~/.config/nvim
git clone https://github.com/guanghechen/config.git --single-branch --branch=ripgrep ~/.config/ripgrep
git clone https://github.com/guanghechen/config.git --single-branch --branch=tmux ~/.config/tmux

### Setup git
cp -f ~/.config/guanghechen/config/.gitconfig ~/.gitconfig

## Install

### Install homebrew
source ~/.config/guanghechen/nix/install/homebrew.sh

### Install miniforge
source ~/.config/guanghechen/nix/install/miniforge.sh

### Install rust
source ~/.config/guanghechen/nix/install/rust.sh

### Install node
source ~/.config/guanghechen/nix/install/node.sh

### Install fonts
source ~/.config/guanghechen/nix/install/fonts.sh

## Setup

### Setup nvim
fish -c "cd ~/.config/nvim/rust/nvim_tools/ && bash build.sh"
