#! /usr/bin/env bash
# shellcheck disable=SC1091

GHC_CONFIG_ROOT="${GHC_CONFIG_ROOT:-$HOME/.config/guanghechen}"
export GHC_CONFIG_ROOT

# shellcheck source=nix/setup/path.sh
source "$GHC_CONFIG_ROOT/nix/setup/path.sh"

## Setup windows terminal
printf "\e[96m  [setup windows-terminal] set windows terminal...\e[0m\n"
fish -c "node \"$GHC_CONFIG_ROOT/config/app/windows-terminal/index.mjs\""
