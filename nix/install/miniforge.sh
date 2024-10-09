#! /usr/bin/env bash

## Set environment variables
export PYTHONIOENCODING=utf8
export PYTHONUTF8=1

## Mkdirs
mkdir -p ~/.app/
mkdir -p ~/download/app/

## Download and install the miniforge3
cd ~/download/app/
curl -L -O "https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-$(uname)-$(uname -m).sh"
printf "\n\nyes\n$HOME/.app/miniforge3\nno\n" | bash Miniforge3-$(uname)-$(uname -m).sh # should install at ~/.app/miniforge3
