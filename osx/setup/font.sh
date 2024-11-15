#! /usr/bin/env bash

source $HOME/.config/guanghechen/nix/setup/path.sh

ROBOTO_MONO_FONT_COMMON_DIR="/Library/Fonts"
ROBOTO_MONO_FONT_LOCAL_DIR="$HOME/Library/Fonts"

if [ -f "$ROBOTO_MONO_FONT_COMMON_DIR/RobotoMonoNerdFont-Bold.ttf" ]; then
  printf "\n\e[34m  [setup font] RobotoMono is already installed.\e[0m\n"
else
  mkdir -p ~/download/fonts/RobotoMono
  cd ~/download/fonts/RobotoMono

  rm -rf "$ROBOTO_MONO_FONT_LOCAL_DIR/RobotoMonoNerdFont*"
  sudo rm -rf "$ROBOTO_MONO_FONT_COMMON_DIR/RobotoMonoNerdFont*"

  printf "\n\e[34m  [setup font] downloading RobotoMono fonts...\e[0m\n"
  wget https://github.com/guanghechen/mirror/releases/download/font/RobotoMono.zip

  printf "\n\e[34m  [setup font] installing RobotoMono fonts...\e[0m\n"
  unzip RobotoMono.zip
  rm -f RobotoMono.zip
  sudo cp ~/download/fonts/RobotoMono/* "$ROBOTO_MONO_FONT_COMMON_DIR/"
  sudo atsutil databases -remove
fi
