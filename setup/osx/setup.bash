#! /usr/bin/env bash

## Download core configurations
reporoot="$HOME/.config"
repomain="$HOME/.config/guanghechen"
if [ -e "$repomain/.git" ]; then
  git -C "$repomain" fetch origin
  git -C "$repomain" merge origin/guanghechen --ff-only
else
  mkdir -p "$repomain"
  git clone https://github.com/guanghechen/config.git --branch=guanghechen "$repomain"
fi

## Bootstrap
source "$HOME/.config/guanghechen/env/setting.bash"

### Setup homebrew
if [ -z "$HOME_HOMEBREW" ] || [ -w "$HOME_HOMEBREW/var/homebrew/locks" ]; then
  printf "\n\e[96m  [setup homebrew] preparing...\e[0m\n"
  source "$HOME/.config/guanghechen/setup/nix/bot/homebrew.bash"
  source "$HOME/.config/guanghechen/setup/osx/bot/homebrew-patch.bash"
  printf "\e[92m  [setup homebrew] done.\e[0m\n"
fi

## Setup envs
### Setup rust environment
printf "\n\e[96m  [setup rust] preparing...\e[0m\n"
source "$HOME/.config/guanghechen/setup/nix/env/rust.bash"
printf "\e[92m  [setup rust] done.\e[0m\n"

### Setup python environment
printf "\n\e[96m  [setup miniforge] preparing...\e[0m\n"
source "$HOME/.config/guanghechen/setup/nix/env/miniforge.bash"
printf "\e[92m  [setup miniforge] done.\e[0m\n"

### Setup bun
printf "\n\e[96m  [setup bun] preparing...\e[0m\n"
source "$HOME/.config/guanghechen/setup/nix/env/bun.bash"
printf "\e[92m  [setup bun] done.\e[0m\n"

### Setup fish
printf "\n\e[96m  [setup fish] preparing...\e[0m\n"
source "$HOME/.config/guanghechen/setup/nix/bot/fish.bash"
printf "\e[92m  [setup fish] done.\e[0m\n"

### Setup node
printf "\n\e[96m  [setup node] preparing...\e[0m\n"
source "$HOME/.config/guanghechen/setup/nix/env/node.bash"
printf "\e[92m  [setup node] done.\e[0m\n"

### Setup pnpm
printf "\n\e[96m  [setup pnpm] preparing...\e[0m\n"
source "$HOME/.config/guanghechen/setup/nix/env/pnpm.bash"
printf "\e[92m  [setup pnpm] done.\e[0m\n"

## Setup configs
### Setup local settings
node "$HOME/.config/guanghechen/cli/setting.mjs" --set-edition osx

### Setup xdg configs
printf "\n\e[96m  [setup config] preparing...\e[0m\n"
source "$HOME/.config/guanghechen/setup/nix/bot/config.bash"
printf "\e[92m  [setup config] done.\e[0m\n"

## Setup apps
### Setup newsboat
printf "\n\e[96m  [setup newsboat] preparing...\e[0m\n"
source "$HOME/.config/guanghechen/setup/nix/app/newsboat.bash"
printf "\e[92m  [setup newsboat] done.\e[0m\n"

### Setup nvim
printf "\n\e[96m  [setup nvim] preparing...\e[0m\n"
source "$HOME/.config/guanghechen/setup/nix/app/nvim.bash"
printf "\e[92m  [setup nvim] done.\e[0m\n"

### Setup tmux
printf "\n\e[96m  [setup tmux] preparing...\e[0m\n"
source "$HOME/.config/guanghechen/setup/nix/app/tmux.bash"
printf "\e[92m  [setup tmux] done.\e[0m\n"

### Setup vscode
printf "\n\e[96m  [setup vscode] preparing...\e[0m\n"
source "$HOME/.config/guanghechen/setup/nix/app/vscode.bash"
printf "\e[92m  [setup vscode] done.\e[0m\n"

### Setup windows-terminal
printf "\n\e[96m  [setup windows-terminal] preparing...\e[0m\n"
source "$HOME/.config/guanghechen/setup/nix/app/windows-terminal.bash"
printf "\e[92m  [setup windows-terminal] done.\e[0m\n"

## Setup font
printf "\n\e[96m  [setup font] preparing...\e[0m\n"
source "$HOME/.config/guanghechen/setup/osx/bot/font-maple.bash"
# source "$HOME/.config/guanghechen/setup/osx/bot/font-roboto.bash"
printf "\e[92m  [setup font] done.\e[0m\n"

## Setup themes
printf "\n\e[96m  [setup theme] preparing...\e[0m\n"
node "$HOME/.config/guanghechen/cli/theme.mjs" apply
printf "\e[92m  [setup theme] done.\e[0m\n"

printf "\n\e[95m ===== [setup settings] =====\e[0m\n"
printf "\n\e[96m  [setup settings] preparing...\e[0m\n"
printf "\e[92m  [setup settings] done.\e[0m\n"
