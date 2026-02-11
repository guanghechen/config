#! /usr/bin/env bash

newsboat_config_dir="$HOME/.config/newsboat"
if [ -d "$newsboat_config_dir" ]; then
  newsboat_platform_link="$newsboat_config_dir/local/platform"
  newsboat_platform_dir="$newsboat_config_dir/conf/platform"

  if [ "$(uname)" = "Darwin" ]; then
    platform="mac"
  elif [ -r /proc/version ] && grep -qEi "(Microsoft|WSL)" /proc/version; then
    platform="wsl"
  else
    platform="nix"
  fi

  mkdir -p "$newsboat_config_dir/local"

  if [ -e "$newsboat_platform_dir/$platform" ]; then
    printf "\e[96m  [setup newsboat] setting up platform symlink (%s)...\e[0m\n" "$platform"
    ln -sf "$newsboat_platform_dir/$platform" "$newsboat_platform_link"
  fi
fi
