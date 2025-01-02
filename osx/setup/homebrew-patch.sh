#! /usr/bin/env bash

source $HOME/.config/guanghechen/nix/setup/path.sh

### Install git
brew tap microsoft/git
brew install --cask git-credential-manager

### Install kitty
brew install --cask kitty

### Install wezterm
brew install --cask wezterm
