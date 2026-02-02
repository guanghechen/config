#! /usr/bin/env bash
# shellcheck disable=SC1091


# shellcheck source=setup/nix/setup/path.sh
source "$HOME/.config/guanghechen/setup/nix/setup/path.sh"

if command -v bun &>/dev/null; then
  printf "\e[96m  [setup bun] bun is already installed, upgrading...\e[0m\n"
  bun upgrade
else
  printf "\e[96m  [setup bun] installing bun...\e[0m\n"
  curl -fsSL https://bun.sh/install | bash
fi
