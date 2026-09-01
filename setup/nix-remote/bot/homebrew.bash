#! /usr/bin/env bash

if [ ! -f "/home/linuxbrew/.linuxbrew/bin/brew" ] && [ ! -f "/opt/homebrew/bin/brew" ] && [ ! -f "/usr/local/bin/brew" ]; then
  printf "\e[96minstalling Homebrew...\e[0m\n"
  if [ -n "${CI:-}" ] || [ "${GHC_NONINTERACTIVE:-}" = "1" ] || [ ! -t 0 ]; then
    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  else
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  fi
  printf "\e[96mupdating Homebrew...\e[0m\n"
else
  printf "\e[96mupdating Homebrew...\e[0m\n"
fi
source "$HOME/.config/guanghechen/setup/nix/bot/env.bash"
brew update

### Install node
printf "\e[96minstalling fnm...\e[0m\n"
brew install -y fnm

### Install node package manager
printf "\e[96minstalling pnpm...\e[0m\n"
brew install -y pnpm

### Install python
printf "\e[96minstalling Python...\e[0m\n"
brew install -y python3

### Install nvim
printf "\e[96minstalling Neovim tools...\e[0m\n"
brew install -y nvim fd git-delta lazygit ripgrep

### Install yazi
printf "\e[96minstalling Yazi tools...\e[0m\n"
brew install -y yazi ffmpegthumbnailer imagemagick jq poppler sevenzip starship jstkdng/programs/ueberzugpp

### Install hardware utilities (cpu/memo/disk/network)
printf "\e[96minstalling hardware utilities...\e[0m\n"
brew install -y btop fastfetch httpie

### Install usual tools
printf "\e[96minstalling general CLI tools...\e[0m\n"
brew install -y automake bat duf ffmpeg fzf git-lfs hyperfine jq lsd tree unzip yt-dlp zoxide
