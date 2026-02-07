#!/usr/bin/env node

import { spawn } from 'node:child_process'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'

const __dirname = dirname(fileURLToPath(import.meta.url))
const contextWindowSize = process.argv[2]

const patches = [
  { name: 'context-window', file: 'patch-context-window.mjs', args: contextWindowSize ? [contextWindowSize] : [] },
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
