#! /usr/bin/env bash

source "$HOME/.config/guanghechen/setup/nix/bot/env.bash"

fish_path="$HOME_HOMEBREW/bin/fish"
if [ -x "$fish_path" ]; then
  printf "\e[93m  [setup homebrew] fish is already installed. (skipped)\e[0m\n"
else
  printf "\e[96m  [setup homebrew] installing fish...\e[0m\n"
  brew install -y fish
fi

if [ -n "${CI:-}" ] || [ "${GHC_NONINTERACTIVE:-}" = "1" ] || [ ! -t 0 ]; then
  printf "\e[93m  [setup homebrew] non-interactive shell detected. (skipped login shell setup)\e[0m\n"
else
  if grep -Fxq "$fish_path" /etc/shells; then
    printf "\e[93m  [setup homebrew] fish is already registered in /etc/shells. (skipped)\e[0m\n"
  else
    printf "\e[96m  [setup homebrew] registering fish in /etc/shells...\e[0m\n"
    echo "$fish_path" | sudo tee -a /etc/shells
  fi

  current_user="$(id -un)"
  case "$GHC_ENV_PLATFORM" in
    osx)
      current_shell="$(dscl . -read "/Users/$current_user" UserShell | awk '{print $2}')"
      ;;
    nix | wsl)
      current_shell="$(getent passwd "$current_user" | cut -d: -f7)"
      ;;
    *)
      printf "\e[91m [setup homebrew] unsupported platform: %s\e[0m\n" "$GHC_ENV_PLATFORM" >&2
      exit 1
      ;;
  esac

  if [ -z "$current_shell" ]; then
    printf "\e[91m [setup homebrew] failed to determine the login shell for %s.\e[0m\n" \
      "$current_user" >&2
    exit 1
  fi

  if [ "$current_shell" = "$fish_path" ]; then
    printf "\e[93m  [setup homebrew] fish is already the login shell. (skipped)\e[0m\n"
  else
    printf "\e[96m  [setup homebrew] setting fish as the login shell...\e[0m\n"
    chsh -s "$fish_path"
  fi
fi
