#! /usr/bin/env bash

ROBOTO_MONO_FONT_DIR="/usr/share/fonts/RobotoMono/"

if [ -d $ROBOTO_MONO_FONT_DIR ]; then
  echo -e "\n\e[34m  [setup fonts] RobotoMono is already installed.\e[0m"
else
  mkdir -p ~/download/fonts/RobotoMono
  cd ~/download/fonts/RobotoMono

  echo -e "\n\e[34m  [setup fonts] downloading RobotoMono fonts...\e[0m"
  wget https://github.com/ryanoasis/nerd-fonts/releases/download/v3.2.1/RobotoMono.zip

  echo -e "\n\e[34m  [setup fonts] installing RobotoMono fonts...\e[0m"
  unzip RobotoMono.zip
  rm -f RobotoMono.zip
  sudo cp -r ~/download/fonts/RobotoMono "$ROBOTO_MONO_FONT_DIR"
  sudo fc-cache -f -v
fi
