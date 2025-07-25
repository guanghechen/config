#! /usr/bin/env bash

if [[ -n "$ROOT_SOURCECODES" ]]; then
  ROOT_TMUX="$ROOT_SOURCECODES/github/tmux/tmux/"
  mkdir -p "$ROOT_TMUX"

  if [ -d "$ROOT_TMUX/.git" ]; then
    git -C "$ROOT_TMUX" pull origin master
  else
    git clone https://github.com/tmux/tmux "$ROOT_TMUX"
  fi

  sudo apt install bison libevent-dev libncurses5-dev libncursesw5-dev
  cd "$ROOT_TMUX"
  sh autogen.sh
  ./configure
  make
fi
