#! /usr/bin/env bash
# shellcheck disable=SC1091


## Preparation
printf "\n\e[95m ===== [prepare] =====\e[0m\n"
sudo apt update
sudo apt dist-upgrade -y
# sudo apt remove -y tmux
sudo apt install -y curl git locales wget
sudo apt install -y build-essential libvips-dev unixodbc
sudo apt install -y clangd colordiff file fontconfig libunwind8 net-tools vim
sudo apt install -y wl-clipboard
sudo apt autoremove
sudo apt autoclean
printf "\e[92m  [preparation] done.\e[0m\n"

## Download core configurations
repomain="$HOME/.config/guanghechen"
if [ -e "$repomain/.git" ]; then
  git -C "$repomain" fetch origin
  git -C "$repomain" merge origin/guanghechen --ff-only
else
  mkdir -p "$repomain"
  git clone https://github.com/guanghechen/config.git --branch=guanghechen "$repomain"
fi

## Fix locale issues
sudo locale-gen en_US.UTF-8
sudo update-locale LANG=en_US.UTF-8

# shellcheck source=env/setting.sh
source "$HOME/.config/guanghechen/env/setting.sh"

## Bootstrap
printf "\n\e[95m ===== [bootstrap] =====\e[0m\n"

### Setup configs
printf "\n\e[96m  [setup config] preparing...\e[0m\n"
# shellcheck source=setup/nix-remote/bot/config.sh
source "$HOME/.config/guanghechen/setup/nix-remote/bot/config.sh"
printf "\e[92m  [setup config] done.\e[0m\n"

### Setup homebrew
if [ -z "$HOME_HOMEBREW" ] || [ -w "$HOME_HOMEBREW/var/homebrew/locks" ]; then
  printf "\n\e[96m  [setup homebrew] preparing...\e[0m\n"
  # shellcheck source=setup/nix/bot/homebrew.sh
  source "$HOME/.config/guanghechen/setup/nix/bot/homebrew.sh"
  printf "\e[92m  [setup homebrew] done.\e[0m\n"
fi

### Setup fish
printf "\n\e[96m  [setup fish] preparing...\e[0m\n"
# shellcheck source=setup/nix/bot/fish.sh
source "$HOME/.config/guanghechen/setup/nix/bot/fish.sh"
printf "\e[92m  [setup fish] done.\e[0m\n"

## Setup envs
printf "\n\e[95m ===== [setup env] =====\e[0m\n"
### Setup rust environment
printf "\n\e[96m  [setup rust] preparing...\e[0m\n"
# shellcheck source=setup/nix/env/rust.sh
source "$HOME/.config/guanghechen/setup/nix/env/rust.sh"
printf "\e[92m  [setup rust] done.\e[0m\n"

### Setup python environment
printf "\n\e[96m  [setup miniforge] preparing...\e[0m\n"
# shellcheck source=setup/nix/env/miniforge.sh
source "$HOME/.config/guanghechen/setup/nix/env/miniforge.sh"
printf "\e[92m  [setup miniforge] done.\e[0m\n"

### Setup node
printf "\n\e[96m  [setup node] preparing...\e[0m\n"
# shellcheck source=setup/nix-remote/env/node.sh
source "$HOME/.config/guanghechen/setup/nix-remote/env/node.sh"
printf "\e[92m  [setup node] done.\e[0m\n"

### Generate local settings
node "$HOME/.config/guanghechen/cli/setting.mjs" --set-edition nix-remote

## Setup apps

### Setup nvim
printf "\n\e[96m  [setup nvim] preparing...\e[0m\n"
# shellcheck source=setup/nix/app/nvim.sh
source "$HOME/.config/guanghechen/setup/nix/app/nvim.sh"
printf "\e[92m  [setup nvim] done.\e[0m\n"

### Setup tmux
printf "\n\e[96m  [setup tmux] preparing...\e[0m\n"
# shellcheck source=setup/nix/app/tmux.sh
source "$HOME/.config/guanghechen/setup/nix/app/tmux.sh"
printf "\e[92m  [setup tmux] done.\e[0m\n"

## Setup themes
printf "\n\e[96m  [setup theme] preparing...\e[0m\n"
node "$HOME/.config/guanghechen/cli/theme.mjs" apply
printf "\e[92m  [setup theme] done.\e[0m\n"

printf "\n\e[95m ===== [setup settings] =====\e[0m\n"
printf "\n\e[96m  [setup settings] preparing...\e[0m\n"
printf "\e[92m  [setup settings] done.\e[0m\n"
