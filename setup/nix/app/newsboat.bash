#! /usr/bin/env bash

source "$HOME/.config/guanghechen/setup/nix/bot/env.bash"

newsboat_config_dir="$HOME/.config/newsboat"
if [ -d "$newsboat_config_dir" ]; then
  newsboat_platform_link="$newsboat_config_dir/local/platform"
  newsboat_platform_dir="$newsboat_config_dir/conf/platform"
  platform="$GHC_ENV_PLATFORM"

  mkdir -p "$newsboat_config_dir/local"

  if [ -e "$newsboat_platform_dir/$platform" ]; then
    printf "\e[96m  [setup newsboat] setting up platform symlink (%s)...\e[0m\n" "$platform"
    ln -sf "$newsboat_platform_dir/$platform" "$newsboat_platform_link"
  fi
fi
