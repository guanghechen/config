#! /usr/bin/env bash
# shellcheck disable=SC1091

GHC_CONFIG_ROOT="${GHC_CONFIG_ROOT:-$HOME/.config/guanghechen}"
export GHC_CONFIG_ROOT

# shellcheck source=nix/setup/path.sh
source "$GHC_CONFIG_ROOT/nix/setup/path.sh"

if fnm list | grep -q "v$PREFER_NODE_VERSION"; then
  printf "\e[93m  [setup node] node@%s is already installed. (skipped)\e[0m\n" "$PREFER_NODE_VERSION"
else
  printf "\e[96m  [setup node] installing node@%s...\e[0m\n" "$PREFER_NODE_VERSION"
  fnm install "$PREFER_NODE_VERSION"
fi

fnm use "$PREFER_NODE_VERSION"
fnm default "$PREFER_NODE_VERSION"

printf "\e[96m  [setup node] installing npm pm2 yarn prettier\e[0m\n"
npm install -g npm pm2 yarn prettier
