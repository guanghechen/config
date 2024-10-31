#! /usr/bin/env bash

ROBOTO_MONO_FONT_DIR="/usr/share/fonts/RobotoMono/"

if [ -d $ROBOTO_MONO_FONT_DIR ]; then
  printf "\n\e[34m  [setup font] RobotoMono is already installed.\e[0m\n"
else
  mkdir -p ~/download/fonts/RobotoMono
  cd ~/download/fonts/RobotoMono

  printf "\n\e[34m  [setup font] downloading RobotoMono fonts...\e[0m\n"
  wget https://github.com/guanghechen/mirror/releases/download/font/RobotoMono.zip

  printf "\n\e[34m  [setup font] installing RobotoMono fonts...\e[0m\n"
  unzip RobotoMono.zip
  rm -f RobotoMono.zip
  sudo cp -r ~/download/fonts/RobotoMono "$ROBOTO_MONO_FONT_DIR"
  sudo fc-cache -f -v
fi
