#!/usr/bin/env bun

import type { IPatch } from "./types"
import { applyPatches, replaceAll } from "./util"

const targetSize = process.argv[2] || "144000"

const patches: IPatch[] = [
  // 2.1.12
  {
    name: "context-window-BS9",
    version: "2.1.12",
    platform: ["wsl", "win", "osx", "nix"],
    search: /var BS9=\d+/,
    replace: (content, matches) => replaceAll(content, matches, () => `var BS9=${targetSize}`),
    verify: (text) => text.includes(`var BS9=${targetSize}`),
  },
  {
    name: "context-window-S2B",
    version: "2.1.12",
    platform: ["wsl", "win", "osx", "nix"],
    search: /var S2B=\d+/,
    replace: (content, matches) => replaceAll(content, matches, () => `var S2B=${targetSize}`),
    verify: (text) => text.includes(`var S2B=${targetSize}`),
  },
  {
    name: "context-window-x2B",
    version: "2.1.12",
    platform: ["wsl", "win", "osx", "nix"],
    search: /,x2B=\d+/,
    replace: (content, matches) => replaceAll(content, matches, () => `,x2B=${targetSize}`),
    verify: (text) => text.includes(`,x2B=${targetSize}`),
  },
  // 2.1.7
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
