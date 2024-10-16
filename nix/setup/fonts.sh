#! /usr/bin/env bash

ROBOTO_MONO_FONT_DIR="/usr/share/fonts/RobotoMono/"

if [ -d $ROBOTO_MONO_FONT_DIR ]; then
  echo -e "\e[32m  [setup fonts] RobotoMono already installed.\e[0m"
else
  echo -e "\e[34m  [setup fonts] preparing...\e[0m"

  mkdir -p ~/download/fonts/RobotoMono
  cd ~/download/fonts/RobotoMono

  echo -e "\n\e[34m  [setup fonts] downloading RobotoMono fonts...\e[0m"
  wget https://github.com/ryanoasis/nerd-fonts/releases/download/v3.2.1/RobotoMono.zip

  echo -e "\n\e[34m  [setup fonts] installing RobotoMono fonts...\e[0m"
  unzip RobotoMono.zip
  rm -f RobotoMono.zip
  sudo cp -r ~/download/fonts/RobotoMono "$ROBOTO_MONO_FONT_DIR"
  sudo fc-cache -f -v
  echo -e "\e[32m  [setup fonts] done.\e[0m"
fi
