#!/usr/bin/env node

/**
 * @typedef {import('./types.mjs').IPatch} IPatch
 */

import { applyPatches, replaceAll } from './util.mjs'

const targetSize = process.argv[2] || '144000'
const jsIdentifier = String.raw`[A-Za-z_$][A-Za-z0-9_$]*`
const jsMemberExpression = String.raw`${jsIdentifier}(?:\.${jsIdentifier})*`
const contextWindow1mSearch = new RegExp(
  String.raw`CLAUDE_CODE_MAX_CONTEXT_TOKENS\)\{let ${jsIdentifier}=parseInt\(process\.env\.CLAUDE_CODE_MAX_CONTEXT_TOKENS,10\);if\(!isNaN\(${jsIdentifier}\)&&${jsIdentifier}>0\)return ${jsIdentifier}\}` +
    String.raw`if\(${jsIdentifier}\(${jsIdentifier}\)\)return 1e6;if\(${jsIdentifier}\?\.includes\(${jsMemberExpression}\)&&${jsIdentifier}\(${jsIdentifier}\)\)return 1e6;` +
    String.raw`if\(${jsIdentifier}\(${jsIdentifier}\)\)return 1e6;let ${jsIdentifier}=${jsIdentifier}\(${jsIdentifier}\);if\(${jsIdentifier}!==null\)return ${jsIdentifier};return (${jsIdentifier})`,
)
const contextWindowSnippetSearch = new RegExp(
  String.raw`CLAUDE_CODE_MAX_CONTEXT_TOKENS\)\{let ${jsIdentifier}=parseInt\(process\.env\.CLAUDE_CODE_MAX_CONTEXT_TOKENS,10\);if\(!isNaN\(${jsIdentifier}\)&&${jsIdentifier}>0\)return ${jsIdentifier}\}` +
    String.raw`if\(${jsIdentifier}\(${jsIdentifier}\)\)return (${jsIdentifier}|1e6);if\(${jsIdentifier}\?\.includes\(${jsMemberExpression}\)&&${jsIdentifier}\(${jsIdentifier}\)\)return (${jsIdentifier}|1e6);` +
    String.raw`if\(${jsIdentifier}\(${jsIdentifier}\)\)return (${jsIdentifier}|1e6);let ${jsIdentifier}=${jsIdentifier}\(${jsIdentifier}\);if\(${jsIdentifier}!==null\)return ${jsIdentifier};return (${jsIdentifier})`,
  'g',
)

/**
 * @param {string} text
 * @returns {boolean}
 */
function hasPatchedContextWindow1m(text) {
  const matches = [...text.matchAll(contextWindowSnippetSearch)]
  return matches.length > 0 && matches.every((m) => m[1] === m[4] && m[2] === m[4] && m[3] === m[4])
}

