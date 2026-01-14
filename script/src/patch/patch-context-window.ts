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
    replace: `var GCB=${targetSize}`,
  },
  {
    name: "context-window-VT9",
    version: "2.1.7",
    platform: ["wsl", "win", "osx", "nix"],
    search: /var VT9=\d+/,
    replace: `var VT9=${targetSize}`,
  },
]

applyPatches({ patches })
