#!/usr/bin/env bun

import type { IPatch } from "./types"
import { applyPatches, replaceAll } from "./util"

const patches: IPatch[] = [
  {
    name: "checkImage-grep-pattern",
    version: "2.1.7",
    platform: ["wsl", "nix"],
    search: /grep -E "image\/\(png\|jpeg\|jpg\|gif\|webp\)"/,
    replace: (content, matches) => replaceAll(content, matches, () => 'grep -E "image/(png|jpeg|jpg|gif|webp|bmp)"'),
    verify: (text) => text.includes('grep -E "image/(png|jpeg|jpg|gif|webp|bmp)"'),
  },
  {
    name: "wl-paste-bmp-conversion",
    version: "2.1.7",
    platform: ["wsl", "nix"],
    search: "wl-paste --type image/png >",
    replace: (content, matches) =>
      replaceAll(content, matches, () => "wl-paste --type image/png 2>/dev/null || wl-paste --type image/bmp | magick bmp:- png:- >"),
    verify: (text) => text.includes("wl-paste --type image/png 2>/dev/null || wl-paste --type image/bmp | magick bmp:- png:- >"),
  },
  {
    // Original: zzA=$Q()==="windows"?{displayText:`${pH1}+v`,check:(A,Q)=>Q.meta&&(A==="v"||A==="V")}
    // Changed:  zzA=$Q()==="windows"?{displayText:"ctrl+v",check:(A,Q)=>Q.ctrl&&(A==="v"||A==="V")}
    // This makes Windows use Ctrl+V instead of Alt+V for image paste
    name: "win-image-paste-shortcut",
    version: "2.1.7",
    platform: ["win"],
    search: /(\w+)=\$Q\(\)==="windows"\?\{displayText:`\$\{\w+\}\+v`,check:\((\w+),(\w+)\)=>\3\.meta&&/,
    replace: (content, matches) =>
      replaceAll(content, matches, (m) => {
        const [varName, arg1, arg2] = m.matched_groups
        return `${varName}=$Q()==="windows"?{displayText:"ctrl+v",check:(${arg1},${arg2})=>${arg2}.ctrl&&`
      }),
    verify: (text) => text.includes('$Q()==="windows"?{displayText:"ctrl+v",check:'),
  },
]

applyPatches({ patches })
