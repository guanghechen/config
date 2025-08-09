#! /usr/bin/env bash

source $HOME/.config/guanghechen/nix/setup/path.sh

FONT_DIR="/usr/share/fonts/Maple"

if [ -d $FONT_DIR ]; then
  printf "\n\e[94m  [setup font (Maple)] Maple is already installed.\e[0m\n"
else
  mkdir -p ~/download/fonts/Maple
  rm -rf ~/download/fonts/Maple
  mkdir -p ~/download/fonts/Maple

  cd ~/download/fonts/Maple

  printf "\n\e[94m  [setup font (Maple)] downloading MapleMono-NF-CN fonts...\e[0m\n"
  wget https://github.com/guanghechen/mirror/releases/download/font/MapleMono-NF-CN-unhinted.zip

  printf "\n\e[94m  [setup font (Maple)] installing MapleMono fonts...\e[0m\n"
  unzip MapleMono-NF-CN-unhinted.zip
  rm -f MapleMono-NF-CN-unhinted.zip
  sudo cp -r ~/download/fonts/Maple "$FONT_DIR/"
  sudo fc-cache -f -v
fi
