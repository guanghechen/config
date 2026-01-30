#! /usr/bin/env bash
# shellcheck disable=SC1091

GHC_CONFIG_ROOT="${GHC_CONFIG_ROOT:-$HOME/.config/guanghechen}"
export GHC_CONFIG_ROOT

# shellcheck source=nix/setup/path.sh
source "$GHC_CONFIG_ROOT/nix/setup/path.sh"

## Setup vscode
printf "\e[96m  [setup vscode] set vscode...\e[0m\n"
fish -c "node \"$GHC_CONFIG_ROOT/config/app/vscode/keybinding/index.mjs\""
