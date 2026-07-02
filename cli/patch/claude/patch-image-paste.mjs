#!/usr/bin/env node

/**
 * Image Paste Patch (WSL clipboard image format / source)
 *
 * The Ctrl+V keybinding is NOT patched here — configure it via
 * `~/.config/claude/keybindings.json` (`ctrl+v: chat:imagePaste`, requires
 * Claude Code v2.1.18+). This patch only fixes the WSL clipboard *format /
 * source*:
 *
 *   Upstream reads the WSL (WSLg Wayland) clipboard via xclip/wl-paste, so an
 *   image copied on the Windows side is invisible, and WSLg exposes only a
 *   BI_BITFIELDS-compressed image/bmp that the bundled libvips cannot decode.
 *   Route checkImage/saveImage through an external helper that (1) reads the
 *   Windows clipboard first via powershell.exe and (2) converts BMP -> PNG.
 */

/**
 * @typedef {import('./types.mjs').IPatch} IPatch
 */

import { applyPatches, replaceAll } from './util.mjs'

const jsIdentifier = String.raw`[A-Za-z_$][A-Za-z0-9_$]*`
const wslImagePasteHelper = 'bash ~/.config/guanghechen/cli/patch/claude/wsl-image-paste.bash'

/**
 * @param {string} value
 * @param {number} length
 * @returns {string}
 */
function padToLength(value, length) {
  if (value.length > length) throw new Error(`Replacement is longer than original: ${value.length} > ${length}`)
  return value + ' '.repeat(length - value.length)
}

/** @type {IPatch[]} */
const patches = [
  // 2.1.198 - WSL patches
  // Upstream still tries the WSL clipboard before the Windows clipboard.
  // Use the helper so images copied on the Windows side are checked first.
  {
    name: 'wsl-image-paste-checkImage',
    version: '2.1.198',
    platform: ['wsl'],
    search:
      'xclip -selection clipboard -t TARGETS -o 2>/dev/null | grep -E "image/(png|jpeg|jpg|gif|webp|bmp)" || wl-paste -l 2>/dev/null | grep -E "image/(png|jpeg|jpg|gif|webp|bmp)"',
    replace: (content, matches) =>
      replaceAll(
        content,
        matches,
        (m) => padToLength(`${wslImagePasteHelper} check`, m.matched_text.length),
      ),
    verify: (text) => text.includes(`${wslImagePasteHelper} check`),
  },
  {
    name: 'wsl-image-paste-saveImage',
    version: '2.1.198',
    platform: ['wsl'],
    search: new RegExp(
      String.raw`xclip -selection clipboard -t image/png -o > \$\{(${jsIdentifier})\} 2>/dev/null \|\| wl-paste --type image/png > \$\{\1\} 2>/dev/null \|\| xclip -selection clipboard -t image/bmp -o > \$\{\1\} 2>/dev/null \|\| wl-paste --type image/bmp > \$\{\1\}`,
    ),
    replace: (content, matches) =>
      replaceAll(content, matches, (m) => {
        const [varName] = m.matched_groups
        return padToLength(`${wslImagePasteHelper} save \${${varName}}`, m.matched_text.length)
      }),
    verify: (text) => text.includes(`${wslImagePasteHelper} save`),
  },
]

applyPatches({ patches })
