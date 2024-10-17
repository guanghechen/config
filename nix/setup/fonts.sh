#! /usr/bin/env bash

ROBOTO_MONO_FONT_DIR="/usr/share/fonts/RobotoMono/"

if [ -d $ROBOTO_MONO_FONT_DIR ]; then
  printf "\n\e[34m  [setup fonts] RobotoMono is already installed.\e[0m\n"
else
  mkdir -p ~/download/fonts/RobotoMono
  cd ~/download/fonts/RobotoMono

  printf "\n\e[34m  [setup fonts] downloading RobotoMono fonts...\e[0m\n"
  wget https://github.com/ryanoasis/nerd-fonts/releases/download/v3.2.1/RobotoMono.zip

  printf "\n\e[34m  [setup fonts] installing RobotoMono fonts...\e[0m\n"
  unzip RobotoMono.zip
  rm -f RobotoMono.zip
  sudo cp -r ~/download/fonts/RobotoMono "$ROBOTO_MONO_FONT_DIR"
  sudo fc-cache -f -v
fi
