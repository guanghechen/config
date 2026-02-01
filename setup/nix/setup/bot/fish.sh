#! /usr/bin/env bash
# shellcheck disable=SC1091

GHC_CONFIG_ROOT="${GHC_CONFIG_ROOT:-$HOME/.config/guanghechen}"
export GHC_CONFIG_ROOT

# shellcheck source=setup/nix/setup/path.sh
source "$GHC_CONFIG_ROOT/setup/nix/setup/path.sh"

fish_path="$HOME_HOMEBREW/bin/fish"
if [[ 
  -f "$fish_path" &&
  $(
    grep -Fxq "$fish_path" /etc/shells
    echo $?
  ) -eq 0 ]]; then
  printf "\e[93m  [setup homebrew] fish is already set up. (skipped)\e[0m\n"
else
  printf "\e[96m  [setup homebrew] setting up fish...\e[0m\n"
  brew install fish
  echo "$fish_path" | sudo tee -a /etc/shells
  chsh -s "$fish_path"
fi
