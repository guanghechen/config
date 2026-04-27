#!/usr/bin/env bash

set -o pipefail

check_image() {
  powershell.exe -NoProfile -Command 'if ((Get-Clipboard -Format Image) -eq $null) { exit 1 }' 2>/dev/null \
    || xclip -selection clipboard -t TARGETS -o 2>/dev/null | grep -E 'image/(png|jpeg|jpg|gif|webp|bmp)' \
    || wl-paste -l 2>/dev/null | grep -E 'image/(png|jpeg|jpg|gif|webp|bmp)'
}

save_image() {
  local target=$1

  if [ -z "$target" ]; then
    return 2
  fi

  powershell.exe -NoProfile -Command '\
$img = Get-Clipboard -Format Image;
if ($img) {
  $ms = New-Object System.IO.MemoryStream;
  $img.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png);
  $bytes = $ms.ToArray();
  [Console]::OpenStandardOutput().Write($bytes, 0, $bytes.Length)
} else {
  exit 1
}' > "$target" 2>/dev/null \
    || xclip -selection clipboard -t image/png -o > "$target" 2>/dev/null \
    || wl-paste --type image/png > "$target" 2>/dev/null \
    || xclip -selection clipboard -t image/bmp -o > "$target" 2>/dev/null \
    || wl-paste --type image/bmp > "$target"
}

case "${1:-}" in
  check)
    check_image
    ;;
  save)
    save_image "$2"
    ;;
  *)
    exit 2
    ;;
esac