/** @type {IPatch[]} */
const patches = [
  // 2.1.146 - Context window constants keep the same role as 2.1.119,
  // but the trailing 8K constant is no longer adjacent in the bundle.
  {
    name: 'context-window-200k',
    version: '2.1.146',
    platform: ['wsl', 'win', 'osx', 'nix'],
    search: /var ([A-Za-z_$][A-Za-z0-9_$]*)=200000,[A-Za-z_$][A-Za-z0-9_$]*=20000,[A-Za-z_$][A-Za-z0-9_$]*=32000,[A-Za-z_$][A-Za-z0-9_$]*=128000/,
    replace: (content, matches) =>
      replaceAll(content, matches, (m) => m.matched_text.replace(/=200000/, `=${targetSize}`)),
    verify: (text) =>
      new RegExp(
        `var ${jsIdentifier}=${targetSize},${jsIdentifier}=20000,${jsIdentifier}=32000,${jsIdentifier}=128000`,
      ).test(text),
  },
  // 2.1.146 - 1M-capable branches now include a member expression in the
  // header allowlist check, for example `includes(TF.header)`.
  {
    name: 'context-window-1e6',
    version: '2.1.146',
    platform: ['wsl', 'win', 'osx', 'nix'],
    search: contextWindow1mSearch,
    replace: (content, matches) =>
      replaceAll(content, matches, (m) => {
        const [varName] = m.matched_groups
        return m.matched_text.replaceAll('return 1e6', `return ${varName}`)
      }),
    verify: hasPatchedContextWindow1m,
  },
  // 2.1.119 - Context window variable keeps the same role, but surrounding
  // output-token constants changed from 64K to 128K and identifiers may contain `$`.
  {
    name: 'context-window-200k',
    version: '2.1.119',
    platform: ['wsl', 'win', 'osx', 'nix'],
    search: /var ([A-Za-z_$][A-Za-z0-9_$]*)=200000,[A-Za-z_$][A-Za-z0-9_$]*=20000,[A-Za-z_$][A-Za-z0-9_$]*=32000,[A-Za-z_$][A-Za-z0-9_$]*=128000,[A-Za-z_$][A-Za-z0-9_$]*=8000/,
    replace: (content, matches) =>
      replaceAll(content, matches, (m) => m.matched_text.replace(/=200000/, `=${targetSize}`)),
    verify: (text) =>
      new RegExp(
        `var ${jsIdentifier}=${targetSize},${jsIdentifier}=20000,${jsIdentifier}=32000,${jsIdentifier}=128000,${jsIdentifier}=8000`,
      ).test(text),
  },
  // 2.1.119 - 1M-capable models now return `1e6` directly in the context
  // function. Replace those branches with the default context variable.
  {
    name: 'context-window-1e6',
    version: '2.1.119',
    platform: ['wsl', 'win', 'osx', 'nix'],
    search: contextWindow1mSearch,
    replace: (content, matches) =>
      replaceAll(content, matches, (m) => {
        const [varName] = m.matched_groups
        return m.matched_text.replaceAll('return 1e6', `return ${varName}`)
      }),
    verify: hasPatchedContextWindow1m,
  },
  // 2.1.92 - Context window variable follows the same shape as 2.1.50+
  {
    name: 'context-window-200k',
    version: '2.1.92',
    platform: ['wsl', 'win', 'osx', 'nix'],
    search: /var (\w+)=200000,\w+=20000,\w+=32000,\w+=64000/,
    replace: (content, matches) =>
      replaceAll(content, matches, (m) => m.matched_text.replace(/=200000/, `=${targetSize}`)),
    verify: (text) => new RegExp(`var \\w+=${targetSize},\\w+=20000,\\w+=32000,\\w+=64000`).test(text),
  },
  // 2.1.92 - Opus-4-6 / Sonnet-4 use a separate 1M branch: `return 1e6;return <var>`
  {
    name: 'context-window-1e6',
    version: '2.1.92',
    platform: ['wsl', 'win', 'osx', 'nix'],
    search: /return 1e6;return (\w+)/,
    replace: (content, matches) =>
      replaceAll(content, matches, (m) => {
        const [varName] = m.matched_groups
        return `return ${varName};return ${varName}`
      }),
    verify: (text) => !/return 1e6;return \w+/.test(text),
  },
  // 2.1.50 - Context window variable (Bun SEA: aQB=200000, Node.js: uIq=200000)
  {
    name: 'context-window-200k',
    version: '2.1.50',
    platform: ['wsl', 'win', 'osx', 'nix'],
    search: /var (\w+)=200000,\w+=20000,\w+=32000,\w+=64000/,
    replace: (content, matches) =>
      replaceAll(content, matches, (m) => m.matched_text.replace(/=200000/, `=${targetSize}`)),
    verify: (text) => new RegExp(`var \\w+=${targetSize},\\w+=20000,\\w+=32000,\\w+=64000`).test(text),
  },
  // 2.1.50 - Opus-4-6 / Sonnet-4 use a separate 1M branch: `return 1e6;return <var>`
  // Unify all models to use the same context window variable (same length replacement)
  {
    name: 'context-window-1e6',
    version: '2.1.50',
    platform: ['wsl', 'win', 'osx', 'nix'],
    search: /return 1e6;return (\w+)/,
    replace: (content, matches) =>
      replaceAll(content, matches, (m) => {
        const [varName] = m.matched_groups
        return `return ${varName};return ${varName}`
      }),
    verify: (text) => !/return 1e6;return \w+/.test(text),
  },
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
