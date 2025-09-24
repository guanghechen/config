#! /usr/bin/env bash

if [ ! -f "/home/linuxbrew/.linuxbrew/bin/brew" ] && [ ! -f "/opt/homebrew/bin/brew" ]; then
  printf "\n\e[94m  [setup homebrew] installing homebrew...\e[0m\n"
  yes | /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

printf "\n\e[94m  [setup homebrew] updating...\e[0m\n"
source $HOME/.config/guanghechen/nix/setup/path.sh
brew update

### Install node
printf "\n\e[94m  [setup homebrew] installing fnm...\e[0m\n"
brew install fnm pnpm

### Install python
printf "\n\e[94m  [setup homebrew] installing uv...\e[0m\n"
brew install uv

### Install nvim
printf "\n\e[94m  [setup homebrew] installing nvim...\e[0m\n"
brew install nvim fd git-delta lazygit ripgrep

### Install tmux
brew install tmux
# printf "\n\e[94m  [setup homebrew] installing tmux...\e[0m\n"
# brew install $HOME/.config/guanghechen/config/app/homebrew/tmux.rb
# brew pin tmux

### Install yazi
printf "\n\e[94m  [setup homebrew] installing yazi...\e[0m\n"
brew install yazi ffmpegthumbnailer imagemagick jq poppler sevenzip starship jstkdng/programs/ueberzugpp

### Install hardware utilities (cpu/memo/disk/network)
printf "\n\e[94m  [setup homebrew] installing hardware utilities (cpu/memo/disk/network)...\e[0m\n"
brew install btop fastfetch httpie

### Install usual tools
printf "\n\e[94m  [setup homebrew] installing usual tools...\n"
brew install automake bat duf ffmpeg fzf hyperfine jq lsd scc tldr tree tty-clock unzip zoxide
