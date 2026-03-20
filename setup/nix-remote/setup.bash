#! /usr/bin/env bash

## Preparation
printf "\n\e[95m ===== [prepare] =====\e[0m\n"
sudo apt update
sudo apt dist-upgrade -y
sudo apt remove -y tmux
sudo apt install -y curl git locales traceroute wget
sudo apt install -y bash-completion build-essential libvips-dev unixodbc
sudo apt install -y clangd colordiff file fontconfig libunwind8 net-tools vim
sudo apt install -y wl-clipboard
sudo apt autoremove
sudo apt autoclean
printf "\e[92m  [preparation] done.\e[0m\n"

## Download core configurations
repomain="$HOME/.config/guanghechen"
repoworktree="$HOME/.config/kit"
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
source "$HOME/.config/guanghechen/setup/nix/bot/env.bash"

### Setup homebrew
if [ -z "$HOME_HOMEBREW" ] || [ -w "$HOME_HOMEBREW/var/homebrew/locks" ]; then
  printf "\n\e[96m  [setup homebrew] preparing...\e[0m\n"
  source "$HOME/.config/guanghechen/setup/nix/bot/homebrew.bash"
  printf "\e[92m  [setup homebrew] done.\e[0m\n"
fi

## Setup envs
printf "\n\e[95m ===== [setup env] =====\e[0m\n"
### Setup rust environment
printf "\n\e[96m  [setup rust] preparing...\e[0m\n"
source "$HOME/.config/guanghechen/setup/nix/env/rust.bash"
printf "\e[92m  [setup rust] done.\e[0m\n"

### Setup python environment
printf "\n\e[96m  [setup miniforge] preparing...\e[0m\n"
source "$HOME/.config/guanghechen/setup/nix/env/miniforge.bash"
printf "\e[92m  [setup miniforge] done.\e[0m\n"

### Setup node
printf "\n\e[96m  [setup node] preparing...\e[0m\n"
source "$HOME/.config/guanghechen/setup/nix-remote/env/node.bash"
printf "\e[92m  [setup node] done.\e[0m\n"

## Setup configs
### ensure kit worktree
if [ -e "$repoworktree/.git" ]; then
  printf "\e[93m  [setup config] %s already exists. (skipped worktree).\e[0m\n" "$repoworktree"
  git -C "$repoworktree" pull --ff-only origin kit
elif git -C "$repomain" show-ref --verify --quiet refs/heads/kit; then
  printf "\e[96m  [setup config] attaching existing branch kit to %s...\e[0m\n" "$repoworktree"
  git -C "$repomain" worktree add "$repoworktree" kit
else
  printf "\e[96m  [setup config] creating worktree %s from origin/kit...\e[0m\n" "$repoworktree"
  git -C "$repomain" fetch origin
  git -C "$repomain" worktree add --track -b kit "$repoworktree" origin/kit
fi

### Setup local settings
kit repo set config.edition "nix-remote"
kit repo sync

### Setup configs
printf "\n\e[96m  [setup config] preparing...\e[0m\n"
source "$HOME/.config/guanghechen/setup/nix/bot/config.bash"
printf "\e[92m  [setup config] done.\e[0m\n"

### Setup bash
printf "\n\e[96m  [setup bash] preparing...\e[0m\n"
source "$HOME/.config/bash/setup.bash"
printf "\e[92m  [setup bash] done.\e[0m\n"

## Setup apps

### Setup nvim
printf "\n\e[96m  [setup nvim] preparing...\e[0m\n"
source "$HOME/.config/guanghechen/setup/nix/app/nvim.bash"
printf "\e[92m  [setup nvim] done.\e[0m\n"

### Setup tmux
printf "\n\e[96m  [setup tmux] preparing...\e[0m\n"
source "$HOME/.config/guanghechen/setup/nix/app/tmux.bash"
printf "\e[92m  [setup tmux] done.\e[0m\n"

## Setup themes
printf "\n\e[96m  [setup theme] preparing...\e[0m\n"
node "$HOME/.config/guanghechen/cli/theme.mjs" apply
printf "\e[92m  [setup theme] done.\e[0m\n"

printf "\n\e[95m ===== [setup settings] =====\e[0m\n"
printf "\n\e[96m  [setup settings] preparing...\e[0m\n"
printf "\e[92m  [setup settings] done.\e[0m\n"
