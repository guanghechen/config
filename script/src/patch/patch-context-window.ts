#!/usr/bin/env bun

import { applyPatches } from "./apply"
import type { IPatch } from "./types"

const targetSize = process.argv[2] || "144000"

const patches: IPatch[] = [
  {
    name: "context-window-GCB",
    version: "2.1.7",
    platform: ["wsl", "win", "osx", "nix"],
    search: /var GCB=\d+/,
    replace: (content, matches) => {
      let result = content
      for (const m of matches.toReversed()) {
        result = result.slice(0, m.offset_start) + `var GCB=${targetSize}` + result.slice(m.offset_end)
      }
      return result
    },
    verify: (text) => text.includes(`var GCB=${targetSize}`),
  },
  {
    name: "context-window-VT9",
    version: "2.1.7",
    platform: ["wsl", "win", "osx", "nix"],
    search: /var VT9=\d+/,
    replace: (content, matches) => {
      let result = content
      for (const m of matches.toReversed()) {
        result = result.slice(0, m.offset_start) + `var VT9=${targetSize}` + result.slice(m.offset_end)
      }
      return result
    },
    verify: (text) => text.includes(`var VT9=${targetSize}`),
  },
]

applyPatches({ patches })
