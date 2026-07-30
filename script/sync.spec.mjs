import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import {
  chmod,
  copyFile,
  mkdir,
  mkdtemp,
  readFile,
  readdir,
  rm,
  stat,
  writeFile,
} from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { test } from "node:test";
import { fileURLToPath } from "node:url";

const DIVIDER = "#".repeat(100);
const SOURCE_SCRIPT_PATH = fileURLToPath(new URL("./sync.mjs", import.meta.url));

test(
  "replaces only the shared prefix and preserves the first divider onward",
  async (t) => {
    const fixture = await createFixture(t);
    const suffix = [
      DIVIDER,
      "",
      "[local]",
      'value = "keep"',
      "",
      DIVIDER,
      "second = true",
    ].join("\r\n");
    await writeFile(fixture.sharedConfigPath, "model = \"new\"\n\n");
    await writeFile(fixture.localConfigPath, `model = "old"\r\n\r\n${suffix}`);
    await chmod(fixture.localConfigPath, 0o600);

    const result = runSync(fixture.scriptPath);

    assert.equal(result.status, 0, result.stderr);
    const actual = await readFile(fixture.localConfigPath, "utf8");
    assert.equal(actual, `model = "new"\n\n${suffix}`);
    assert.equal((await stat(fixture.localConfigPath)).mode & 0o7777, 0o600);
  },
);

test("creates config.toml with a private mode when it does not exist", async (t) => {
  const fixture = await createFixture(t);
  await writeFile(fixture.sharedConfigPath, "model = \"new\"\n");

  const result = runSync(fixture.scriptPath);

  assert.equal(result.status, 0, result.stderr);
  assert.equal(
    await readFile(fixture.localConfigPath, "utf8"),
    `model = "new"\n\n${DIVIDER}\n\n`,
  );
  assert.equal((await stat(fixture.localConfigPath)).mode & 0o7777, 0o600);
});

test("leaves an undivided config.toml unchanged", async (t) => {
  const fixture = await createFixture(t);
  const originalConfig = "local_only = true\n";
  await writeFile(fixture.sharedConfigPath, "model = \"new\"\n");
  await writeFile(fixture.localConfigPath, originalConfig);

  const result = runSync(fixture.scriptPath);

  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /exactly 100/);
  assert.equal(await readFile(fixture.localConfigPath, "utf8"), originalConfig);
  assert.deepEqual(await temporaryFiles(fixture), []);
});

test("leaves config.toml unchanged when the divider has no following blank line", async (t) => {
  const fixture = await createFixture(t);
  const originalConfig = `${DIVIDER}\n[local]\n`;
  await writeFile(fixture.sharedConfigPath, "model = \"new\"\n");
  await writeFile(fixture.localConfigPath, originalConfig);

  const result = runSync(fixture.scriptPath);

  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /followed by a blank line/);
  assert.equal(await readFile(fixture.localConfigPath, "utf8"), originalConfig);
  assert.deepEqual(await temporaryFiles(fixture), []);
});

async function createFixture(t) {
  const temporaryRoot = await mkdtemp(path.join(os.tmpdir(), "codex-sync-test-"));
  t.after(() => rm(temporaryRoot, { recursive: true, force: true }));

  const scriptPath = path.join(temporaryRoot, "script", "sync.mjs");
  await mkdir(path.dirname(scriptPath));
  await copyFile(SOURCE_SCRIPT_PATH, scriptPath);

  return {
    temporaryRoot,
    scriptPath,
    sharedConfigPath: path.join(temporaryRoot, "config.shared.toml"),
    localConfigPath: path.join(temporaryRoot, "config.toml"),
  };
}

function runSync(scriptPath) {
  return spawnSync(process.execPath, [scriptPath], { encoding: "utf8" });
}

async function temporaryFiles(fixture) {
  const names = await readdir(fixture.temporaryRoot);
  return names.filter(
    (name) => name.startsWith("config.toml.") && name.endsWith(".tmp"),
  );
}
