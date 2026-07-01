#! /usr/bin/env bash

source "$HOME/.config/guanghechen/setup/nix/bot/env.bash"

### Install git
brew tap microsoft/git
brew install --cask git-credential-manager

### Install wget
brew install wget

### Install odbc
brew install unixodbc

### Install pngpaste
brew install pngpaste

### Install alacritty
brew install --cask alacritty

### Install ghostty
brew install --cask ghostty

### Install kitty
brew install --cask kitty

### Install tex
brew install tectonic

### Install wezterm
brew install --cask wezterm

### Install yabai
brew install koekeishiya/formulae/skhd
brew install koekeishiya/formulae/yabai
brew install FelixKratz/formulae/borders

### Install OSX System Utilities
brew install mole

### Install karabiner-elements
### macOS built-in modifier-key remapping only applies to the local device. We need
### Karabiner-Elements so keyboard key swaps keep working when this Mac controls
### another macOS device through Universal Control.
brew install --cask karabiner-elements
