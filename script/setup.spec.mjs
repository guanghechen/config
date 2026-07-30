import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import {
  chmod,
  copyFile,
  mkdir,
  mkdtemp,
  readFile,
  rm,
  stat,
  writeFile,
} from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { test } from "node:test";
import { fileURLToPath } from "node:url";

const DIVIDER = "#".repeat(100);
const SCRIPT_DIRECTORY = path.dirname(fileURLToPath(import.meta.url));

test("syncs the shared prefix before refreshing hooks state", async (t) => {
  const fixture = await createFixture(t);
  const sharedConfig = [
    'model = "new"',
    "",
    "[[hooks.PreToolUse]]",
    'matcher = "Bash"',
    "",
    "[[hooks.PreToolUse.hooks]]",
    'type = "command"',
    'command = "node script/check.mjs"',
    "timeout = 30",
    "",
  ].join("\n");
  const localSuffix = '[local]\r\nvalue = "keep"\r\n';
  const existingConfig = [
    'model = "old"',
    "",
    DIVIDER,
    "",
    "[hooks.state]",
    "",
    '[hooks.state."stale"]',
    'trusted_hash = "sha256:stale"',
    "",
    localSuffix,
  ].join("\r\n");
  await writeFile(fixture.sharedConfigPath, sharedConfig);
  await writeFile(fixture.localConfigPath, existingConfig);
  await chmod(fixture.localConfigPath, 0o640);

  const result = runSetup(fixture);

  assert.equal(result.status, 0, result.stderr);
  const actual = await readFile(fixture.localConfigPath, "utf8");
  assert.ok(actual.startsWith(`${sharedConfig.trimEnd()}\n\n${DIVIDER}\r\n\r\n`));
  assert.match(actual, /^\[hooks\.state\]$/m);
  assert.match(actual, /trusted_hash = "sha256:[a-f0-9]{64}"/);
  assert.doesNotMatch(actual, /sha256:stale/);
  assert.ok(actual.endsWith(localSuffix));
  assert.equal((await stat(fixture.localConfigPath)).mode & 0o7777, 0o640);
});

test("migrates an undivided config before invoking strict sync", async (t) => {
  const fixture = await createFixture(t);
  const sharedConfig = [
    'model = "new"',
    "",
    "[features]",
    "hooks = true",
    "",
  ].join("\n");
  const existingConfig = [
    'model = "old"',
    "",
    "[features]",
    "hooks = false",
    "",
    "[local]",
    'value = "keep"',
    "",
  ].join("\n");
  await writeFile(fixture.sharedConfigPath, sharedConfig);
  await writeFile(fixture.localConfigPath, existingConfig);

  const result = runSetup(fixture);

  assert.equal(result.status, 0, result.stderr);
  assert.equal(
    await readFile(fixture.localConfigPath, "utf8"),
    `${sharedConfig.trimEnd()}\n\n${DIVIDER}\n\n[local]\nvalue = "keep"\n`,
  );
});

test("leaves config.toml unchanged when hook discovery fails", async (t) => {
  const fixture = await createFixture(t);
  const sharedConfig = [
    'model = "new"',
    "",
    "[[hooks.PreToolUse]]",
    "",
    "[[hooks.PreToolUse.hooks]]",
    'type = "command"',
    'command = "\\q"',
    "",
  ].join("\n");
  const existingConfig = `model = "old"\n\n${DIVIDER}\n\n[local]\nvalue = "keep"\n`;
  await writeFile(fixture.sharedConfigPath, sharedConfig);
  await writeFile(fixture.localConfigPath, existingConfig);

  const result = runSetup(fixture);

  assert.notEqual(result.status, 0);
  assert.equal(await readFile(fixture.localConfigPath, "utf8"), existingConfig);
});

async function createFixture(t) {
  const temporaryRoot = await mkdtemp(path.join(os.tmpdir(), "codex-setup-test-"));
  t.after(() => rm(temporaryRoot, { recursive: true, force: true }));

  const scriptDirectory = path.join(temporaryRoot, "script");
  await mkdir(scriptDirectory);
  await Promise.all([
    copyFile(path.join(SCRIPT_DIRECTORY, "setup.mjs"), path.join(scriptDirectory, "setup.mjs")),
    copyFile(path.join(SCRIPT_DIRECTORY, "sync.mjs"), path.join(scriptDirectory, "sync.mjs")),
  ]);

  return {
    temporaryRoot,
    setupScriptPath: path.join(scriptDirectory, "setup.mjs"),
    sharedConfigPath: path.join(temporaryRoot, "config.shared.toml"),
    localConfigPath: path.join(temporaryRoot, "config.toml"),
  };
}

function runSetup(fixture) {
  return spawnSync(process.execPath, [fixture.setupScriptPath], {
    encoding: "utf8",
    env: { ...process.env, CODEX_SETUP_HOME: fixture.temporaryRoot },
  });
}
