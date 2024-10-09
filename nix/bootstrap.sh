#! /usr/bin/env bash

## Update system
sudo apt update
sudo apt dist-upgrade -y
sudo apt remove -y tmux vim
sudo apt install -y vim gcc clangd git curl wget
sudo apt autoremove
sudo apt autoclean

## Fetch app configurations
mkdir -p ~/.config
git clone https://github.com/guanghechen/config.git --single-branch --branch=alacritty ~/.config/alacritty
git clone https://github.com/guanghechen/config.git --single-branch --branch=btop ~/.config/btop
git clone https://github.com/guanghechen/config.git --single-branch --branch=fish ~/.config/fish
git clone https://github.com/guanghechen/config.git --single-branch --branch=fzf ~/.config/fzf
git clone https://github.com/guanghechen/config.git --single-branch --branch=guanghechen ~/.config/guanghechen
git clone https://github.com/guanghechen/config.git --single-branch --branch=helix ~/.config/helix
git clone https://github.com/guanghechen/config.git --single-branch --branch=lazygit ~/.config/lazygit
git clone https://github.com/guanghechen/config.git --single-branch --branch=nvim ~/.config/nvim
git clone https://github.com/guanghechen/config.git --single-branch --branch=ripgrep ~/.config/ripgrep
git clone https://github.com/guanghechen/config.git --single-branch --branch=tmux ~/.config/tmux

## Install

### Install rust
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

### Install homebrew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
if [ -e "/home/linuxbrew/.linuxbrew/bin/brew" ]; then
  export PATH=$PATH:/home/linuxbrew/.linuxbrew/bin
elif [ -e "/opt/homebrew/bin/brew" ]; then
  export PATH=$PATH:/opt/homebrew/bin
fi

brew update
brew install fd fnm fish git-delta httpie lazygit nvim python3 ripgrep tree unzip
brew install ~/.config/guanghechen/config/homebrew/tmux.rb
brew pin tmux

### Install node
fish -c "fnm install 20"
fish -c "npm install -g npm yarn"

## Config

### fish
echo "$(which fish)" | sudo tee -a /etc/shells
chsh -s "$(which fish)"

### nvim
fish -c "cd ~/.config/nvim/rust/nvim_tools/ && bash build.sh"

### others
cp -f ~/.config/guanghechen/config/cargo.toml ~/.cargo/config.toml
cp -f ~/.config/guanghechen/config/.gitconfig ~/.gitconfig
