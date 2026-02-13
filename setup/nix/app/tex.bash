#! /usr/bin/env bash

set -euo pipefail

GHC_TEX_PACKAGES=(
  texlive
  texlive-latex-extra
  texlive-fonts-recommended
  texlive-bibtex-extra
  texlive-science
  texlive-xetex
  texlive-lang-chinese
  texlive-lang-english
  latexmk
)

if command -v pdflatex &>/dev/null && command -v xelatex &>/dev/null; then
  printf "\e[93m  [setup tex] TeX Live is already installed. (skipped)\e[0m\n"
else
  printf "\e[96m  [setup tex] installing TeX Live packages...\e[0m\n"
  sudo apt update
  sudo apt install -y "${GHC_TEX_PACKAGES[@]}"
fi

printf "\e[96m  [setup tex] checking installed packages...\e[0m\n"
for pkg in "${GHC_TEX_PACKAGES[@]}"; do
  if dpkg -l "$pkg" &>/dev/null; then
    printf "\e[92m  [setup tex] %s is installed.\e[0m\n" "$pkg"
  else
    printf "\e[91m  [setup tex] %s is not installed.\e[0m\n" "$pkg"
  fi
done
