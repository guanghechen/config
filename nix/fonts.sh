#! /usr/bin/env bash

mkdir -p ~/download/fonts/RobotoMono
cd ~/download/fonts/RobotoMono
wget https://github.com/ryanoasis/nerd-fonts/releases/download/v3.2.1/RobotoMono.zip
unzip RobotoMono.zip
sudo cp -r ~/download/fonts/RobotoMono /usr/share/fonts/
sudo fc-cache -f -v
