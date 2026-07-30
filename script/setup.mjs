#!/usr/bin/env node

import { createHash } from "node:crypto";
import { readFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { DIVIDER, syncConfig, writeAtomic } from "./sync.mjs";

const DIVIDER_RE = new RegExp(`^${DIVIDER}(?=\\r?$)`, "m");

const HOOK_EVENT_KEYS = new Map([
  ["PreToolUse", "pre_tool_use"],
  ["PermissionRequest", "permission_request"],
  ["PostToolUse", "post_tool_use"],
  ["PreCompact", "pre_compact"],
  ["PostCompact", "post_compact"],
  ["SessionStart", "session_start"],
  ["UserPromptSubmit", "user_prompt_submit"],
  ["SubagentStart", "subagent_start"],
  ["SubagentStop", "subagent_stop"],
  ["Stop", "stop"],
]);

const EVENTS_WITH_MATCHERS = new Set([
  "PreToolUse",
  "PermissionRequest",
  "PostToolUse",
  "PreCompact",
  "PostCompact",
  "SessionStart",
  "SubagentStart",
  "SubagentStop",
]);

const scriptDir = path.dirname(fileURLToPath(import.meta.url));
const codexHome = path.resolve(process.env.CODEX_SETUP_HOME || path.join(scriptDir, ".."));
const sharedConfigPath = path.join(codexHome, "config.shared.toml");
const localConfigPath = path.join(codexHome, "config.toml");

// Setup is the lifecycle entry point: syncConfig owns the shared prefix, while
// this file owns legacy migration and the generated hooks.state suffix sections.
async function main() {
  const sharedConfig = await readFile(sharedConfigPath, "utf8");
  const trustedHooks = discoverCommandHooks(sharedConfig);

  await migrateLegacyConfig(sharedConfig);
  await syncConfig({ codexHome });

  const syncedConfig = await readFile(localConfigPath, "utf8");
  const nextConfig = replaceHooksState(syncedConfig, trustedHooks);

  await writeAtomic(localConfigPath, nextConfig);
  console.log(`updated ${localConfigPath}`);
}

async function readOptionalFile(filePath) {
  try {
    return await readFile(filePath, "utf8");
  } catch (error) {
    if (error?.code === "ENOENT") {
      return null;
    }
    throw error;
  }
}

async function migrateLegacyConfig(sharedConfig) {
  const existingConfig = await readOptionalFile(localConfigPath);
  if (existingConfig === null || DIVIDER_RE.test(existingConfig)) {
    return;
  }

  // syncConfig deliberately refuses to guess the ownership boundary. Setup owns
  // this one-time compatibility path and makes that boundary explicit first.
  const suffix = trimLeadingNewlines(migrateUndividedSuffix(existingConfig, sharedConfig));
  const prefix = `${trimTrailingNewlines(sharedConfig)}\n\n${DIVIDER}\n\n`;
  await writeAtomic(localConfigPath, `${prefix}${suffix}`);
}

function replaceHooksState(syncedConfig, trustedHooks) {
  const dividerMatch = syncedConfig.match(DIVIDER_RE);
  if (!dividerMatch) {
    throw new Error(`sync did not create the expected divider in ${localConfigPath}`);
  }

  const dividerEnd = dividerMatch.index + DIVIDER.length;
  const lineEnding = syncedConfig.startsWith("\r\n", dividerEnd) ? "\r\n" : "\n";
  const prefixThroughDivider = syncedConfig.slice(0, dividerEnd + lineEnding.length);
  const suffix = syncedConfig.slice(dividerEnd + lineEnding.length);
  const trustState = renderTrustState(trustedHooks, localConfigPath, lineEnding);
  const localSuffix = trimLeadingNewlines(removeHooksState(suffix));

  const separatorAfterTrustState = trustState && localSuffix ? lineEnding : "";
  return (
    prefixThroughDivider
    + lineEnding
    + trustState
    + separatorAfterTrustState
    + localSuffix
  );
}

function migrateUndividedSuffix(existingConfig, sharedConfig) {
  const sharedHeaders = new Set(sectionBlocks(sharedConfig).map((block) => block.header));
  const localOnlyBlocks = sectionBlocks(existingConfig)
    .filter((block) => !sharedHeaders.has(block.header))
    .map((block) => block.text.trimEnd())
    .filter(Boolean);

  if (localOnlyBlocks.length === 0) {
    return "";
  }
  return `${localOnlyBlocks.join("\n\n")}\n`;
}

function sectionBlocks(toml) {
  const lines = toml.split(/(?<=\n)/u);
  const blocks = [];
  let current = null;

  for (const line of lines) {
    const header = parseSectionHeader(line);
    if (header) {
      if (current) {
        blocks.push(current);
      }
      current = { header, text: line };
      continue;
    }
    if (current) {
      current.text += line;
    }
  }

  if (current) {
    blocks.push(current);
  }
  return blocks;
}

function parseSectionHeader(line) {
  const trimmed = line.trim();
  if (!trimmed.startsWith("[") || !trimmed.endsWith("]")) {
    return null;
  }
  return trimmed;
}

function removeHooksState(toml) {
  const keptLines = [];
  let removing = false;

  for (const line of toml.split(/(?<=\n)/u)) {
    const header = parseSectionHeader(line);
    if (header) {
      removing = header === "[hooks.state]" || header.startsWith("[hooks.state.");
    }
    if (!removing) {
      keptLines.push(line);
    }
  }
  return keptLines.join("");
}

function renderTrustState(hooks, sourcePath, lineEnding) {
  if (hooks.length === 0) {
    return "";
  }

  const lines = ["[hooks.state]", ""];
  for (const hook of hooks) {
    const key = `${sourcePath}:${hook.keySuffix}`;
    lines.push(`[hooks.state.${tomlBasicString(key)}]`);
    lines.push(`trusted_hash = "${hook.currentHash}"`);
    lines.push("");
  }
  return trimTrailingNewlines(lines.join(lineEnding)) + lineEnding;
}

function tomlBasicString(value) {
  return JSON.stringify(value);
}

function discoverCommandHooks(toml) {
  const groupsByEvent = new Map();
  let currentGroup = null;
  let currentHook = null;

  for (const rawLine of toml.split("\n")) {
    const line = stripInlineComment(rawLine).trim();
    if (!line) {
      continue;
    }

    const groupEvent = parseHooksGroupHeader(line);
    if (groupEvent) {
      currentGroup = { matcher: null, hooks: [] };
      currentHook = null;
      const groups = groupsByEvent.get(groupEvent) || [];
      groups.push(currentGroup);
      groupsByEvent.set(groupEvent, groups);
      continue;
    }

    const hookEvent = parseHookHandlerHeader(line);
    if (hookEvent) {
      const groups = groupsByEvent.get(hookEvent);
      currentGroup = groups?.at(-1) || null;
      currentHook = {};
      currentGroup?.hooks.push(currentHook);
      continue;
    }

    if (parseSectionHeader(line)) {
      currentGroup = null;
      currentHook = null;
      continue;
    }

    const assignment = parseAssignment(line);
    if (!assignment) {
      continue;
    }

    if (currentHook) {
      currentHook[assignment.key] = assignment.value;
      continue;
    }
    if (currentGroup && assignment.key === "matcher") {
      currentGroup.matcher = assignment.value;
    }
  }

  const hooks = [];
  for (const [eventName, groups] of groupsByEvent.entries()) {
    const eventKey = HOOK_EVENT_KEYS.get(eventName);
    if (!eventKey) {
      continue;
    }

    groups.forEach((group, groupIndex) => {
      group.hooks.forEach((hook, handlerIndex) => {
        if (hook.type !== "command") {
          return;
        }
        // Mirror Codex discovery: skip async and blank commands before hashing so we
        // never emit an orphan trust entry that Codex would not register.
        const command = typeof hook.command === "string" ? hook.command : "";
        if (command.trim() === "" || hook.async === true) {
          return;
        }
        // macOS-only bootstrap: commandWindows is intentionally ignored; the hash
        // mirrors Codex's non-Windows identity (host command only).
        const normalizedHook = {
          type: "command",
          command,
          timeout: Math.max(Number(hook.timeout ?? 600), 1),
          async: false,
        };
        if (hook.statusMessage !== undefined) {
          normalizedHook.statusMessage = hook.statusMessage;
        }

        const identity = {
          event_name: eventKey,
          hooks: [normalizedHook],
        };
        if (EVENTS_WITH_MATCHERS.has(eventName) && group.matcher !== null) {
          identity.matcher = group.matcher;
        }

        hooks.push({
          keySuffix: `${eventKey}:${groupIndex}:${handlerIndex}`,
          currentHash: versionForObject(identity),
        });
      });
    });
  }
  return hooks;
}

function parseHooksGroupHeader(line) {
  return line.match(/^\[\[hooks\.([A-Za-z]+)\]\]$/u)?.[1] || null;
}

function parseHookHandlerHeader(line) {
  return line.match(/^\[\[hooks\.([A-Za-z]+)\.hooks\]\]$/u)?.[1] || null;
}

function parseAssignment(line) {
  const match = line.match(/^([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.+)$/u);
  if (!match) {
    return null;
  }
  return { key: match[1], value: parseTomlScalar(match[2].trim()) };
}

function parseTomlScalar(value) {
  if (value === "true") {
    return true;
  }
  if (value === "false") {
    return false;
  }
  if (/^\d+$/u.test(value)) {
    return Number(value);
  }
  if (value.startsWith('"') && value.endsWith('"')) {
    return JSON.parse(value);
  }
  if (value.startsWith("'") && value.endsWith("'")) {
    return value.slice(1, -1).replace(/''/gu, "'");
  }
  return value;
}

function stripInlineComment(line) {
  let quote = null;
  for (let index = 0; index < line.length; index += 1) {
    const char = line[index];
    if (quote === '"' && char === "\\") {
      index += 1;
      continue;
    }
    if ((char === '"' || char === "'") && quote === null) {
      quote = char;
      continue;
    }
    if (char === quote) {
      quote = null;
      continue;
    }
    if (char === "#" && quote === null) {
      return line.slice(0, index);
    }
  }
  return line;
}

function versionForObject(value) {
  const serialized = JSON.stringify(canonicalJson(value));
  return `sha256:${createHash("sha256").update(serialized).digest("hex")}`;
}

function canonicalJson(value) {
  if (Array.isArray(value)) {
    return value.map(canonicalJson);
  }
  if (value && typeof value === "object") {
    return Object.fromEntries(
      Object.keys(value)
        .sort()
        .map((key) => [key, canonicalJson(value[key])]),
    );
  }
  return value;
}

function trimTrailingNewlines(value) {
  return value.replace(/(?:\r?\n)+$/u, "");
}

function trimLeadingNewlines(value) {
  return value.replace(/^(?:\r?\n)+/u, "");
}

main().catch((error) => {
  console.error(error instanceof Error ? error.message : String(error));
  process.exitCode = 1;
});
