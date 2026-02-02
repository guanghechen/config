#! /usr/bin/env bash
# shellcheck disable=SC1091


# shellcheck source=setup/nix/path.sh
source "$HOME/.config/guanghechen/setup/nix/path.sh"

# printf "\n\e[94m  [setup config] gen themes...\e[0m\n"
# fish -c "node \"$HOME/.config/guanghechen/cli/theme-gen.mjs\""

printf "\e[96m  [setup config] reload theme...\e[0m\n"
fish -c "node \"$HOME/.config/guanghechen/cli/theme-apply.mjs\""
