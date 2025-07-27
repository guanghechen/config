#! /usr/bin/env bash

source $HOME/.config/guanghechen/nix/setup/path.sh

### Install git
brew tap microsoft/git
brew install --cask git-credential-manager

### Install odbc
brew install unixodbc

### Install pngpaste
brew install pngpaste

### Install kitty
brew install --cask kitty

### Install wezterm
brew install --cask wezterm

### Install yabai
brew install koekeishiya/formulae/skhd
brew install koekeishiya/formulae/yabai
brew install FelixKratz/formulae/borders
