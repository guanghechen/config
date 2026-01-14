#!/usr/bin/env bun

import { applyPatches } from "./apply"
import type { IPatch } from "./types"

const patches: IPatch[] = [
  {
    name: "checkImage-grep-pattern",
    version: "2.1.7",
    platform: ["wsl", "nix"],
    search: /grep -E "image\/\(png\|jpeg\|jpg\|gif\|webp\)"/,
    replace: (content, matches) => {
      let result = content
      for (const m of matches.toReversed()) {
        result = result.slice(0, m.offset_start) + 'grep -E "image/(png|jpeg|jpg|gif|webp|bmp)"' + result.slice(m.offset_end)
      }
      return result
    },
    verify: (text) => text.includes('grep -E "image/(png|jpeg|jpg|gif|webp|bmp)"'),
  },
  {
    name: "wl-paste-bmp-conversion",
    version: "2.1.7",
    platform: ["wsl", "nix"],
    search: "wl-paste --type image/png >",
    replace: (content, matches) => {
      let result = content
      for (const m of matches.toReversed()) {
        result =
          result.slice(0, m.offset_start) +
          "wl-paste --type image/png 2>/dev/null || wl-paste --type image/bmp | magick bmp:- png:- >" +
          result.slice(m.offset_end)
      }
      return result
    },
    verify: (text) => text.includes("wl-paste --type image/png 2>/dev/null || wl-paste --type image/bmp | magick bmp:- png:- >"),
  },
  {
    // Original: zzA=$Q()==="windows"?{displayText:`${pH1}+v`,check:(A,Q)=>Q.meta&&(A==="v"||A==="V")}
    // Changed:  zzA=$Q()==="windows"?{displayText:"ctrl+v",check:(A,Q)=>Q.ctrl&&(A==="v"||A==="V")}
    // This changes the display text from "alt+v" to "ctrl+v" on Windows
    name: "win-image-paste-display",
    version: "2.1.7",
    platform: ["win"],
    search: /(\w+)=\$Q\(\)==="windows"\?\{displayText:`\$\{\w+\}\+v`,check:\((\w+),(\w+)\)=>\3\.meta&&/,
    replace: (content, matches) => {
      let result = content
      for (const m of matches.toReversed()) {
        const [varName, arg1, arg2] = m.matched_groups
        const replacement = `${varName}=$Q()==="windows"?{displayText:"ctrl+v",check:(${arg1},${arg2})=>${arg2}.ctrl&&`
        result = result.slice(0, m.offset_start) + replacement + result.slice(m.offset_end)
      }
      return result
    },
    verify: (text) => text.includes('$Q()==="windows"?{displayText:"ctrl+v",check:'),
  },
  {
    // Original: IH8=$Q()==="windows"?"alt+v":"ctrl+v"
    // Changed:  IH8=$Q()==="windows"?"ctrl+v":"ctrl+v"
    // This changes the actual keybinding from "alt+v" to "ctrl+v" on Windows
    name: "win-image-paste-keybinding",
    version: "2.1.7",
    platform: ["win"],
    search: /(\w+)=\$Q\(\)==="windows"\?"alt\+v":"ctrl\+v"/,
    replace: (content, matches) => {
      let result = content
      for (const m of matches.toReversed()) {
        const [varName] = m.matched_groups
        const replacement = `${varName}=$Q()==="windows"?"ctrl+v":"ctrl+v"`
        result = result.slice(0, m.offset_start) + replacement + result.slice(m.offset_end)
      }
      return result
    },
    verify: (text) => text.includes('$Q()==="windows"?"ctrl+v":"ctrl+v"'),
  },
]

applyPatches({ patches })
