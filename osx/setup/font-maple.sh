#! /usr/bin/env bash

source $HOME/.config/guanghechen/nix/setup/path.sh

FONT_COMMON_DIR="/Library/Fonts"
FONT_LOCAL_DIR="$HOME/Library/Fonts"

if [ -f "$FONT_COMMON_DIR/MapleMono-NF-CN-Bold.ttf" ]; then
  printf "\n\e[94m  [setup font (Maple)] Maple is already installed.\e[0m\n"
else
  # Create the font download folder and ensure it to be clean.
  mkdir -p ~/download/fonts/Maple
  rm -rf ~/download/fonts/Maple
  mkdir -p ~/download/fonts/Maple

  # Remove the existed Maple fonts
  rm -rf "$FONT_LOCAL_DIR/Maple*"
  sudo rm -rf "$FONT_COMMON_DIR/Maple*"

  cd ~/download/fonts/Maple

  printf "\n\e[94m  [setup font (Maple)] downloading MapleMono-NF-CN fonts...\e[0m\n"
  wget https://github.com/guanghechen/mirror/releases/download/font/MapleMono-NF-CN-unhinted.zip

  printf "\n\e[94m  [setup font (Maple)] installing MapleMono fonts...\e[0m\n"
  unzip MapleMono-NF-CN-unhinted.zip
  rm -f MapleMono-NF-CN-unhinted.zip
  sudo cp ~/download/fonts/Maple/* "$FONT_COMMON_DIR/"
  sudo atsutil databases -remove
fi
