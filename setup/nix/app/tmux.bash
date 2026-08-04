#! /usr/bin/env bash

source "$HOME/.config/guanghechen/setup/nix/bot/env.bash"

prefer_tmux_version="${GHC_APP_EDITION_TMUX:-latest}"
case "$prefer_tmux_version" in
  latest | nightly | manual) ;;
  *)
    printf "\e[91m  [setup tmux] invalid edition: %s\e[0m\n" "$prefer_tmux_version" >&2
    return 1
    ;;
esac

if [ "$prefer_tmux_version" = "manual" ] && [ -n "$ROOT_SOURCECODES" ]; then
  root_tmux="$ROOT_SOURCECODES/github/tmux/tmux"
  mkdir -p "$root_tmux"

  if [ -e "$root_tmux/.git" ]; then
    git -C "$root_tmux" pull origin master
  else
    git clone https://github.com/tmux/tmux "$root_tmux"
  fi

  if [ "$(uname -s)" = "Linux" ]; then
    sudo apt install -y bison libevent-dev libncurses5-dev libncursesw5-dev
    cd "$root_tmux" || return 1
    sh autogen.sh
    ./configure
    make
  else
    printf "\e[93m  [setup tmux] manual build is only for Linux/WSL. (skipped)\e[0m\n"
  fi
elif [ "$prefer_tmux_version" = "nightly" ] && command -v brew &>/dev/null; then
  printf "\e[96m  [setup tmux] installing nightly tmux...\e[0m\n"
  brew install -y --HEAD tmux
elif [ "$prefer_tmux_version" = "latest" ] && command -v brew &>/dev/null; then
  printf "\e[96m  [setup tmux] installing latest tmux...\e[0m\n"
  brew install -y tmux
fi

TPM_DIR="$HOME/.config/tmux/plugins/tpm"
if [ -d "$TPM_DIR" ]; then
  printf "\e[96m  [setup tmux] updating tmux plugin manager...\e[0m\n"
  git -C "$TPM_DIR" pull
else
  printf "\e[96m  [setup tmux] installing tmux plugin manager...\e[0m\n"
  mkdir -p "$HOME/.config/tmux/plugins/"
  git clone https://github.com/tmux-plugins/tpm "$TPM_DIR"
fi

# Install plugins need start a tmux server first.
# printf "\n\e[94m  [setup tmux] installing tmux plugins...\e[0m\n"
# tmux run-shell ~/.config/tmux/plugins/tpm/bin/install_plugins
