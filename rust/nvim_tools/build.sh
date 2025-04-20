#! /bin/env bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)" # Get the directory of the current script
cd "$SCRIPT_DIR"                                           # Change to that directory

[ "$CARGO_TARGET_DIR" = "" ] && CARGO_TARGET_DIR=target

if [ "$(uname)" == "Darwin" ]; then
  if [ ! -f "../../lua/nvim_tools.so" ]; then
    cargo build --release
    rm -f ../../lua/nvim_tools.so
    cp "${CARGO_TARGET_DIR}/release/libnvim_tools.dylib" ../../lua/nvim_tools.so

    mkdir -p ../../bin/
    cp "${CARGO_TARGET_DIR}/release/libnvim_tools.dylib" ../../bin/osx.nvim_tools.so
    rm -rf $CARGO_TARGET_DIR
  fi
elif [ "$(expr substr $(uname -s) 1 5)" == "Linux" ]; then
  if [ ! -f "../../lua/nvim_tools.so" ]; then
    cargo build --release
    rm -f ../../lua/nvim_tools.so
    cp "${CARGO_TARGET_DIR}/release/libnvim_tools.so" ../../lua/nvim_tools.so

    mkdir -p ../../bin/
    cp "${CARGO_TARGET_DIR}/release/libnvim_tools.so" ../../bin/nix.nvim_tools.so
    rm -rf $CARGO_TARGET_DIR
  fi
elif [ "$(expr substr $(uname -s) 1 10)" == "MINGW32_NT" ]; then
  if [ ! -f "../../lua/nvim_tools.dll" ]; then
    cargo build --release
    rm -f ../../lua/nvim_tools.dll
    cp "${CARGO_TARGET_DIR}/release/libnvim_tools.dll" ../../lua/nvim_tools.dll

    mkdir -p ../../bin/
    cp "${CARGO_TARGET_DIR}/release/libnvim_tools.dll" ../../bin/win.nvim_tools.dll
    rm -rf $CARGO_TARGET_DIR
  fi
fi

echo "Build Done"
