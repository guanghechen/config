#! /usr/bin/env bash
# shellcheck disable=SC1091

# shellcheck source=nix/setup/path.sh
source "$HOME/.config/guanghechen/nix/setup/path.sh"

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
