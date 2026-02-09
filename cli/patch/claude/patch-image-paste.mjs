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

/** @type {IPatch[]} */
const patches = [
  // 2.1.37 - Windows patches
  {
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
