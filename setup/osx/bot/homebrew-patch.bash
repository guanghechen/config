#! /usr/bin/env bash

source "$HOME/.config/guanghechen/setup/nix/bot/env.bash"

### Install git
brew tap microsoft/git
brew install -y --cask git-credential-manager

### Install wget
brew install -y wget

### Install odbc
brew install -y unixodbc

### Install pngpaste
brew install -y pngpaste

### Install alacritty
brew install -y --cask alacritty

### Install ghostty
brew install -y --cask ghostty

### Install kitty
brew install -y --cask kitty

### Install tex
brew install -y tectonic

### Install wezterm
brew install -y --cask wezterm

### Install yabai
brew install -y koekeishiya/formulae/skhd
brew install -y koekeishiya/formulae/yabai
brew install -y FelixKratz/formulae/borders

### Install OSX System Utilities
brew install -y mole

### Install karabiner-elements
### macOS built-in modifier-key remapping only applies to the local device. We need
### Karabiner-Elements so keyboard key swaps keep working when this Mac controls
### another macOS device through Universal Control.
brew install -y --cask karabiner-elements
