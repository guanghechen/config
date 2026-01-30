#! /usr/bin/env bash
# shellcheck disable=SC1091

# shellcheck source=nix/setup/path.sh
source "$HOME/.config/guanghechen/nix/setup/path.sh"

# printf "\n\e[94m  [setup config] gen themes...\e[0m\n"
# fish -c "node ~/.config/guanghechen/config/theme/gen_themes.mjs"

printf "\e[96m  [setup config] reload theme...\e[0m\n"
fish -c "node ~/.config/guanghechen/config/theme/apply_theme.mjs"
