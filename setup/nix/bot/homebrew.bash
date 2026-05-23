#! /usr/bin/env bash

if [ ! -f "/home/linuxbrew/.linuxbrew/bin/brew" ] && [ ! -f "/opt/homebrew/bin/brew" ] && [ ! -f "/usr/local/bin/brew" ]; then
  printf "\e[96m  [setup homebrew] installing homebrew...\e[0m\n"
  if [ -n "${CI:-}" ] || [ "${GHC_NONINTERACTIVE:-}" = "1" ] || [ ! -t 0 ]; then
    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  else
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  fi
  printf "\e[96m  [setup homebrew] updating...\e[0m\n"
else
  printf "\e[96m  [setup homebrew] updating...\e[0m\n"
fi
source "$HOME/.config/guanghechen/setup/nix/bot/env.bash"
brew update

### Install node
printf "\e[96m  [setup homebrew] installing fnm...\e[0m\n"
brew install fnm

### Install python
printf "\e[96m  [setup homebrew] installing uv...\e[0m\n"
brew install uv

### Install nvim
printf "\e[96m  [setup homebrew] installing nvim...\e[0m\n"
brew install nvim fd git-delta lazygit ripgrep

### Install yazi
printf "\e[96m  [setup homebrew] installing yazi...\e[0m\n"
brew install yazi ffmpegthumbnailer imagemagick jq poppler sevenzip starship jstkdng/programs/ueberzugpp

### Install hardware utilities (cpu/memo/disk/network)
printf "\e[96m  [setup homebrew] installing hardware utilities (cpu/memo/disk/network)...\e[0m\n"
brew install btop fastfetch httpie

### Install github cli
printf "\e[96m  [setup homebrew] installing github cli...\e[0m\n"
brew install gh

### Install usual tools
printf "\e[96m  [setup homebrew] installing usual tools...\e[0m\n"
brew install automake bat duf ffmpeg fzf git-lfs hyperfine jq lsd scc tldr tree tty-clock unzip yt-dlp zoxide
