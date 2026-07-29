#! /usr/bin/env bash

## Fetch a clean, verified set of font files. The staging directory is
## disposable; callers own the live target and recover by rerunning setup.

## macOS ships `shasum`, Linux ships `sha256sum`.
ghc_font_sha256() {
  local output
  if command -v sha256sum >/dev/null 2>&1; then
    output="$(sha256sum "$1")" || return 1
  elif command -v shasum >/dev/null 2>&1; then
    output="$(shasum -a 256 "$1")" || return 1
  else
    printf "no SHA-256 command found (expected sha256sum or shasum)\n" >&2
    return 1
  fi

  printf '%s\n' "${output%% *}"
}

## Download an archive, verify its checksum, extract its *.ttf into <workdir>.
##
## Usage: ghc_font_fetch <label> <url> <sha256> <workdir>
ghc_font_fetch() {
  local label="$1" url="$2" expected="$3" workdir="$4"
  local archive="$workdir/${url##*/}"
  local actual count=0 path

  if ! rm -rf "${workdir:?}" || [ -e "$workdir" ]; then
    printf "\e[91m  [setup font (%s)] failed to clean staging directory: %s\e[0m\n" \
      "$label" "$workdir"
    return 1
  fi
  mkdir -p "$workdir" || return 1

  printf "\e[96m  [setup font (%s)] downloading %s...\e[0m\n" "$label" "${url##*/}"
  curl -fsSL --retry 3 -o "$archive" "$url" || return 1

  actual="$(ghc_font_sha256 "$archive")" || return 1
  if [ "$actual" != "$expected" ]; then
    printf "\e[91m  [setup font (%s)] checksum mismatch, refusing to install.\e[0m\n" "$label"
    printf "\e[91m    expected: %s\n    actual:   %s\e[0m\n" "$expected" "$actual"
    return 1
  fi

  unzip -q -o -j "$archive" '*.ttf' -d "$workdir" || return 1
  rm -f "$archive" || return 1
  for path in "$workdir"/*.ttf; do
    [ -f "$path" ] || continue
    count=$((count + 1))
  done
  if [ "$count" -eq 0 ]; then
    printf "\e[91m  [setup font (%s)] archive contains no ttf files.\e[0m\n" "$label"
    return 1
  fi
  printf "\e[96m  [setup font (%s)] verified, %s ttf files.\e[0m\n" "$label" "$count"
}
