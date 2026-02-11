#!/usr/bin/env node

/**
 * @typedef {import('./types.mjs').IPatch} IPatch
 */

import { applyPatches, replaceAll } from './util.mjs'

const targetSize = process.argv[2] || '144000'

/** @type {IPatch[]} */
const patches = [
  // 2.1.39 - Context window variable is Bbq=200000
  {
    name: 'context-window-Bbq',
    version: '2.1.39',
    platform: ['wsl', 'win', 'osx', 'nix'],
    search: /var Bbq=\d+/,
    replace: (content, matches) => replaceAll(content, matches, () => `var Bbq=${targetSize}`),
    verify: (text) => text.includes(`var Bbq=${targetSize}`),
  },
  // 2.1.37 - Context window is now $Iq=200000 (200K by default)
  // The new version uses dynamic context based on model:
  //   - opus-4-6: 1,000,000 tokens
  //   - default: 200,000 tokens
  // Since 200K > 144K, patching may not be necessary unless you want a smaller window
  {
    name: 'context-window-$Iq',
    version: '2.1.37',
    platform: ['wsl', 'win', 'osx', 'nix'],
    search: /var \$Iq=\d+/,
    replace: (content, matches) => replaceAll(content, matches, () => `var $Iq=${targetSize}`),
    verify: (text) => text.includes(`var $Iq=${targetSize}`),
  },
  // 2.1.29 - QEq is the actual context window variable used in mM() function
  {
    name: 'context-window-QEq',
    version: '2.1.29',
    platform: ['wsl', 'win', 'osx', 'nix'],
    search: /var QEq=\d+/,
    replace: (content, matches) => replaceAll(content, matches, () => `var QEq=${targetSize}`),
    verify: (text) => text.includes(`var QEq=${targetSize}`),
  },
  // 2.1.20
  {
    name: 'context-window-EiK',
    version: '2.1.20',
    platform: ['wsl', 'win', 'osx', 'nix'],
    search: /var EiK=\d+/,
    replace: (content, matches) => replaceAll(content, matches, () => `var EiK=${targetSize}`),
    verify: (text) => text.includes(`var EiK=${targetSize}`),
  },
  // 2.1.14
  {
    name: 'context-window-NS9',
    version: '2.1.14',
    platform: ['wsl', 'win', 'osx', 'nix'],
    search: /var NS9=\d+/,
    replace: (content, matches) => replaceAll(content, matches, () => `var NS9=${targetSize}`),
    verify: (text) => text.includes(`var NS9=${targetSize}`),
  },
  // 2.1.7
  {
    name: 'context-window-GCB',
    version: '2.1.7',
    platform: ['wsl', 'win', 'osx', 'nix'],
    search: /var GCB=\d+/,
    replace: (content, matches) => replaceAll(content, matches, () => `var GCB=${targetSize}`),
    verify: (text) => text.includes(`var GCB=${targetSize}`),
  },
  {
    name: 'context-window-VT9',
    version: '2.1.7',
    platform: ['wsl', 'win', 'osx', 'nix'],
    search: /var VT9=\d+/,
    replace: (content, matches) => replaceAll(content, matches, () => `var VT9=${targetSize}`),
    verify: (text) => text.includes(`var VT9=${targetSize}`),
  },
]

applyPatches({ patches })
