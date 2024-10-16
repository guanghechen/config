#! /usr/bin/env bash

echo -e "\e[34m  [setup homebrew] installing homebrew...\e[0m"
yes | /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
if [ -e "/home/linuxbrew/.linuxbrew/bin/brew" ]; then
  export PATH=$PATH:/home/linuxbrew/.linuxbrew/bin
elif [ -e "/opt/homebrew/bin/brew" ]; then
  export PATH=$PATH:/opt/homebrew/bin
fi
brew update

### Setup fish
echo -e "\n\e[34m  [setup homebrew] setting up fish...\e[0m"
brew install fish
echo "$(which fish)" | sudo tee -a /etc/shells
chsh -s "$(which fish)"

### Setup node
echo -e "\n\e[34m  [setup homebrew] setting up node...\e[0m"
brew install fnm
fnm install 20
fish -c "npm install -g npm yarn"

### Setup nvim
echo -e "\n\e[34m  [setup homebrew] setting up nvim...\e[0m"
brew install nvim fd git-delta lazygit ripgrep
fish -c "cd ~/.config/nvim/rust/nvim_tools/ && bash build.sh"

### Setup tmux
echo -e "\n\e[34m  [setup homebrew] setting up tmux...\e[0m"
brew install ~/.config/guanghechen/config/homebrew/tmux.rb
brew pin tmux

### Setup hardware utilities (cpu/memo/disk/network)
echo -e "\n\e[34m  [setup homebrew] setting up hardware utilities (cpu/memo/disk/network)...\e[0m"
brew install btop fastfetch httpie

### Setup usual tools
echo -e "\n\e[34m  [setup homebrew] setting up usual tools..."
brew install bat ffmpeg fzf hyperfine jq lsd scc tldr tree unzip you-get zoxide

echo -e "\e[32m  [setup homebrew] done."
