#!/usr/bin/env node

import { spawn } from 'node:child_process'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'

const __dirname = dirname(fileURLToPath(import.meta.url))

// Context-window patching is intentionally not part of the default flow:
// newer Claude Code defaults (200K / 1M) are kept as-is. The
// patch-context-window.mjs script is retained for manual use if needed:
//   node patch-context-window.mjs [size]
const patches = [
  { name: 'image-paste', file: 'patch-image-paste.mjs', args: [] },
]

for (const { name, file, args } of patches) {
  console.log(`\n${'='.repeat(50)}`)
  console.log(`Running: ${name}`)
  console.log('='.repeat(50))

  const script = join(__dirname, file)
  await new Promise((resolve) => {
    spawn(process.execPath, [script, ...args], { stdio: 'inherit' }).on('close', resolve)
  })
}
