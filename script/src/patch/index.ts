#!/usr/bin/env bun

import { spawn } from "node:child_process"
import { dirname, join } from "node:path"

const __dirname = dirname(new URL(import.meta.url).pathname)
const contextWindowSize = process.argv[2]

const patches = [
  { name: "context-window", file: "context-window.ts", args: contextWindowSize ? [contextWindowSize] : [] },
  { name: "image-paste", file: "image-paste.ts", args: [] },
]

for (const { name, file, args } of patches) {
  console.log(`\n${"=".repeat(50)}`)
  console.log(`Running: ${name}`)
  console.log("=".repeat(50))

  await new Promise<void>((resolve) => {
    spawn("bun", [join(__dirname, file), ...args], { stdio: "inherit" }).on("close", resolve)
  })
}
