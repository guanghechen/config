#! /usr/bin/env bash
# shellcheck disable=SC1091

GHC_CONFIG_ROOT="${GHC_CONFIG_ROOT:-$HOME/.config/guanghechen}"
export GHC_CONFIG_ROOT

# shellcheck source=setup/nix/setup/path.sh
source "$GHC_CONFIG_ROOT/setup/nix/setup/path.sh"

## Setup windows terminal
printf "\e[96m  [setup windows-terminal] set windows terminal...\e[0m\n"
fish -c "node \"$GHC_CONFIG_ROOT/cli/sync-config-windows-terminal.mjs\""
