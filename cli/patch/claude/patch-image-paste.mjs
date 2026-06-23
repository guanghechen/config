#!/usr/bin/env node

/**
 * Image Paste Patch (WSL / Linux clipboard format)
 *
 * Handles clipboard *image format* issues for image paste. The Windows
 * keybinding fix (Alt+V -> Ctrl+V) is no longer patched here; it is now
 * configured via `~/.config/claude/keybindings.json` (`ctrl+v: chat:imagePaste`,
 * requires Claude Code v2.1.18+).
 *
 * Remaining patches, by platform:
 *
 * 1. WSL: check/read the Windows clipboard before the WSL clipboard, and
 *    convert BMP -> PNG. WSLg drops CF_PNG and only exposes BI_BITFIELDS-
 *    compressed image/bmp, which the bundled libvips cannot decode, so route
 *    through the external helper (ImageMagick).
 *
 * 2. WSL/Linux (older builds): add image/bmp to the clipboard format grep, and
 *    add a wl-paste BMP -> PNG fallback via ImageMagick.
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
  // 2.1.186 - WSL patches
  // Upstream still tries the WSL clipboard before the Windows clipboard.
  // Use the helper so images copied on the Windows side are checked first.
  {
    name: 'wsl-image-paste-checkImage',
    version: '2.1.186',
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
    version: '2.1.186',
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
  // 2.1.178 - WSL patches
  // Upstream still tries the WSL clipboard before the Windows clipboard.
  // Use the helper so images copied on the Windows side are checked first.
  {
    name: 'wsl-image-paste-checkImage',
    version: '2.1.178',
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
    version: '2.1.178',
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
  // 2.1.163 - WSL patches
  // Upstream still tries the WSL clipboard before the Windows clipboard.
  // Use the helper so images copied on the Windows side are checked first.
  {
    name: 'wsl-image-paste-checkImage',
    version: '2.1.163',
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
    version: '2.1.163',
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
  // 2.1.146 - WSL patches
  // Upstream now has a Windows clipboard fallback, but it runs after xclip/wl-paste.
  // Use the helper to preserve the patched behavior: Windows clipboard first.
  {
    name: 'wsl-image-paste-checkImage',
    version: '2.1.146',
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
    version: '2.1.146',
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
  // 2.1.119 - WSL patches
  // Keep the Windows clipboard fallback through powershell.exe first.
  {
    name: 'wsl-image-paste-checkImage',
    version: '2.1.119',
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
    version: '2.1.119',
    platform: ['wsl'],
    search: new RegExp(
      String.raw`xclip -selection clipboard -t image/png -o > "\$\{(${jsIdentifier})\}" 2>/dev/null \|\| wl-paste --type image/png > "\$\{\1\}" 2>/dev/null \|\| xclip -selection clipboard -t image/bmp -o > "\$\{\1\}" 2>/dev/null \|\| wl-paste --type image/bmp > "\$\{\1\}"`,
    ),
    replace: (content, matches) =>
      replaceAll(content, matches, (m) => {
        const [varName] = m.matched_groups
        return padToLength(`${wslImagePasteHelper} save "\${${varName}}"`, m.matched_text.length)
      }),
    verify: (text) => text.includes(`${wslImagePasteHelper} save`),
  },
  // 2.1.92 - WSL patches
  // Keep the Windows clipboard fallback through powershell.exe first.
  {
    name: 'wsl-image-paste-checkImage',
    version: '2.1.92',
    platform: ['wsl'],
    search:
      'xclip -selection clipboard -t TARGETS -o 2>/dev/null | grep -E "image/(png|jpeg|jpg|gif|webp|bmp)" || wl-paste -l 2>/dev/null | grep -E "image/(png|jpeg|jpg|gif|webp|bmp)"',
    replace: (content, matches) =>
      replaceAll(
        content,
        matches,
        () =>
          'powershell.exe -NoProfile -Command "if ((Get-Clipboard -Format Image) -eq \\$null) { exit 1 }" 2>/dev/null || xclip -selection clipboard -t TARGETS -o 2>/dev/null | grep -E "image/(png|jpeg|jpg|gif|webp|bmp)" || wl-paste -l 2>/dev/null | grep -E "image/(png|jpeg|jpg|gif|webp|bmp)"',
      ),
    verify: (text) =>
      text.includes(
        'powershell.exe -NoProfile -Command "if ((Get-Clipboard -Format Image) -eq \\$null) { exit 1 }" 2>/dev/null || xclip -selection clipboard -t TARGETS',
      ),
  },
  {
    name: 'wsl-image-paste-saveImage',
    version: '2.1.92',
    platform: ['wsl'],
    search:
      /xclip -selection clipboard -t image\/png -o > "\$\{(\w+)\}" 2>\/dev\/null \|\| wl-paste --type image\/png > "\$\{\1\}" 2>\/dev\/null \|\| xclip -selection clipboard -t image\/bmp -o > "\$\{\1\}" 2>\/dev\/null \|\| wl-paste --type image\/bmp > "\$\{\1\}"/,
    replace: (content, matches) =>
      replaceAll(content, matches, (m) => {
        const [varName] = m.matched_groups
        const psCmd = [
          "\\$img = Get-Clipboard -Format Image;",
          "if (\\$img) {",
          "  \\$ms = New-Object System.IO.MemoryStream;",
          "  \\$img.Save(\\$ms, [System.Drawing.Imaging.ImageFormat]::Png);",
          "  \\$bytes = \\$ms.ToArray();",
          "  [Console]::OpenStandardOutput().Write(\\$bytes, 0, \\$bytes.Length)",
          "}",
        ].join(' ')
        return (
          `powershell.exe -NoProfile -Command '${psCmd}' > "\${${varName}}" 2>/dev/null || ` +
          `xclip -selection clipboard -t image/png -o > "\${${varName}}" 2>/dev/null || ` +
          `wl-paste --type image/png > "\${${varName}}" 2>/dev/null || ` +
          `xclip -selection clipboard -t image/bmp -o > "\${${varName}}" 2>/dev/null || ` +
          `wl-paste --type image/bmp > "\${${varName}}"`
        )
      }),
    verify: (text) =>
      text.includes("powershell.exe -NoProfile -Command '\\$img = Get-Clipboard -Format Image;"),
  },
  // 2.1.70 - WSL patches
  // In WSL, process.platform === "linux" so Claude uses xclip/wl-paste to access the
  // WSLg Wayland clipboard. But images copied on the Windows side are not available there.
  // These patches prepend a powershell.exe fallback so Windows clipboard is tried first.
  {
    // Prepend powershell.exe image detection before xclip/wl-paste in checkImage
    name: 'wsl-image-paste-checkImage',
    version: '2.1.70',
    platform: ['wsl'],
    search:
      'xclip -selection clipboard -t TARGETS -o 2>/dev/null | grep -E "image/(png|jpeg|jpg|gif|webp|bmp)" || wl-paste -l 2>/dev/null | grep -E "image/(png|jpeg|jpg|gif|webp|bmp)"',
    replace: (content, matches) =>
      replaceAll(
        content,
        matches,
        () =>
          'powershell.exe -NoProfile -Command "if ((Get-Clipboard -Format Image) -eq \\$null) { exit 1 }" 2>/dev/null || xclip -selection clipboard -t TARGETS -o 2>/dev/null | grep -E "image/(png|jpeg|jpg|gif|webp|bmp)" || wl-paste -l 2>/dev/null | grep -E "image/(png|jpeg|jpg|gif|webp|bmp)"',
      ),
    verify: (text) =>
      text.includes(
        'powershell.exe -NoProfile -Command "if ((Get-Clipboard -Format Image) -eq \\$null) { exit 1 }" 2>/dev/null || xclip -selection clipboard -t TARGETS',
      ),
  },
  {
    // Prepend powershell.exe image save (PNG via stdout) before xclip/wl-paste in saveImage
    name: 'wsl-image-paste-saveImage',
    version: '2.1.70',
    platform: ['wsl'],
    search:
      /xclip -selection clipboard -t image\/png -o > "\$\{(\w+)\}" 2>\/dev\/null \|\| wl-paste --type image\/png > "\$\{\1\}" 2>\/dev\/null \|\| xclip -selection clipboard -t image\/bmp -o > "\$\{\1\}" 2>\/dev\/null \|\| wl-paste --type image\/bmp > "\$\{\1\}"/,
    replace: (content, matches) =>
      replaceAll(content, matches, (m) => {
        const [varName] = m.matched_groups
        // PowerShell reads clipboard image, converts to PNG bytes, writes to stdout
        const psCmd = [
          "\\$img = Get-Clipboard -Format Image;",
          "if (\\$img) {",
          "  \\$ms = New-Object System.IO.MemoryStream;",
          "  \\$img.Save(\\$ms, [System.Drawing.Imaging.ImageFormat]::Png);",
          "  \\$bytes = \\$ms.ToArray();",
          "  [Console]::OpenStandardOutput().Write(\\$bytes, 0, \\$bytes.Length)",
          "}",
        ].join(' ')
        return (
          `powershell.exe -NoProfile -Command '${psCmd}' > "\${${varName}}" 2>/dev/null || ` +
          `xclip -selection clipboard -t image/png -o > "\${${varName}}" 2>/dev/null || ` +
          `wl-paste --type image/png > "\${${varName}}" 2>/dev/null || ` +
          `xclip -selection clipboard -t image/bmp -o > "\${${varName}}" 2>/dev/null || ` +
          `wl-paste --type image/bmp > "\${${varName}}"`
        )
      }),
    verify: (text) =>
      text.includes("powershell.exe -NoProfile -Command '\\$img = Get-Clipboard -Format Image;"),
  },
  // 2.1.50 - WSL patches
  // In WSL, process.platform === "linux" so Claude uses xclip/wl-paste to access the
  // WSLg Wayland clipboard. But images copied on the Windows side are not available there.
  // These patches prepend a powershell.exe fallback so Windows clipboard is tried first.
  {
    // Prepend powershell.exe image detection before xclip/wl-paste in checkImage
    name: 'wsl-image-paste-checkImage',
    version: '2.1.50',
    platform: ['wsl'],
    search:
      'xclip -selection clipboard -t TARGETS -o 2>/dev/null | grep -E "image/(png|jpeg|jpg|gif|webp|bmp)" || wl-paste -l 2>/dev/null | grep -E "image/(png|jpeg|jpg|gif|webp|bmp)"',
    replace: (content, matches) =>
      replaceAll(
        content,
        matches,
        () =>
          'powershell.exe -NoProfile -Command "if ((Get-Clipboard -Format Image) -eq \\$null) { exit 1 }" 2>/dev/null || xclip -selection clipboard -t TARGETS -o 2>/dev/null | grep -E "image/(png|jpeg|jpg|gif|webp|bmp)" || wl-paste -l 2>/dev/null | grep -E "image/(png|jpeg|jpg|gif|webp|bmp)"',
      ),
    verify: (text) =>
      text.includes(
        'powershell.exe -NoProfile -Command "if ((Get-Clipboard -Format Image) -eq \\$null) { exit 1 }" 2>/dev/null || xclip -selection clipboard -t TARGETS',
      ),
  },
  {
    // Prepend powershell.exe image save (PNG via stdout) before xclip/wl-paste in saveImage
    name: 'wsl-image-paste-saveImage',
    version: '2.1.50',
    platform: ['wsl'],
    search:
      /xclip -selection clipboard -t image\/png -o > "\$\{(\w+)\}" 2>\/dev\/null \|\| wl-paste --type image\/png > "\$\{\1\}" 2>\/dev\/null \|\| xclip -selection clipboard -t image\/bmp -o > "\$\{\1\}" 2>\/dev\/null \|\| wl-paste --type image\/bmp > "\$\{\1\}"/,
    replace: (content, matches) =>
      replaceAll(content, matches, (m) => {
        const [varName] = m.matched_groups
        // PowerShell reads clipboard image, converts to PNG bytes, writes to stdout
        const psCmd = [
          "\\$img = Get-Clipboard -Format Image;",
          "if (\\$img) {",
          "  \\$ms = New-Object System.IO.MemoryStream;",
          "  \\$img.Save(\\$ms, [System.Drawing.Imaging.ImageFormat]::Png);",
          "  \\$bytes = \\$ms.ToArray();",
          "  [Console]::OpenStandardOutput().Write(\\$bytes, 0, \\$bytes.Length)",
          "}",
        ].join(' ')
        return (
          `powershell.exe -NoProfile -Command '${psCmd}' > "\${${varName}}" 2>/dev/null || ` +
          `xclip -selection clipboard -t image/png -o > "\${${varName}}" 2>/dev/null || ` +
          `wl-paste --type image/png > "\${${varName}}" 2>/dev/null || ` +
          `xclip -selection clipboard -t image/bmp -o > "\${${varName}}" 2>/dev/null || ` +
          `wl-paste --type image/bmp > "\${${varName}}"`
        )
      }),
    verify: (text) =>
      text.includes("powershell.exe -NoProfile -Command '\\$img = Get-Clipboard -Format Image;"),
  },
  // 2.1.39 - Linux/WSL patches
  {
    name: 'checkImage-grep-pattern',
    version: '2.1.39',
    platform: ['wsl', 'nix'],
    search: 'grep -E "image/(png|jpeg|jpg|gif|webp)"',
    replace: (content, matches) => replaceAll(content, matches, () => 'grep -E "image/(png|jpeg|jpg|gif|webp|bmp)"'),
    verify: (text) => text.includes('grep -E "image/(png|jpeg|jpg|gif|webp|bmp)"'),
  },
  {
    name: 'wl-paste-bmp-conversion',
    version: '2.1.39',
    platform: ['wsl', 'nix'],
    search: /wl-paste --type image\/png > "\$\{(\w+)\}"/,
    replace: (content, matches) =>
      replaceAll(content, matches, (m) => {
        const [varName] = m.matched_groups
        return `wl-paste --type image/png 2>/dev/null || wl-paste --type image/bmp | magick bmp:- png:- > "\${${varName}}"`
      }),
    verify: (text) => text.includes('wl-paste --type image/png 2>/dev/null || wl-paste --type image/bmp | magick bmp:- png:- >'),
  },
  // 2.1.37 - Linux/WSL patches
  {
    name: 'checkImage-grep-pattern',
    version: '2.1.37',
    platform: ['wsl', 'nix'],
    search: 'grep -E "image/(png|jpeg|jpg|gif|webp)"',
    replace: (content, matches) => replaceAll(content, matches, () => 'grep -E "image/(png|jpeg|jpg|gif|webp|bmp)"'),
    verify: (text) => text.includes('grep -E "image/(png|jpeg|jpg|gif|webp|bmp)"'),
  },
  {
    name: 'wl-paste-bmp-conversion',
    version: '2.1.37',
    platform: ['wsl', 'nix'],
    search: /wl-paste --type image\/png > "\$\{(\w+)\}"/,
    replace: (content, matches) =>
      replaceAll(content, matches, (m) => {
        const [varName] = m.matched_groups
        return `wl-paste --type image/png 2>/dev/null || wl-paste --type image/bmp | magick bmp:- png:- > "\${${varName}}"`
      }),
    verify: (text) => text.includes('wl-paste --type image/png 2>/dev/null || wl-paste --type image/bmp | magick bmp:- png:- >'),
  },
  // 2.1.29 - Linux/WSL patches
  {
    name: 'checkImage-grep-pattern',
    version: '2.1.29',
    platform: ['wsl', 'nix'],
    search: 'grep -E "image/(png|jpeg|jpg|gif|webp)"',
    replace: (content, matches) => replaceAll(content, matches, () => 'grep -E "image/(png|jpeg|jpg|gif|webp|bmp)"'),
    verify: (text) => text.includes('grep -E "image/(png|jpeg|jpg|gif|webp|bmp)"'),
  },
  {
    name: 'wl-paste-bmp-conversion',
    version: '2.1.29',
    platform: ['wsl', 'nix'],
    search: /wl-paste --type image\/png > "\$\{(\w+)\}"/,
    replace: (content, matches) =>
      replaceAll(content, matches, (m) => {
        const [varName] = m.matched_groups
        return `wl-paste --type image/png 2>/dev/null || wl-paste --type image/bmp | magick bmp:- png:- > "\${${varName}}"`
      }),
    verify: (text) => text.includes('wl-paste --type image/png 2>/dev/null || wl-paste --type image/bmp | magick bmp:- png:- >'),
  },
  // 2.1.20 - Linux/WSL patches
  {
    name: 'checkImage-grep-pattern',
    version: '2.1.20',
    platform: ['wsl', 'nix'],
    search: 'grep -E "image/(png|jpeg|jpg|gif|webp)"',
    replace: (content, matches) => replaceAll(content, matches, () => 'grep -E "image/(png|jpeg|jpg|gif|webp|bmp)"'),
    verify: (text) => text.includes('grep -E "image/(png|jpeg|jpg|gif|webp|bmp)"'),
  },
  {
    name: 'wl-paste-bmp-conversion',
    version: '2.1.20',
    platform: ['wsl', 'nix'],
    search: /wl-paste --type image\/png > "\$\{(\w+)\}"/,
    replace: (content, matches) =>
      replaceAll(content, matches, (m) => {
        const [varName] = m.matched_groups
        return `wl-paste --type image/png 2>/dev/null || wl-paste --type image/bmp | magick bmp:- png:- > "\${${varName}}"`
      }),
    verify: (text) => text.includes('wl-paste --type image/png 2>/dev/null || wl-paste --type image/bmp | magick bmp:- png:- >'),
  },
  // 2.1.14 - Linux/WSL patches
  {
    name: 'checkImage-grep-pattern',
    version: '2.1.14',
    platform: ['wsl', 'nix'],
    search: 'grep -E "image/(png|jpeg|jpg|gif|webp)"',
    replace: (content, matches) => replaceAll(content, matches, () => 'grep -E "image/(png|jpeg|jpg|gif|webp|bmp)"'),
    verify: (text) => text.includes('grep -E "image/(png|jpeg|jpg|gif|webp|bmp)"'),
  },
  {
    name: 'wl-paste-bmp-conversion',
    version: '2.1.14',
    platform: ['wsl', 'nix'],
    search: /wl-paste --type image\/png > "\$\{(\w+)\}"/,
    replace: (content, matches) =>
      replaceAll(content, matches, (m) => {
        const [varName] = m.matched_groups
        return `wl-paste --type image/png 2>/dev/null || wl-paste --type image/bmp | magick bmp:- png:- > "\${${varName}}"`
      }),
    verify: (text) => text.includes('wl-paste --type image/png 2>/dev/null || wl-paste --type image/bmp | magick bmp:- png:- >'),
  },
]

applyPatches({ patches })
