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
  if [ "$FORCE" == "true" ] || [ ! -f "../../lua/rstd.so" ]; then
    mkdir -p ../../bin/

    cargo build --release
    rm -f ../../lua/rstd.so
    rm -f ../../bin/osx.rstd.so

    cp "${CARGO_TARGET_DIR}/release/librstd.dylib" ../../lua/rstd.so
    cp "${CARGO_TARGET_DIR}/release/librstd.dylib" ../../bin/osx.rstd.so
    rm -rf $CARGO_TARGET_DIR
  fi
elif [ "$(expr substr $(uname -s) 1 5)" == "Linux" ]; then
  if [ "$FORCE" == "true" ] || [ ! -f "../../lua/rstd.so" ]; then
    mkdir -p ../../bin/

    cargo build --release
    rm -f ../../lua/rstd.so
    rm -f ../../bin/nix.rstd.so

    cp "${CARGO_TARGET_DIR}/release/librstd.so" ../../lua/rstd.so
    cp "${CARGO_TARGET_DIR}/release/librstd.so" ../../bin/nix.rstd.so
    rm -rf $CARGO_TARGET_DIR
  fi
elif [ "$(expr substr $(uname -s) 1 10)" == "MINGW32_NT" ]; then
  if [ "$FORCE" == "true" ] || [ ! -f "../../lua/rstd.dll" ]; then
    mkdir -p ../../bin/

    cargo build --release
    rm -f ../../lua/rstd.dll
    rm -f ../../bin/win.rstd.dll

    cp "${CARGO_TARGET_DIR}/release/librstd.dll" ../../lua/rstd.dll
    cp "${CARGO_TARGET_DIR}/release/librstd.dll" ../../bin/win.rstd.dll
    rm -rf $CARGO_TARGET_DIR
  fi
fi

echo "Build Done"
