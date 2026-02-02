#! /usr/bin/env bash
# shellcheck disable=SC1091


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

# shellcheck source=setup/nix/path.sh
source "$HOME/.config/guanghechen/setup/nix/path.sh"

## Bootstrap
### Setup configs
printf "\n\e[96m  [setup config] preparing...\e[0m\n"
node "$HOME/.config/guanghechen/cli/setting.mjs" --set-edition osx
# shellcheck source=setup/nix/bot/config.sh
source "$HOME/.config/guanghechen/setup/nix/bot/config.sh"
printf "\e[92m  [setup config] done.\e[0m\n"

### Setup font
printf "\n\e[96m  [setup font] preparing...\e[0m\n"
# shellcheck source=setup/osx/bot/font-maple.sh
source "$HOME/.config/guanghechen/setup/osx/bot/font-maple.sh"
# source "$HOME/.config/guanghechen/setup/osx/bot/font-roboto.sh"
printf "\e[92m  [setup font] done.\e[0m\n"

### Setup homebrew
if [ -z "$HOME_HOMEBREW" ] || [ -w "$HOME_HOMEBREW/var/homebrew/locks" ]; then
  printf "\n\e[96m  [setup homebrew] preparing...\e[0m\n"
  # shellcheck source=setup/nix/bot/homebrew.sh
  source "$HOME/.config/guanghechen/setup/nix/bot/homebrew.sh"
  # shellcheck source=setup/osx/bot/homebrew-patch.sh
  source "$HOME/.config/guanghechen/setup/osx/bot/homebrew-patch.sh"
  printf "\e[92m  [setup homebrew] done.\e[0m\n"
fi

### Setup fish
printf "\n\e[96m  [setup fish] preparing...\e[0m\n"
# shellcheck source=setup/nix/bot/fish.sh
source "$HOME/.config/guanghechen/setup/nix/bot/fish.sh"
printf "\e[92m  [setup fish] done.\e[0m\n"

## Setup envs
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

### Setup bun
printf "\n\e[96m  [setup bun] preparing...\e[0m\n"
# shellcheck source=setup/nix/env/bun.sh
source "$HOME/.config/guanghechen/setup/nix/env/bun.sh"
printf "\e[92m  [setup bun] done.\e[0m\n"

### Setup node
printf "\n\e[96m  [setup node] preparing...\e[0m\n"
# shellcheck source=setup/nix/env/node.sh
source "$HOME/.config/guanghechen/setup/nix/env/node.sh"
printf "\e[92m  [setup node] done.\e[0m\n"

### Setup pnpm
printf "\n\e[96m  [setup pnpm] preparing...\e[0m\n"
# shellcheck source=setup/nix/env/pnpm.sh
source "$HOME/.config/guanghechen/setup/nix/env/pnpm.sh"
printf "\e[92m  [setup pnpm] done.\e[0m\n"

## Setup apps
### Setup newsboat
printf "\n\e[96m  [setup newsboat] preparing...\e[0m\n"
# shellcheck source=setup/nix/app/newsboat.sh
source "$HOME/.config/guanghechen/setup/nix/app/newsboat.sh"
printf "\e[92m  [setup newsboat] done.\e[0m\n"

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

### Setup vscode
printf "\n\e[96m  [setup vscode] preparing...\e[0m\n"
# shellcheck source=setup/nix/app/vscode.sh
source "$HOME/.config/guanghechen/setup/nix/app/vscode.sh"
printf "\e[92m  [setup vscode] done.\e[0m\n"

### Setup windows-terminal
printf "\n\e[96m  [setup windows-terminal] preparing...\e[0m\n"
# shellcheck source=setup/nix/app/windows-terminal.sh
source "$HOME/.config/guanghechen/setup/nix/app/windows-terminal.sh"
printf "\e[92m  [setup windows-terminal] done.\e[0m\n"

## Setup themes
printf "\n\e[96m  [setup theme] preparing...\e[0m\n"
node "$HOME/.config/guanghechen/cli/theme-apply.mjs"
printf "\e[92m  [setup theme] done.\e[0m\n"

printf "\n\e[95m ===== [setup settings] =====\e[0m\n"
printf "\n\e[96m  [setup settings] preparing...\e[0m\n"
printf "\e[92m  [setup settings] done.\e[0m\n"
