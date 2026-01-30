#! /usr/bin/env bash
# shellcheck disable=SC1091

GHC_CONFIG_ROOT="${GHC_CONFIG_ROOT:-$HOME/.config/guanghechen}"
export GHC_CONFIG_ROOT

## Preparation
sudo apt update
sudo apt dist-upgrade -y
sudo apt remove -y tmux
sudo apt install -y curl git locales wget
sudo apt install -y build-essential libvips-dev unixodbc
sudo apt install -y clangd colordiff file fontconfig libunwind8 net-tools vim
sudo apt install -y wl-clipboard
sudo apt autoremove
sudo apt autoclean
printf "\e[92m  [preparation] done.\e[0m\n"

## Download core configurations
reporoot="$HOME/.config"
repomain="$GHC_CONFIG_ROOT"
if [ -e "$repomain/.git" ]; then
  git -C "$repomain" fetch origin
  git -C "$repomain" merge origin/guanghechen --ff-only
else
  mkdir -p "$repomain"
  git clone https://github.com/guanghechen/config.git --branch=guanghechen "$repomain"
fi

# shellcheck source=nix/setup/path.sh
source "$GHC_CONFIG_ROOT/nix/setup/path.sh"

## Fix locale issues
sudo locale-gen en_US.UTF-8
sudo update-locale LANG=en_US.UTF-8
