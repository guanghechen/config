#! /usr/bin/bash

## Update system
sudo apt update
sudo apt dist-upgrade -y
sudo apt install -y gcc clangd git curl wget
sudo apt remove -y tmux vim

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

### Install homebrew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
if [ -e "/home/linuxbrew/.linuxbrew/bin/brew" ]; then
  export PATH=$PATH:/home/linuxbrew/.linuxbrew/bin
elif [ -e "/opt/homebrew/bin/brew" ]; then
  export PATH=$PATH:/opt/homebrew/bin
fi

### Install rust
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

### Install apps
brew update
brew install fd fnm fish git-delta httpie lazygit nvim python3 ripgrep tree unzip
brew install ~/.config/guanghechen/config/homebrew/tmux.rb
brew pin tmux

### Install node
fnm install 20
npm install -g npm yarn

## Config

### Set fish as the default shell
sudo echo "$(which fish)" >>/etc/shells
chsh -s "$(which fish)"

### Config cargo
_cargo_config='
[target.x86_64-apple-darwin]
rustflags = [
"-C", "link-arg=-undefined",
"-C", "link-arg=dynamic_lookup",
]

[target.aarch64-apple-darwin]
rustflags = [
"-C", "link-arg=-undefined",
"-C", "link-arg=dynamic_lookup",
]
'
echo "${_cargo_config}" >~/.cargo/config.toml

### Config nvim
fish -c "cd ~/.config/nvim/rust/nvim_tools/ && bash build.sh"

## anaconda
# mkdir -p ~/download && cd ~/download
# wget <anaconda installer url>
# export PYTHONIOENCODING=utf8
# export PYTHONUTF8=1
# bash <anaconda installer>
