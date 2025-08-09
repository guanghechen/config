#! /usr/bin/env bash

source $HOME/.config/guanghechen/nix/setup/path.sh

FONT_COMMON_DIR="/Library/Fonts"
FONT_LOCAL_DIR="$HOME/Library/Fonts"

if [ -f "$FONT_COMMON_DIR/RobotoMonoNerdFont-Bold.ttf" ]; then
  printf "\n\e[94m  [setup font (RobotoMono)] RobotoMono is already installed.\e[0m\n"
else
  mkdir -p ~/download/fonts/RobotoMono
  rm -rf ~/download/fonts/RobotoMono
  mkdir -p ~/download/fonts/RobotoMono
  cd ~/download/fonts/RobotoMono

  rm -rf "$FONT_LOCAL_DIR/RobotoMonoNerdFont*"
  sudo rm -rf "$FONT_COMMON_DIR/RobotoMonoNerdFont*"

  printf "\n\e[94m  [setup font (RobotoMono)] downloading RobotoMono fonts...\e[0m\n"
  wget https://github.com/guanghechen/mirror/releases/download/font/RobotoMono.zip

  printf "\n\e[94m  [setup font (RobotoMono)] installing RobotoMono fonts...\e[0m\n"
  unzip RobotoMono.zip
  rm -f RobotoMono.zip
  sudo cp ~/download/fonts/RobotoMono/* "$FONT_COMMON_DIR/"
  sudo atsutil databases -remove
fi
