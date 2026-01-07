#!/usr/bin/env node
// Patch Claude Code to support image/bmp format in clipboard
// Usage: node image-paste.mjs

import { execSync } from "child_process";
import { readFileSync, writeFileSync, realpathSync } from "fs";

// Patterns to patch - add bmp detection in clipboard check, convert to png for API
// Claude API only supports: image/png, image/jpeg, image/gif, image/webp
// So BMP must be converted to PNG before sending
const patches = [
  {
    name: "checkImage grep pattern",
    // Add bmp to clipboard format detection
    search: /grep -E "image\/\(png\|jpeg\|jpg\|gif\|webp\)"/g,
    replace: 'grep -E "image/(png|jpeg|jpg|gif|webp|bmp)"',
  },
  {
    name: "wl-paste with BMP to PNG conversion",
    // Use ImageMagick to convert BMP to PNG since Claude API doesn't support BMP
    // Only match if not already patched with magick conversion
    search: "wl-paste --type image/png >",
    replace: "wl-paste --type image/png 2>/dev/null || wl-paste --type image/bmp | magick bmp:- png:- >",
  },
];

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

  console.log(`File: ${cliPath}\n`);

  let content = readFileSync(cliPath, "utf-8");
  let patchedCount = 0;

  for (const patch of patches) {
    const isRegex = patch.search instanceof RegExp;

    // Check if pattern exists
    if (isRegex) patch.search.lastIndex = 0;
    const hasOldPattern = isRegex ? patch.search.test(content) : content.includes(patch.search);
    if (isRegex) patch.search.lastIndex = 0;

    // Already patched = has replace string but no old pattern
    if (content.includes(patch.replace) && !hasOldPattern) {
      console.log(`✓ [${patch.name}] Already patched`);
      continue;
    }

    if (!hasOldPattern) {
      console.log(`⚠ [${patch.name}] Pattern not found, skipping`);
      continue;
    }

    content = content.replaceAll(patch.search, patch.replace);
    if (isRegex) patch.search.lastIndex = 0;
    patchedCount++;
    console.log(`✓ [${patch.name}] Patched`);
  }

  if (patchedCount === 0) {
    console.log("\n✓ Nothing to patch");
    process.exit(0);
  }

  writeFileSync(cliPath, content);

  // Verify
  const verify = readFileSync(cliPath, "utf-8");
  let success = true;
  for (const patch of patches) {
    if (!verify.includes(patch.replace)) {
      console.error(`❌ [${patch.name}] Verification failed`);
      success = false;
    }
  }

  if (success) {
    console.log(`\n✓ Patched ${patchedCount} location(s) successfully`);
  } else {
    console.error("\n❌ Patch verification failed");
    process.exit(1);
  }
}

main();
