#! /usr/bin/env bash

cargo_home="${CARGO_HOME:-$HOME/.cargo}"
installed_binary="$cargo_home/bin/kit-repo"
local_bin="$cargo_home/local/bin"
local_binary="$local_bin/kit-repo"

case "$cargo_home" in
  /*) ;;
  *)
    printf "\e[91mCARGO_HOME must be absolute: %s\e[0m\n" "$cargo_home" >&2
    exit 1
    ;;
esac

if [ -x "$local_binary" ]; then
  printf "\e[96musing local development binary: %s\e[0m\n" "$local_binary"
else
  if [ -L "$installed_binary" ]; then
    printf "\e[91mlegacy development link found at %s\e[0m\n" "$installed_binary" >&2
    printf "\e[91m   From kit-rust, run: BIN_DIR=%q cargo unlink\e[0m\n" "$cargo_home/bin" >&2
    exit 1
  fi

  printf "\e[96minstalling the latest published version...\e[0m\n"
  cargo install --locked --root "$cargo_home" guanghechen-kit-repo

  if [ ! -x "$installed_binary" ]; then
    printf "\e[91mcargo completed without installing %s\e[0m\n" "$installed_binary" >&2
    exit 1
  fi
fi

if ! mkdir -p "$local_bin"; then
  printf "\e[91mfailed to create development binary directory: %s\e[0m\n" "$local_bin" >&2
  exit 1
fi
