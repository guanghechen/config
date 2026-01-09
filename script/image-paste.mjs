#!/usr/bin/env node
// Patch Claude Code to support image/bmp format in clipboard
// Usage: node image-paste.mjs
//
// Patches:
// 1. Linux: Add BMP format support for clipboard image detection
// 2. Linux: Add BMP to PNG conversion fallback for wl-paste
// 3. Windows: Change image paste shortcut from Alt+V to Ctrl+V
//    (Useful when terminal uses Alt+V for system clipboard paste)

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
  {
    // Original: hu=TQ()==="windows"?{displayText:`${sB1}+v`,check:(A,Q)=>Q.meta&&...
    // Changed:  hu=TQ()==="windows"?{displayText:"ctrl+v",check:(A,Q)=>Q.ctrl&&...
    // This makes Windows use Ctrl+V instead of Alt+V for image paste
    name: "Windows image paste shortcut (Alt+V -> Ctrl+V)",
    search: /(\w+)=TQ\(\)==="windows"\?\{displayText:`\$\{\w+\}\+v`,check:\((\w+),(\w+)\)=>\3\.meta&&/g,
    replace: (_, varName, arg1, arg2) =>
      `${varName}=TQ()==="windows"?{displayText:"ctrl+v",check:(${arg1},${arg2})=>${arg2}.ctrl&&`,
    verify: 'TQ()==="windows"?{displayText:"ctrl+v",check:',
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

for (const { name, search, replace, verify } of patches) {
  const isRegex = search instanceof RegExp;
  if (isRegex) search.lastIndex = 0;

  const verifyStr = verify || replace;
  const hasOld = isRegex ? search.test(content) : content.includes(search);
  if (isRegex) search.lastIndex = 0;

  if (content.includes(verifyStr) && !hasOld) {
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
const allVerified = patches.every(({ name, replace, verify: verifyStr }) => {
  const ok = verify.includes(verifyStr || replace);
  if (!ok) console.error(`❌ [${name}] Verification failed`);
  return ok;
});

if (allVerified) {
  console.log(`\n✓ Patched ${patchedCount} location(s) successfully`);
} else {
  console.error("\n❌ Patch verification failed");
  process.exit(1);
}
