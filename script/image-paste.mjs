#!/usr/bin/env node
// Patch Claude Code to support image/bmp format in clipboard
// Usage: node image-paste.mjs

import { execSync } from "node:child_process";
import { existsSync, readFileSync, realpathSync, writeFileSync } from "node:fs";
import { platform } from "node:os";
import { dirname, join } from "node:path";

const patches = [
  {
    name: "checkImage grep pattern",
    search: /grep -E "image\/\(png\|jpeg\|jpg\|gif\|webp\)"/g,
    replace: 'grep -E "image/(png|jpeg|jpg|gif|webp|bmp)"',
  },
  {
    name: "wl-paste with BMP to PNG conversion",
    search: "wl-paste --type image/png >",
    replace: "wl-paste --type image/png 2>/dev/null || wl-paste --type image/bmp | magick bmp:- png:- >",
  },
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

let content = readFileSync(cliPath, "utf-8");
let patchedCount = 0;

for (const { name, search, replace } of patches) {
  const isRegex = search instanceof RegExp;
  if (isRegex) search.lastIndex = 0;

  const hasOld = isRegex ? search.test(content) : content.includes(search);
  if (isRegex) search.lastIndex = 0;

  if (content.includes(replace) && !hasOld) {
    console.log(`✓ [${name}] Already patched`);
    continue;
  }

  if (!hasOld) {
    console.log(`⚠ [${name}] Pattern not found, skipping`);
    continue;
  }

  content = content.replaceAll(search, replace);
  patchedCount++;
  console.log(`✓ [${name}] Patched`);
}

if (patchedCount === 0) {
  console.log("\n✓ Nothing to patch");
  process.exit(0);
}

writeFileSync(cliPath, content);

const verify = readFileSync(cliPath, "utf-8");
const allVerified = patches.every(({ name, replace }) => {
  const ok = verify.includes(replace);
  if (!ok) console.error(`❌ [${name}] Verification failed`);
  return ok;
});

if (allVerified) {
  console.log(`\n✓ Patched ${patchedCount} location(s) successfully`);
} else {
  console.error("\n❌ Patch verification failed");
  process.exit(1);
}
