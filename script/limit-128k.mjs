#!/usr/bin/env node
// Patch Claude Code context window size from 200K to 128K
// Usage: node limit-128k.mjs [size]
// Example: node limit-128k.mjs 128000

import { execSync } from "child_process";
import { readFileSync, writeFileSync, realpathSync } from "fs";

const targetSize = process.argv[2] || "150000";
const pattern = /function NO\(A\)\{if\(A\.includes\("\[1m\]"\)\)return 1e6;return \d+\}/;

function getCliPath() {
  const isWindows = process.platform === "win32";
  try {
    const cmd = isWindows ? "where claude" : "which claude";
    const which = execSync(cmd, { encoding: "utf-8" }).trim().split(/\r?\n/)[0];
    return realpathSync(which);
  } catch {
    return null;
  }
}

function main() {
  const cliPath = getCliPath();
  if (!cliPath) {
    console.error("❌ Claude Code not found");
    process.exit(1);
  }

  const content = readFileSync(cliPath, "utf-8");
  const match = content.match(pattern);

  if (!match) {
    console.error("❌ Cannot find NO function in cli.js");
    process.exit(1);
  }

  const currentSize = match[0].match(/return (\d+)\}$/)?.[1];

  if (currentSize === targetSize) {
    console.log(`✓ Already patched to ${targetSize}`);
    process.exit(0);
  }

  console.log(`Patching: ${currentSize} → ${targetSize}`);
  console.log(`File: ${cliPath}`);

  const newFunc = `function NO(A){if(A.includes("[1m]"))return 1e6;return ${targetSize}}`;
  const newContent = content.replace(pattern, newFunc);

  writeFileSync(cliPath, newContent);

  // Verify
  const verify = readFileSync(cliPath, "utf-8");
  if (verify.includes(`return ${targetSize}}`)) {
    console.log("✓ Patched successfully");
  } else {
    console.error("❌ Patch failed");
    process.exit(1);
  }
}

main();
