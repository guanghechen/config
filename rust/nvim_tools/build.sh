#! /bin/env bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)" # Get the directory of the current script
cd "$SCRIPT_DIR"                                           # Change to that directory

cargo build --release

[ "$CARGO_TARGET_DIR" = "" ] && CARGO_TARGET_DIR=target

if [ "$(uname)" == "Darwin" ]; then
	cp "${CARGO_TARGET_DIR}/release/libnvim_tools.dylib" ../../lua/nvim_tools.so
elif [ "$(expr substr $(uname -s) 1 5)" == "Linux" ]; then
	cp "${CARGO_TARGET_DIR}/release/libnvim_tools.so" ../../lua/nvim_tools.so
elif [ "$(expr substr $(uname -s) 1 10)" == "MINGW32_NT" ]; then
	cp "${CARGO_TARGET_DIR}/release/libnvim_tools.dll" ../../lua/nvim_tools.dll
fi

rm -rf $CARGO_TARGET_DIR

echo "Build Done"
