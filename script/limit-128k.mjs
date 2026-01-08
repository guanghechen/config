#!/usr/bin/env node
// Patch Claude Code context window size from 200K to custom size
// Usage: node limit-128k.mjs [size]
// Example: node limit-128k.mjs 128000

import { execSync } from "child_process";
import { readFileSync, writeFileSync, realpathSync } from "fs";

const targetSize = process.argv[2] || "150000";

// v2.1.1+: ...return JO9}var JO9=200000
const patternV2 = /return JO9\}var JO9=\d+/;

// v2.0.x: function NO(A){if(A.includes("[1m]"))return 1e6;return \d+}
const patternV1 = /function NO\(A\)\{if\(A\.includes\("\[1m\]"\)\)return 1e6;return \d+\}/;

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

  // Try v2.1.1+ pattern first
  let matchV2 = content.match(patternV2);
  if (matchV2) {
    const currentSize = matchV2[0].match(/JO9=(\d+)$/)?.[1];

    if (currentSize === targetSize) {
      console.log(`✓ Already patched to ${targetSize}`);
      process.exit(0);
    }

    console.log(`Patching (v2.1+): ${currentSize} → ${targetSize}`);
    console.log(`File: ${cliPath}`);

    const newContent = content.replace(patternV2, `return JO9}var JO9=${targetSize}`);
    writeFileSync(cliPath, newContent);

    // Verify
    const verify = readFileSync(cliPath, "utf-8");
    if (verify.includes(`return JO9}var JO9=${targetSize}`)) {
      console.log("✓ Patched successfully");
    } else {
      console.error("❌ Patch failed");
      process.exit(1);
    }
    return;
  }

  // Fallback to v2.0.x pattern
  let matchV1 = content.match(patternV1);
  if (matchV1) {
    const currentSize = matchV1[0].match(/return (\d+)\}$/)?.[1];

    if (currentSize === targetSize) {
      console.log(`✓ Already patched to ${targetSize}`);
      process.exit(0);
    }

    console.log(`Patching (v2.0): ${currentSize} → ${targetSize}`);
    console.log(`File: ${cliPath}`);

    const newFunc = `function NO(A){if(A.includes("[1m]"))return 1e6;return ${targetSize}}`;
    const newContent = content.replace(patternV1, newFunc);
    writeFileSync(cliPath, newContent);

    // Verify
    const verify = readFileSync(cliPath, "utf-8");
    if (verify.includes(`return ${targetSize}}`)) {
      console.log("✓ Patched successfully");
    } else {
      console.error("❌ Patch failed");
      process.exit(1);
    }
    return;
  }

  console.error("❌ Cannot find context window size pattern in cli.js");
  console.error("   Checked patterns:");
  console.error("   - v2.1+: return JO9}var JO9=<number>");
  console.error("   - v2.0:  function NO(A){...return <number>}");
  process.exit(1);
}

main();
