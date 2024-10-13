#! /usr/bin/env bash

### Install homebrew
yes | /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
if [ -e "/home/linuxbrew/.linuxbrew/bin/brew" ]; then
  export PATH=$PATH:/home/linuxbrew/.linuxbrew/bin
elif [ -e "/opt/homebrew/bin/brew" ]; then
  export PATH=$PATH:/opt/homebrew/bin
fi

brew update
brew install bat fastfetch fd ffmpeg fish fnm fzf git-delta lazygit lsd nvim ripgrep tree unzip
brew install ~/.config/guanghechen/config/homebrew/tmux.rb
brew pin tmux

### Setup fish
echo "$(which fish)" | sudo tee -a /etc/shells
chsh -s "$(which fish)"
