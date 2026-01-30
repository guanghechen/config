#! /usr/bin/env bash
# shellcheck disable=SC1091

# shellcheck source=nix/setup/path.sh
source "$HOME/.config/guanghechen/nix/setup/path.sh"

## Setup vscode
printf "\e[96m  [setup vscode] set vscode...\e[0m\n"
fish -c "node ~/.config/guanghechen/config/app/vscode/keybinding/index.mjs"
