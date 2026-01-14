#!/usr/bin/env bun

import {
  applyPatches,
  createIncludesVerifier,
  createRegexSearcher,
  createSimpleReplacer,
  createStringSearcher,
  type IPatch,
} from "./types"

const patches: IPatch[] = [
  {
    name: "checkImage-grep-pattern",
    version: "2.1.7",
    platform: ["wsl", "nix"],
    search: createRegexSearcher(/grep -E "image\/\(png\|jpeg\|jpg\|gif\|webp\)"/g),
    replace: createSimpleReplacer('grep -E "image/(png|jpeg|jpg|gif|webp|bmp)"'),
    verify: createIncludesVerifier('grep -E "image/(png|jpeg|jpg|gif|webp|bmp)"'),
  },
  {
    name: "wl-paste-bmp-conversion",
    version: "2.1.7",
    platform: ["wsl", "nix"],
    search: createStringSearcher("wl-paste --type image/png >"),
    replace: createSimpleReplacer(
      "wl-paste --type image/png 2>/dev/null || wl-paste --type image/bmp | magick bmp:- png:- >",
    ),
    verify: createIncludesVerifier(
      "wl-paste --type image/png 2>/dev/null || wl-paste --type image/bmp | magick bmp:- png:- >",
    ),
  },
]

applyPatches({ patches })
