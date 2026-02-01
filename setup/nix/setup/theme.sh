#! /usr/bin/env bash
# shellcheck disable=SC1091

GHC_CONFIG_ROOT="${GHC_CONFIG_ROOT:-$HOME/.config/guanghechen}"
export GHC_CONFIG_ROOT

# shellcheck source=nix/setup/path.sh
source "$GHC_CONFIG_ROOT/nix/setup/path.sh"

# printf "\n\e[94m  [setup config] gen themes...\e[0m\n"
# fish -c "node \"$GHC_CONFIG_ROOT/cli/theme-gen.mjs\""

printf "\e[96m  [setup config] reload theme...\e[0m\n"
fish -c "node \"$GHC_CONFIG_ROOT/cli/theme-apply.mjs\""
