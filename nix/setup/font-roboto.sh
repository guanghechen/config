#! /usr/bin/env bash

source $HOME/.config/guanghechen/nix/setup/path.sh

FONT_DIR="/usr/share/fonts/RobotoMono"

if [ -d $FONT_DIR ]; then
  printf "\n\e[34m  [setup font (RobotoMono)] RobotoMono is already installed.\e[0m\n"
else
  mkdir -p  ~/download/fonts/RobotoMono
  rm    -rf ~/download/fonts/RobotoMono
  mkdir -p  ~/download/fonts/RobotoMono
  cd ~/download/fonts/RobotoMono

  printf "\n\e[34m  [setup font (RobotoMono)] downloading RobotoMono fonts...\e[0m\n"
  wget https://github.com/guanghechen/mirror/releases/download/font/RobotoMono.zip

  printf "\n\e[34m  [setup font (RobotoMono)] installing RobotoMono fonts...\e[0m\n"
  unzip RobotoMono.zip
  rm -f RobotoMono.zip
  sudo cp -r ~/download/fonts/RobotoMono "$FONT_DIR/"
  sudo fc-cache -f -v
fi
