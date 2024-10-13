#! /usr/bin/env bash

### Install homebrew
yes | /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
if [ -e "/home/linuxbrew/.linuxbrew/bin/brew" ]; then
  export PATH=$PATH:/home/linuxbrew/.linuxbrew/bin
elif [ -e "/opt/homebrew/bin/brew" ]; then
  export PATH=$PATH:/opt/homebrew/bin
fi

### Install apps through homebrew
brew update
brew install bat fastfetch fd ffmpeg fish fnm fzf git-delta httpie lazygit lsd nvim ripgrep tldr tree unzip you-get
brew install ~/.config/guanghechen/config/homebrew/tmux.rb
brew pin tmux

### Setup fish
echo "$(which fish)" | sudo tee -a /etc/shells
chsh -s "$(which fish)"

### Setup node
fnm install 20
fish -c "npm install -g npm yarn"

### Setup nvim
fish -c "cd ~/.config/nvim/rust/nvim_tools/ && bash build.sh"
