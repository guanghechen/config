#! /usr/bin/env bash

source "$HOME/.config/guanghechen/setup/nix/bot/env.bash"

if command -v pnpm &>/dev/null; then
  printf "\e[96m  [setup pnpm] pnpm is already installed, upgrading...\e[0m\n"
  pnpm self-update
else
  printf "\e[96m  [setup pnpm] installing pnpm...\e[0m\n"
  curl -fsSL https://get.pnpm.io/install.sh | sh -
fi

if command -v pnpm &>/dev/null; then
  if [ -d "$HOME/.config/ora" ]; then
    printf "\e[96m  [setup pnpm] setup ora...\e[0m\n"
    (cd "$HOME/.config/ora" && pnpm install)
  fi

  if [ -d "$HOME/.config/yoz" ]; then
    printf "\e[96m  [setup pnpm] setup yoz...\e[0m\n"
    (cd "$HOME/.config/yoz" && pnpm install)
  fi
fi
