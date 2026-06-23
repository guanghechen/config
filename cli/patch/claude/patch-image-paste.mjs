#!/usr/bin/env node

/**
 * Windows Image Paste Patch
 *
 * Fixes image paste functionality on Windows. Two main issues:
 *
 * 1. Shortcut key: Change from Alt+V to Ctrl+V
 *    - Original uses Alt+V (Q.meta) which doesn't work on Windows
 *    - Need Ctrl+V (Q.ctrl) as the standard Windows paste shortcut
 *
 * 2. Trigger mechanism: Windows Terminal doesn't support bracketed paste mode
 *    - macOS/Linux use escape sequences (\x1B[200~ and \x1B[201~) to detect paste
 *    - Windows needs direct Ctrl+V key detection in the input handler
 *
 * Note: BMP format handling may be needed for WSL (wl-paste outputs BMP on some systems)
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
  // 2.1.186 - Windows patch
  // Same shape as 2.1.178: keybinding maps Windows/WSL to Alt+V via a shared
  // boolean, e.g. Eyd=Syd?"alt+v":"ctrl+v"
  {
    name: 'win-image-paste-keybinding',
    version: '2.1.186',
    platform: ['win'],
    search: new RegExp(`(${jsIdentifier})=(${jsIdentifier})\\?"alt\\+v":"ctrl\\+v"`),
    replace: (content, matches) =>
      replaceAll(content, matches, (m) => {
        const [varName, platformVar] = m.matched_groups
        return `${varName}=${platformVar}?"ctrl+v":"ctr+v"`
      }),
    verify: (text) => new RegExp(`${jsIdentifier}=${jsIdentifier}\\?"ctrl\\+v":"ctr\\+v"`).test(text),
  },
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
  // 2.1.178 - Windows patch
  // Same shape as 2.1.163: keybinding maps Windows/WSL to Alt+V via a shared
  // boolean, e.g. f65=_65?"alt+v":"ctrl+v"
  {
    name: 'win-image-paste-keybinding',
    version: '2.1.178',
    platform: ['win'],
    search: new RegExp(`(${jsIdentifier})=(${jsIdentifier})\\?"alt\\+v":"ctrl\\+v"`),
    replace: (content, matches) =>
      replaceAll(content, matches, (m) => {
        const [varName, platformVar] = m.matched_groups
        return `${varName}=${platformVar}?"ctrl+v":"ctr+v"`
      }),
    verify: (text) => new RegExp(`${jsIdentifier}=${jsIdentifier}\\?"ctrl\\+v":"ctr\\+v"`).test(text),
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
  // 2.1.163 - Windows patch
  // Chat keybinding now maps Windows/WSL to Alt+V through a shared boolean:
  //   fC_=zC_?"alt+v":"ctrl+v"
  // Keep the replacement length stable for native binary patching.
  {
    name: 'win-image-paste-keybinding',
    version: '2.1.163',
    platform: ['win'],
    search: new RegExp(`(${jsIdentifier})=(${jsIdentifier})\\?"alt\\+v":"ctrl\\+v"`),
    replace: (content, matches) =>
      replaceAll(content, matches, (m) => {
        const [varName, platformVar] = m.matched_groups
        return `${varName}=${platformVar}?"ctrl+v":"ctr+v"`
      }),
    verify: (text) => new RegExp(`${jsIdentifier}=${jsIdentifier}\\?"ctrl\\+v":"ctr\\+v"`).test(text),
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
  // 2.1.146 - Windows patch
  // Chat keybindings still use Alt+V on Windows:
  //   go1=s$()==="windows"?"alt+v":"ctrl+v"
  // Keep the replacement length stable for native binary patching.
  {
    name: 'win-image-paste-keybinding',
    version: '2.1.146',
    platform: ['win'],
    search: new RegExp(`(${jsIdentifier})=(${jsIdentifier})\\(\\)==="windows"\\?"alt\\+v":"ctrl\\+v"`),
    replace: (content, matches) =>
      replaceAll(content, matches, (m) => {
        const [varName, platformFn] = m.matched_groups
        return `${varName}=${platformFn}()==="windows"?"ctrl+v":"ctr+v"`
      }),
    verify: (text) => new RegExp(`${jsIdentifier}=${jsIdentifier}\\(\\)==="windows"\\?"ctrl\\+v":"ctr\\+v"`).test(text),
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
  // 2.1.119 - Windows patch
  // In this version, Chat keybindings still use Alt+V on Windows:
  //   Cw_=K8()==="windows"?"alt+v":"ctrl+v"
  // Keep the function name generic because it differs across platform builds.
  {
    name: 'win-image-paste-keybinding',
    version: '2.1.119',
    platform: ['win'],
    search: new RegExp(`(${jsIdentifier})=(${jsIdentifier})\\(\\)==="windows"\\?"alt\\+v":"ctrl\\+v"`),
    replace: (content, matches) =>
      replaceAll(content, matches, (m) => {
        const [varName, platformFn] = m.matched_groups
        return `${varName}=${platformFn}()==="windows"?"ctrl+v":"ctr+v"`
      }),
    verify: (text) => new RegExp(`${jsIdentifier}=${jsIdentifier}\\(\\)==="windows"\\?"ctrl\\+v":"ctr\\+v"`).test(text),
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
  // 2.1.92 - Windows patch
  // In this version, Chat keybindings still use Alt+V on Windows:
  //   yHz=T1()==="windows"?"alt+v":"ctrl+v"
  // We patch it to Ctrl+V for consistent Windows paste behavior.
  {
    name: 'win-image-paste-keybinding',
    version: '2.1.92',
    platform: ['win'],
    search: /(\w+)=T1\(\)==="windows"\?"alt\+v":"ctrl\+v"/,
    replace: (content, matches) =>
      replaceAll(content, matches, (m) => {
        const [varName] = m.matched_groups
        return `${varName}=T1()==="windows"?"ctrl+v":"ctrl+v"`
      }),
    verify: (text) => text.includes('T1()==="windows"?"ctrl+v":"ctrl+v"'),
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
  // 2.1.70 - Windows patches
  // Same as 2.1.50: grep already includes bmp, saveImage chain has bmp fallback.
  // Only Windows keybinding/shortcut patches are needed.
  {
    // Fix keyboard shortcut binding: Windows uses "alt+v" but should use "ctrl+v"
    // Original: Da9=a8()==="windows"?"alt+v":"ctrl+v"
    // Changed:  Da9=a8()==="windows"?"ctrl+v":"ctrl+v"
    name: 'win-image-paste-keybinding',
    version: '2.1.70',
    platform: ['win'],
    search: /(\w+)=a8\(\)==="windows"\?"alt\+v":"ctrl\+v"/,
    replace: (content, matches) =>
      replaceAll(content, matches, (m) => {
        const [varName] = m.matched_groups
        return `${varName}=a8()==="windows"?"ctrl+v":"ctrl+v"`
      }),
    verify: (text) => text.includes('a8()==="windows"?"ctrl+v":"ctrl+v"'),
  },
  {
    // Fix displayText and check function for image paste hint
    // Original: ly1=a8()==="windows"?{displayText:`${cy1}+v`,check:(A,q)=>q.meta&&(A==="v"||A==="V")}
    // Changed:  ly1=a8()==="windows"?{displayText:"ctrl+v",check:(A,q)=>q.ctrl&&(A==="v"||A==="V")}
    name: 'win-image-paste-shortcut',
    version: '2.1.70',
    platform: ['win'],
    search: /(\w+)=a8\(\)==="windows"\?\{displayText:`\$\{\w+\}\+v`,check:\((\w+),(\w+)\)=>\3\.meta&&/,
    replace: (content, matches) =>
      replaceAll(content, matches, (m) => {
        const [varName, arg1, arg2] = m.matched_groups
        return `${varName}=a8()==="windows"?{displayText:"ctrl+v",check:(${arg1},${arg2})=>${arg2}.ctrl&&`
      }),
    verify: (text) => text.includes('a8()==="windows"?{displayText:"ctrl+v",check:'),
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
  // 2.1.50 - Windows patches (Bun SEA binary)
  // Note: Since 2.1.50, Claude Code ships as a Bun SEA (ELF binary).
  // - grep pattern already includes bmp (built-in)
  // - BMP→PNG conversion via native image processor (built-in)
  // - wl-paste BMP fallback already in saveImage chain (built-in)
  // Only Windows keybinding/shortcut patches are needed.
  {
    // Fix keyboard shortcut binding: Windows uses "alt+v" but should use "ctrl+v"
    // Original: SP1=HL()==="windows"?"alt+v":"ctrl+v"
    // Changed:  SP1=HL()==="windows"?"ctrl+v":"ctrl+v"
    name: 'win-image-paste-keybinding',
    version: '2.1.50',
    platform: ['win'],
    search: /(\w+)=HL\(\)==="windows"\?"alt\+v":"ctrl\+v"/,
    replace: (content, matches) =>
      replaceAll(content, matches, (m) => {
        const [varName] = m.matched_groups
        return `${varName}=HL()==="windows"?"ctrl+v":"ctrl+v"`
      }),
    verify: (text) => text.includes('HL()==="windows"?"ctrl+v":"ctrl+v"'),
  },
  {
    // Fix displayText and check function for image paste hint
    // Original: oFH=HL()==="windows"?{displayText:`${UU$}+v`,check:(H,$)=>$.meta&&(H==="v"||H==="V")}
    // Changed:  oFH=HL()==="windows"?{displayText:"ctrl+v",check:(H,$)=>$.ctrl&&(H==="v"||H==="V")}
    name: 'win-image-paste-shortcut',
    version: '2.1.50',
    platform: ['win'],
    search: /(\w+)=HL\(\)==="windows"\?\{displayText:`\$\{\w+\}\+v`,check:\((\w+),(\w+)\)=>\3\.meta&&/,
    replace: (content, matches) =>
      replaceAll(content, matches, (m) => {
        const [varName, arg1, arg2] = m.matched_groups
        return `${varName}=HL()==="windows"?{displayText:"ctrl+v",check:(${arg1},${arg2})=>${arg2}.ctrl&&`
      }),
    verify: (text) => text.includes('HL()==="windows"?{displayText:"ctrl+v",check:'),
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
  // 2.1.39 - Windows patches
  {
    // Fix keyboard shortcut binding: Windows uses "alt+v" but should use "ctrl+v"
    // Original: Nk5=tA()==="windows"?"alt+v":"ctrl+v"
    // Changed:  Nk5=tA()==="windows"?"ctrl+v":"ctrl+v"
    name: 'win-image-paste-keybinding',
    version: '2.1.39',
    platform: ['win'],
    search: /(\w+)=tA\(\)==="windows"\?"alt\+v":"ctrl\+v"/,
    replace: (content, matches) =>
      replaceAll(content, matches, (m) => {
        const [varName] = m.matched_groups
        return `${varName}=tA()==="windows"?"ctrl+v":"ctrl+v"`
      }),
    verify: (text) => text.includes('tA()==="windows"?"ctrl+v":"ctrl+v"'),
  },
  {
    // Fix displayText and check function for image paste hint
    // Original: HZ1=tA()==="windows"?{displayText:`${Bf6}+v`,check:(A,q)=>q.meta&&(A==="v"||A==="V")}
    // Changed:  HZ1=tA()==="windows"?{displayText:"ctrl+v",check:(A,q)=>q.ctrl&&(A==="v"||A==="V")}
    name: 'win-image-paste-shortcut',
    version: '2.1.39',
    platform: ['win'],
    search: /(\w+)=tA\(\)==="windows"\?\{displayText:`\$\{\w+\}\+v`,check:\((\w+),(\w+)\)=>\3\.meta&&/,
    replace: (content, matches) =>
      replaceAll(content, matches, (m) => {
        const [varName, arg1, arg2] = m.matched_groups
        return `${varName}=tA()==="windows"?{displayText:"ctrl+v",check:(${arg1},${arg2})=>${arg2}.ctrl&&`
      }),
    verify: (text) => text.includes('tA()==="windows"?{displayText:"ctrl+v",check:'),
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
  // 2.1.37 - Windows patches
  {
    // Fix keyboard shortcut binding: Windows uses "alt+v" but should use "ctrl+v"
    // Original: gT5=oA()==="windows"?"alt+v":"ctrl+v"
    // Changed:  gT5=oA()==="windows"?"ctrl+v":"ctrl+v"
    name: 'win-image-paste-keybinding',
    version: '2.1.37',
    platform: ['win'],
    search: /(\w+)=oA\(\)==="windows"\?"alt\+v":"ctrl\+v"/,
    replace: (content, matches) =>
      replaceAll(content, matches, (m) => {
        const [varName] = m.matched_groups
        return `${varName}=oA()==="windows"?"ctrl+v":"ctrl+v"`
      }),
    verify: (text) => text.includes('oA()==="windows"?"ctrl+v":"ctrl+v"'),
  },
  {
    // Fix displayText and check function for image paste hint
    // Original: qP1=oA()==="windows"?{displayText:`${XSA}+v`,check:(A,q)=>q.meta&&(A==="v"||A==="V")}
    // Changed:  qP1=oA()==="windows"?{displayText:"ctrl+v",check:(A,q)=>q.ctrl&&(A==="v"||A==="V")}
    name: 'win-image-paste-shortcut',
    version: '2.1.37',
    platform: ['win'],
    search: /(\w+)=oA\(\)==="windows"\?\{displayText:`\$\{\w+\}\+v`,check:\((\w+),(\w+)\)=>\3\.meta&&/,
    replace: (content, matches) =>
      replaceAll(content, matches, (m) => {
        const [varName, arg1, arg2] = m.matched_groups
        return `${varName}=oA()==="windows"?{displayText:"ctrl+v",check:(${arg1},${arg2})=>${arg2}.ctrl&&`
      }),
    verify: (text) => text.includes('oA()==="windows"?{displayText:"ctrl+v",check:'),
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
  // 2.1.29 - Windows patches
  {
    // Original: UP1=cA()==="windows"?{displayText:`${IRA}+v`,check:(A,q)=>q.meta&&(A==="v"||A==="V")}
    // Changed:  UP1=cA()==="windows"?{displayText:"ctrl+v",check:(A,q)=>q.ctrl&&(A==="v"||A==="V")}
    name: 'win-image-paste-shortcut',
    version: '2.1.29',
    platform: ['win'],
    search: /(\w+)=cA\(\)==="windows"\?\{displayText:`\$\{\w+\}\+v`,check:\((\w+),(\w+)\)=>\3\.meta&&/,
    replace: (content, matches) =>
      replaceAll(content, matches, (m) => {
        const [varName, arg1, arg2] = m.matched_groups
        return `${varName}=cA()==="windows"?{displayText:"ctrl+v",check:(${arg1},${arg2})=>${arg2}.ctrl&&`
      }),
    verify: (text) => text.includes('cA()==="windows"?{displayText:"ctrl+v",check:'),
  },
  {
    // Windows doesn't support bracketed paste mode, so we need to check for image paste
    // when Ctrl+V is pressed (detected as input with ctrl flag).
    // Original: wrappedOnInput:(G,Z)=>{if(O.current)$.current=!0
    // Changed:  wrappedOnInput:(G,Z)=>{if(Z.ctrl&&(G==="v"||G==="V")&&K){j();return}if(O.current)$.current=!0
    name: 'win-image-paste-ctrl-v',
    version: '2.1.29',
    platform: ['win'],
    search: 'wrappedOnInput:(G,Z)=>{if(O.current)$.current=!0',
    replace: (content, matches) =>
      replaceAll(content, matches, () => 'wrappedOnInput:(G,Z)=>{if(Z.ctrl&&(G==="v"||G==="V")&&K){j();return}if(O.current)$.current=!0'),
    verify: (text) => text.includes('wrappedOnInput:(G,Z)=>{if(Z.ctrl&&(G==="v"||G==="V")&&K){j();return}'),
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
  // 2.1.20 - Windows patches
  {
    // Original: njA=s6()==="windows"?{displayText:`${ku6}+v`,check:(A,K)=>K.meta&&(A==="v"||A==="V")}
    // Changed:  njA=s6()==="windows"?{displayText:"ctrl+v",check:(A,K)=>K.ctrl&&(A==="v"||A==="V")}
    name: 'win-image-paste-shortcut',
    version: '2.1.20',
    platform: ['win'],
    search: /(\w+)=s6\(\)==="windows"\?\{displayText:`\$\{\w+\}\+v`,check:\((\w+),(\w+)\)=>\3\.meta&&/,
    replace: (content, matches) =>
      replaceAll(content, matches, (m) => {
        const [varName, arg1, arg2] = m.matched_groups
        return `${varName}=s6()==="windows"?{displayText:"ctrl+v",check:(${arg1},${arg2})=>${arg2}.ctrl&&`
      }),
    verify: (text) => text.includes('s6()==="windows"?{displayText:"ctrl+v",check:'),
  },
  {
    // Windows doesn't support bracketed paste mode, so we need to check for image paste
    // when Ctrl+V is pressed (detected as input with ctrl flag).
    // Original: wrappedOnInput:(j,P)=>{if(J.current)O.current=!0
    // Changed:  wrappedOnInput:(j,P)=>{if(P.ctrl&&(j==="v"||j==="V")&&q){G();return}if(J.current)O.current=!0
    name: 'win-image-paste-ctrl-v',
    version: '2.1.20',
    platform: ['win'],
    search: 'wrappedOnInput:(j,P)=>{if(J.current)O.current=!0',
    replace: (content, matches) =>
      replaceAll(content, matches, () => 'wrappedOnInput:(j,P)=>{if(P.ctrl&&(j==="v"||j==="V")&&q){G();return}if(J.current)O.current=!0'),
    verify: (text) => text.includes('wrappedOnInput:(j,P)=>{if(P.ctrl&&(j==="v"||j==="V")&&q){G();return}'),
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
  // 2.1.14 - Windows patches
  {
    // Original: RFA=i0()==="windows"?{displayText:`${bL0}+v`,check:(A,Q)=>Q.meta&&(A==="v"||A==="V")}
    // Changed:  RFA=i0()==="windows"?{displayText:"ctrl+v",check:(A,Q)=>Q.ctrl&&(A==="v"||A==="V")}
    name: 'win-image-paste-shortcut',
    version: '2.1.14',
    platform: ['win'],
    search: /(\w+)=i0\(\)==="windows"\?\{displayText:`\$\{\w+\}\+v`,check:\((\w+),(\w+)\)=>\3\.meta&&/,
    replace: (content, matches) =>
      replaceAll(content, matches, (m) => {
        const [varName, arg1, arg2] = m.matched_groups
        return `${varName}=i0()==="windows"?{displayText:"ctrl+v",check:(${arg1},${arg2})=>${arg2}.ctrl&&`
      }),
    verify: (text) => text.includes('i0()==="windows"?{displayText:"ctrl+v",check:'),
  },
  {
    // Windows doesn't support bracketed paste mode, so we need to check for image paste
    // when Ctrl+V is pressed (detected as input with ctrl flag).
    // Original: wrappedOnInput:(C,L)=>{if(X.current)I.current=!0
    // Changed:  wrappedOnInput:(C,L)=>{if(L.ctrl&&(C==="v"||C==="V")&&B){F();return}if(X.current)I.current=!0
    name: 'win-image-paste-ctrl-v',
    version: '2.1.14',
    platform: ['win'],
    search: 'wrappedOnInput:(C,L)=>{if(X.current)I.current=!0',
    replace: (content, matches) =>
      replaceAll(content, matches, () => 'wrappedOnInput:(C,L)=>{if(L.ctrl&&(C==="v"||C==="V")&&B){F();return}if(X.current)I.current=!0'),
    verify: (text) => text.includes('wrappedOnInput:(C,L)=>{if(L.ctrl&&(C==="v"||C==="V")&&B){F();return}'),
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
