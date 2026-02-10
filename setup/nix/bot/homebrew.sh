#! /usr/bin/env bash
# shellcheck disable=SC1091


if [ ! -f "/home/linuxbrew/.linuxbrew/bin/brew" ] && [ ! -f "/opt/homebrew/bin/brew" ]; then
  printf "\e[96m  [setup homebrew] installing homebrew...\e[0m\n"
  yes | /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  printf "\e[96m  [setup homebrew] updating...\e[0m\n"
else
  printf "\e[96m  [setup homebrew] updating...\e[0m\n"
fi
# shellcheck source=setup/nix/bot/env.sh
source "$HOME/.config/guanghechen/setup/nix/bot/env.sh"
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

### Install usual tools
printf "\e[96m  [setup homebrew] installing usual tools...\e[0m\n"
brew install automake bat duf ffmpeg fzf git-lfs hyperfine jq lsd scc tldr tree tty-clock unzip zoxide
