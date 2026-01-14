#!/usr/bin/env bun

import { applyPatches } from "./apply"
import type { IPatch } from "./types"

const patches: IPatch[] = [
  {
    name: "checkImage-grep-pattern",
    version: "2.1.7",
    platform: ["wsl", "nix"],
    search: /grep -E "image\/\(png\|jpeg\|jpg\|gif\|webp\)"/,
    replace: 'grep -E "image/(png|jpeg|jpg|gif|webp|bmp)"',
  },
  {
    name: "wl-paste-bmp-conversion",
    version: "2.1.7",
    platform: ["wsl", "nix"],
    search: "wl-paste --type image/png >",
    replace: "wl-paste --type image/png 2>/dev/null || wl-paste --type image/bmp | magick bmp:- png:- >",
  },
]

applyPatches({ patches })
