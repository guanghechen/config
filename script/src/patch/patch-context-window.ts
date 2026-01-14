#!/usr/bin/env bun

import type { IPatch } from "./types"
import { applyPatches, replaceAll } from "./util"

const targetSize = process.argv[2] || "144000"

const patches: IPatch[] = [
  {
    name: "context-window-GCB",
    version: "2.1.7",
    platform: ["wsl", "win", "osx", "nix"],
    search: /var GCB=\d+/,
    replace: (content, matches) => replaceAll(content, matches, () => `var GCB=${targetSize}`),
    verify: (text) => text.includes(`var GCB=${targetSize}`),
  },
  {
    name: "context-window-VT9",
    version: "2.1.7",
    platform: ["wsl", "win", "osx", "nix"],
    search: /var VT9=\d+/,
    replace: (content, matches) => replaceAll(content, matches, () => `var VT9=${targetSize}`),
    verify: (text) => text.includes(`var VT9=${targetSize}`),
  },
]

applyPatches({ patches })
