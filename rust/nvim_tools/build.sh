#! /bin/env bash

set -e

# Parse command line arguments
FORCE=false
while [[ $# -gt 0 ]]; do
  case $1 in
  --force | -f)
    FORCE=true
    shift
    ;;
  *)
    echo "Unknown option: $1"
    echo "Usage: $0 [--force|-f]"
    exit 1
    ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)" # Get the directory of the current script
cd "$SCRIPT_DIR"                                           # Change to that directory

[ "$CARGO_TARGET_DIR" = "" ] && CARGO_TARGET_DIR=target

if [ "$(uname)" == "Darwin" ]; then
  if [ "$FORCE" == "true" ] || [ ! -f "../../lua/nvim_tools.so" ]; then
    mkdir -p ../../bin/

    cargo build --release
    rm -f ../../lua/nvim_tools.so
    rm -f ../../bin/osx.nvim_tools.so

    cp "${CARGO_TARGET_DIR}/release/libnvim_tools.dylib" ../../lua/nvim_tools.so
    cp "${CARGO_TARGET_DIR}/release/libnvim_tools.dylib" ../../bin/osx.nvim_tools.so
    rm -rf $CARGO_TARGET_DIR
  fi
elif [ "$(expr substr $(uname -s) 1 5)" == "Linux" ]; then
  if [ "$FORCE" == "true" ] || [ ! -f "../../lua/nvim_tools.so" ]; then
    mkdir -p ../../bin/

    cargo build --release
    rm -f ../../lua/nvim_tools.so
    rm -f ../../bin/nix.nvim_tools.so

    cp "${CARGO_TARGET_DIR}/release/libnvim_tools.so" ../../lua/nvim_tools.so
    cp "${CARGO_TARGET_DIR}/release/libnvim_tools.so" ../../bin/nix.nvim_tools.so
    rm -rf $CARGO_TARGET_DIR
  fi
elif [ "$(expr substr $(uname -s) 1 10)" == "MINGW32_NT" ]; then
  if [ "$FORCE" == "true" ] || [ ! -f "../../lua/nvim_tools.dll" ]; then
    mkdir -p ../../bin/

    cargo build --release
    rm -f ../../lua/nvim_tools.dll
    rm -f ../../bin/win.nvim_tools.dll

    cp "${CARGO_TARGET_DIR}/release/libnvim_tools.dll" ../../lua/nvim_tools.dll
    cp "${CARGO_TARGET_DIR}/release/libnvim_tools.dll" ../../bin/win.nvim_tools.dll
    rm -rf $CARGO_TARGET_DIR
  fi
fi

echo "Build Done"
