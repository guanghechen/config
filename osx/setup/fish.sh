#! /usr/bin/env bash

fish_path="$HOME_HOMEBREW/bin/fish"
if [[ 
  -f "$fish_path" &&
  $(
    grep -Fxq "$fish_path" /etc/shells
    echo $?
  ) -eq 0 ]]; then
  printf "\n\e[38;5;214m  [setup homebrew] fish is already setted up. (skipped)\e[0m\n"
else
  printf "\n\e[34m  [setup homebrew] setting up fish...\e[0m\n"
  brew install fish
  echo "$fish_path" | sudo tee -a /etc/shells
  chsh -s "$fish_path"
fi
