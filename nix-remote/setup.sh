#! /usr/bin/env bash
# shellcheck disable=SC1091

GHC_CONFIG_ROOT="${GHC_CONFIG_ROOT:-$HOME/.config/guanghechen}"
export GHC_CONFIG_ROOT

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
repomain="$GHC_CONFIG_ROOT"
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

## Bootstrap
printf "\n\e[95m ===== [bootstrap] =====\e[0m\n"
### Setup configs
printf "\n\e[96m  [setup config] preparing...\e[0m\n"
# shellcheck source=nix-remote/setup/bot/config.sh
source "$GHC_CONFIG_ROOT/nix-remote/setup/bot/config.sh"
printf "\e[92m  [setup config] done.\e[0m\n"

### Setup font
printf "\n\e[96m  [setup font] preparing...\e[0m\n"
# shellcheck source=nix/setup/bot/font-maple.sh
source "$GHC_CONFIG_ROOT/nix/setup/bot/font-maple.sh"
printf "\e[92m  [setup font] done.\e[0m\n"

### Setup homebrew
if [ -z "$HOME_HOMEBREW" ] || [ -w "$HOME_HOMEBREW/var/homebrew/locks" ]; then
  printf "\n\e[96m  [setup homebrew] preparing...\e[0m\n"
  # shellcheck source=nix/setup/bot/homebrew.sh
  source "$GHC_CONFIG_ROOT/nix/setup/bot/homebrew.sh"
  printf "\e[92m  [setup homebrew] done.\e[0m\n"
fi

### Setup fish
printf "\n\e[96m  [setup fish] preparing...\e[0m\n"
# shellcheck source=nix/setup/bot/fish.sh
source "$GHC_CONFIG_ROOT/nix/setup/bot/fish.sh"
printf "\e[92m  [setup fish] done.\e[0m\n"

## Setup envs
printf "\n\e[95m ===== [setup env] =====\e[0m\n"
### Setup rust environment
printf "\n\e[96m  [setup rust] preparing...\e[0m\n"
# shellcheck source=nix/setup/env/rust.sh
source "$GHC_CONFIG_ROOT/nix/setup/env/rust.sh"
printf "\e[92m  [setup rust] done.\e[0m\n"

### Setup python environment
printf "\n\e[96m  [setup miniforge] preparing...\e[0m\n"
# shellcheck source=nix/setup/env/miniforge.sh
source "$GHC_CONFIG_ROOT/nix/setup/env/miniforge.sh"
printf "\e[92m  [setup miniforge] done.\e[0m\n"

### Setup node
printf "\n\e[96m  [setup node] preparing...\e[0m\n"
# shellcheck source=nix-remote/setup/env/node.sh
source "$GHC_CONFIG_ROOT/nix-remote/setup/env/node.sh"
printf "\e[92m  [setup node] done.\e[0m\n"

### Setup pnpm
printf "\n\e[96m  [setup pnpm] preparing...\e[0m\n"
# shellcheck source=nix/setup/env/pnpm.sh
source "$GHC_CONFIG_ROOT/nix/setup/env/pnpm.sh"
printf "\e[92m  [setup pnpm] done.\e[0m\n"

## Setup apps

### Setup nvim
printf "\n\e[96m  [setup nvim] preparing...\e[0m\n"
# shellcheck source=nix/setup/app/nvim.sh
source "$GHC_CONFIG_ROOT/nix/setup/app/nvim.sh"
printf "\e[92m  [setup nvim] done.\e[0m\n"

### Setup tmux
printf "\n\e[96m  [setup tmux] preparing...\e[0m\n"
# shellcheck source=nix/setup/app/tmux.sh
source "$GHC_CONFIG_ROOT/nix/setup/app/tmux.sh"
printf "\e[92m  [setup tmux] done.\e[0m\n"

## Setup themes
printf "\n\e[96m  [setup theme] preparing...\e[0m\n"
# shellcheck source=nix/setup/theme.sh
source "$GHC_CONFIG_ROOT/nix/setup/theme.sh"
printf "\e[92m  [setup theme] done.\e[0m\n"
