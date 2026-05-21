#!/usr/bin/env bash

set -o pipefail

powershell_cmd() {
  command -v powershell.exe 2>/dev/null || printf '%s\n' /mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe
}

check_image() {
  local powershell
  powershell=$(powershell_cmd)

  "$powershell" -NoProfile -NonInteractive -Command 'if ((Get-Clipboard -Format Image) -eq $null) { exit 1 }' 2>/dev/null \
    || xclip -selection clipboard -t TARGETS -o 2>/dev/null | grep -E 'image/(png|jpeg|jpg|gif|webp|bmp)' \
    || wl-paste -l 2>/dev/null | grep -E 'image/(png|jpeg|jpg|gif|webp|bmp)'
}

save_image() {
  local target=$1
  local powershell

  if [ -z "$target" ]; then
    return 2
  fi

  powershell=$(powershell_cmd)

  "$powershell" -NoProfile -NonInteractive -Command '\
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
