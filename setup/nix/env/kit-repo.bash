#! /usr/bin/env bash

cargo_home="${CARGO_HOME:-$HOME/.cargo}"
installed_binary="$cargo_home/bin/kit-repo"
local_bin="$cargo_home/local/bin"

case "$cargo_home" in
  /*) ;;
  *)
    printf "\e[91m  [setup kit-repo] CARGO_HOME must be absolute: %s\e[0m\n" "$cargo_home" >&2
    exit 1
    ;;
esac

if [ -L "$installed_binary" ]; then
  printf "\e[91m  [setup kit-repo] legacy development link found at %s.\e[0m\n" "$installed_binary" >&2
  printf "\e[91m   From kit-rust, run: BIN_DIR=%q cargo unlink\e[0m\n" "$cargo_home/bin" >&2
  exit 1
fi

printf "\e[96m  [setup kit-repo] installing the latest published version...\e[0m\n"
cargo install --locked --root "$cargo_home" guanghechen-kit-repo

if [ ! -x "$installed_binary" ]; then
  printf "\e[91m  [setup kit-repo] cargo completed without installing %s.\e[0m\n" "$installed_binary" >&2
  exit 1
fi

if ! mkdir -p "$local_bin"; then
  printf "\e[91m  [setup kit-repo] failed to create development binary directory: %s\e[0m\n" "$local_bin" >&2
  exit 1
fi
