#! /usr/bin/env bash

if [ ! -f "/home/linuxbrew/.linuxbrew/bin/brew" ] && [ ! -f "/opt/homebrew/bin/brew" ]; then
  printf "\n\e[34m  [setup homebrew] installing homebrew...\e[0m\n"
  yes | /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

printf "\n\e[34m  [setup homebrew] updating...\e[0m\n"
if [ -e "/home/linuxbrew/.linuxbrew/bin/brew" ]; then
  export HOME_HOMEBREW=/home/linuxbrew/.linuxbrew
elif [ -e "/opt/homebrew/bin/brew" ]; then
  export HOME_HOMEBREW=/opt/homebrew
fi
export PATH=$PATH:"$HOME_HOMEBREW/bin"
brew update

### Install git
brew tap microsoft/git
brew install --cask git-credential-manager

### Install node
printf "\n\e[34m  [setup homebrew] installing fnm...\e[0m\n"
brew install fnm

### Install nvim
printf "\n\e[34m  [setup homebrew] installing nvim...\e[0m\n"
brew install nvim fd git-delta lazygit ripgrep

### Install tmux
printf "\n\e[34m  [setup homebrew] installing tmux...\e[0m\n"
brew install ~/.config/guanghechen/config/homebrew/tmux.rb
brew pin tmux

### Install yazi
printf "\n\e[34m  [setup homebrew] installing yazi...\e[0m\n"
brew install yazi ffmpegthumbnailer jq imagemagick

### Install hardware utilities (cpu/memo/disk/network)
printf "\n\e[34m  [setup homebrew] installing hardware utilities (cpu/memo/disk/network)...\e[0m\n"
brew install btop fastfetch httpie

### Install usual tools
printf "\n\e[34m  [setup homebrew] installing usual tools...\n"
brew install bat ffmpeg fzf hyperfine jq lsd scc tldr tree unzip you-get zoxide
