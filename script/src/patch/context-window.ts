#!/usr/bin/env bun

import {
  applyPatches,
  createIncludesVerifier,
  createRegexSearcher,
  createSimpleReplacer,
  type IPatch,
} from './types'

const targetSize = process.argv[2] || '144000'

const patches: IPatch[] = [
  {
    name: 'context-window',
    version: '2.1.7',
    platform: ['wsl', 'win', 'osx', 'nix'],
    search: createRegexSearcher(/var GCB=\d+/),
    replace: createSimpleReplacer(`var GCB=${targetSize}`),
    verify: createIncludesVerifier(`var GCB=${targetSize}`),
  },
]

applyPatches({
  patches,
  stopOnFirst: true,
  formatMatch: (_patch, match) => `${match.match.match(/\d+$/)?.[0]} -> ${targetSize}`,
})
