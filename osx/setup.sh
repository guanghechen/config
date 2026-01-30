#! /usr/bin/env bash
# shellcheck disable=SC1091

## Download core configurations
reporoot="$HOME/.config"
repomain="$reporoot/guanghechen"
if [ -e "$repomain/.git" ]; then
  git -C "$repomain" fetch origin
  git -C "$repomain" merge origin/guanghechen --ff-only
else
  mkdir -p "$repomain"
  git clone https://github.com/guanghechen/config.git --branch=guanghechen "$repomain"
fi

# shellcheck source=nix/setup/path.sh
source "$HOME/.config/guanghechen/nix/setup/path.sh"

## Bootstrap
### Setup configs
printf "\n\e[96m  [setup config] preparing...\e[0m\n"
# shellcheck source=nix/setup/bot/config.sh
source "$HOME/.config/guanghechen/nix/setup/bot/config.sh"
printf "\e[92m  [setup config] done.\e[0m\n"

### Setup font
printf "\n\e[96m  [setup font] preparing...\e[0m\n"
# shellcheck source=osx/setup/bot/font-maple.sh
source "$HOME/.config/guanghechen/osx/setup/bot/font-maple.sh"
# source ~/.config/guanghechen/osx/setup/bot/font-roboto.sh
printf "\e[92m  [setup font] done.\e[0m\n"

### Setup homebrew
if [ -z "$HOME_HOMEBREW" ] || [ -w "$HOME_HOMEBREW/var/homebrew/locks" ]; then
  printf "\n\e[96m  [setup homebrew] preparing...\e[0m\n"
  # shellcheck source=nix/setup/bot/homebrew.sh
  source "$HOME/.config/guanghechen/nix/setup/bot/homebrew.sh"
  # shellcheck source=osx/setup/bot/homebrew-patch.sh
  source "$HOME/.config/guanghechen/osx/setup/bot/homebrew-patch.sh"
  printf "\e[92m  [setup homebrew] done.\e[0m\n"
fi

### Setup fish
printf "\n\e[96m  [setup fish] preparing...\e[0m\n"
# shellcheck source=nix/setup/bot/fish.sh
source "$HOME/.config/guanghechen/nix/setup/bot/fish.sh"
printf "\e[92m  [setup fish] done.\e[0m\n"

## Setup envs
### Setup rust environment
printf "\n\e[96m  [setup rust] preparing...\e[0m\n"
# shellcheck source=nix/setup/env/rust.sh
source "$HOME/.config/guanghechen/nix/setup/env/rust.sh"
printf "\e[92m  [setup rust] done.\e[0m\n"

### Setup python environment
printf "\n\e[96m  [setup miniforge] preparing...\e[0m\n"
# shellcheck source=nix/setup/env/miniforge.sh
source "$HOME/.config/guanghechen/nix/setup/env/miniforge.sh"
printf "\e[92m  [setup miniforge] done.\e[0m\n"

### Setup bun
printf "\n\e[96m  [setup bun] preparing...\e[0m\n"
# shellcheck source=nix/setup/env/bun.sh
source "$HOME/.config/guanghechen/nix/setup/env/bun.sh"
printf "\e[92m  [setup bun] done.\e[0m\n"

### Setup node
printf "\n\e[96m  [setup node] preparing...\e[0m\n"
# shellcheck source=nix/setup/env/node.sh
source "$HOME/.config/guanghechen/nix/setup/env/node.sh"
printf "\e[92m  [setup node] done.\e[0m\n"

### Setup pnpm
printf "\n\e[96m  [setup pnpm] preparing...\e[0m\n"
# shellcheck source=nix/setup/env/pnpm.sh
source "$HOME/.config/guanghechen/nix/setup/env/pnpm.sh"
printf "\e[92m  [setup pnpm] done.\e[0m\n"

## Setup apps
### Setup newsboat
printf "\n\e[96m  [setup newsboat] preparing...\e[0m\n"
# shellcheck source=nix/setup/app/newsboat.sh
source "$HOME/.config/guanghechen/nix/setup/app/newsboat.sh"
printf "\e[92m  [setup newsboat] done.\e[0m\n"

### Setup nvim
printf "\n\e[96m  [setup nvim] preparing...\e[0m\n"
# shellcheck source=nix/setup/app/nvim.sh
source "$HOME/.config/guanghechen/nix/setup/app/nvim.sh"
printf "\e[92m  [setup nvim] done.\e[0m\n"

### Setup tmux
printf "\n\e[96m  [setup tmux] preparing...\e[0m\n"
# shellcheck source=nix/setup/app/tmux.sh
source "$HOME/.config/guanghechen/nix/setup/app/tmux.sh"
printf "\e[92m  [setup tmux] done.\e[0m\n"

### Setup vscode
printf "\n\e[96m  [setup vscode] preparing...\e[0m\n"
# shellcheck source=nix/setup/app/vscode.sh
source "$HOME/.config/guanghechen/nix/setup/app/vscode.sh"
printf "\e[92m  [setup vscode] done.\e[0m\n"

### Setup windows-terminal
printf "\n\e[96m  [setup windows-terminal] preparing...\e[0m\n"
# shellcheck source=nix/setup/app/windows-terminal.sh
source "$HOME/.config/guanghechen/nix/setup/app/windows-terminal.sh"
printf "\e[92m  [setup windows-terminal] done.\e[0m\n"

## Setup themes
printf "\n\e[96m  [setup theme] preparing...\e[0m\n"
# shellcheck source=nix/setup/theme.sh
source "$HOME/.config/guanghechen/nix/setup/theme.sh"
printf "\e[92m  [setup theme] done.\e[0m\n"
