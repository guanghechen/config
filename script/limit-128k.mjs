#!/usr/bin/env node
// Patch Claude Code context window size from 200K to custom size
// Usage: node limit-128k.mjs [size]
// Example: node limit-128k.mjs 128000

import { execSync } from "node:child_process";
import { existsSync, readFileSync, realpathSync, writeFileSync } from "node:fs";
import { platform } from "node:os";
import { dirname, join } from "node:path";

const targetSize = process.argv[2] || "150000";

const patterns = [
  { name: "v2.1+", regex: /return JO9\}var JO9=\d+/, replacement: `return JO9}var JO9=${targetSize}` },
  { name: "v2.0", regex: /function NO\(A\)\{if\(A\.includes\("\[1m\]"\)\)return 1e6;return \d+\}/, replacement: `function NO(A){if(A.includes("[1m]"))return 1e6;return ${targetSize}}` },
];

function getCliPath() {
  const isNativeWindows = platform() === "win32";

  try {
    const cmd = isNativeWindows ? "where.exe claude" : "which claude";
    const which = execSync(cmd, { encoding: "utf-8" }).trim().split(/\r?\n/)[0];

    if (isNativeWindows) {
      const cliJs = join(dirname(which), "node_modules", "@anthropic-ai", "claude-code", "cli.js");
      return existsSync(cliJs) ? cliJs : null;
    }

    return realpathSync(which);
  } catch {
    return null;
  }
}

const cliPath = getCliPath();
if (!cliPath) {
  console.error("❌ Claude Code not found");
  process.exit(1);
}

console.log(`File: ${cliPath}\n`);

const content = readFileSync(cliPath, "utf-8");

for (const { name, regex, replacement } of patterns) {
  const match = content.match(regex);
  if (!match) continue;

  if (content.includes(replacement)) {
    console.log(`✓ [context-window] Already patched to ${targetSize}`);
    process.exit(0);
  }

  console.log(`✓ [context-window] Patching (${name}): ${match[0].match(/\d+$/)?.[0]} → ${targetSize}`);

  writeFileSync(cliPath, content.replace(regex, replacement));

  if (readFileSync(cliPath, "utf-8").includes(replacement)) {
    console.log("\n✓ Patched 1 location(s) successfully");
  } else {
    console.error("\n❌ Patch verification failed");
    process.exit(1);
  }
  process.exit(0);
}

console.error("❌ [context-window] Pattern not found");
console.error("   Checked patterns:");
for (const { name } of patterns) console.error(`   - ${name}`);
process.exit(1);
