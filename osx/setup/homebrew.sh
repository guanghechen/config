#! /usr/bin/env bash

if [ ! -f "/home/linuxbrew/.linuxbrew/bin/brew" ] && [ ! -f "/opt/homebrew/bin/brew" ]; then
  printf "\n\e[34m  [setup homebrew] installing homebrew...\e[0m\n"
  yes | /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

printf "\n\e[34m  [setup homebrew] updating...\e[0m\n"
if [ -e "/home/linuxbrew/.linuxbrew/bin/brew" ]; then
  export PATH=$PATH:/home/linuxbrew/.linuxbrew/bin
elif [ -e "/opt/homebrew/bin/brew" ]; then
  export PATH=$PATH:/opt/homebrew/bin
fi
brew update

### Setup fish
fish_path=$(which fish)
if [[ 
  -n "$fish_path" &&
  $(
    grep -Fxq "$fish_path" /etc/shells
    echo $?
  ) -eq 0 ]]; then
  printf "\n\e[38;5;214m  [setup homebrew] fish is already setted up. (skipped)\e[0m\n"
else
  printf "\n\e[34m  [setup homebrew] setting up fish...\e[0m\n"
  brew install fish
  echo "$fish_path" | sudo tee -a /etc/shells
  chsh -s "$fish_path"
fi

### Setup git
brew tap microsoft/git
brew install --cask git-credential-manager

### Setup node
printf "\n\e[34m  [setup homebrew] setting up node...\e[0m\n"
brew install fnm
fnm install 20
fish -c "npm install -g npm yarn"

### Setup nvim
printf "\n\e[34m  [setup homebrew] setting up nvim...\e[0m\n"
brew install nvim fd git-delta lazygit ripgrep
fish -c "cd ~/.config/nvim/rust/nvim_tools/ && bash build.sh"

### Setup tmux
printf "\n\e[34m  [setup homebrew] setting up tmux...\e[0m\n"
brew install ~/.config/guanghechen/config/homebrew/tmux.rb
brew pin tmux

### Setup yazi
printf "\n\e[34m  [setup homebrew] setting up yazi...\e[0m\n"
brew install yazi ffmpegthumbnailer jq imagemagick

### Setup hardware utilities (cpu/memo/disk/network)
printf "\n\e[34m  [setup homebrew] setting up hardware utilities (cpu/memo/disk/network)...\e[0m\n"
brew install btop fastfetch httpie

### Setup usual tools
printf "\n\e[34m  [setup homebrew] setting up usual tools...\n"
brew install bat ffmpeg fzf hyperfine jq lsd scc tldr tree unzip you-get zoxide
