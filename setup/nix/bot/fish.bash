#! /usr/bin/env bash

source "$HOME/.config/guanghechen/setup/nix/bot/env.bash"

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
  brew install -y fish
  if [ -n "${CI:-}" ] || [ "${GHC_NONINTERACTIVE:-}" = "1" ] || [ ! -t 0 ]; then
    printf "\e[93m  [setup homebrew] non-interactive shell detected. (skipped chsh)\e[0m\n"
  else
    echo "$fish_path" | sudo tee -a /etc/shells
    chsh -s "$fish_path"
  fi
fi
