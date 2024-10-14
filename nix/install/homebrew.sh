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

### Setup fish
brew install fish
echo "$(which fish)" | sudo tee -a /etc/shells
chsh -s "$(which fish)"

### Setup node
brew install fnm
fnm install 20
fish -c "npm install -g npm yarn"

### Setup nvim
brew install nvim fd git-delta lazygit ripgrep
fish -c "cd ~/.config/nvim/rust/nvim_tools/ && bash build.sh"

### Setup tmux
brew install ~/.config/guanghechen/config/homebrew/tmux.rb
brew pin tmux

### Setup other tools
brew install bat fastfetch ffmpeg fzf httpie jq lsd tldr tree unzip you-get zoxide
