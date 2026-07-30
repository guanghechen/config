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
import { renderSharedConfig } from "./sync.mjs";

const DIVIDER = "#".repeat(100);
const SOURCE_SCRIPT_PATH = fileURLToPath(new URL("./sync.mjs", import.meta.url));

test("renders HOME in TOML strings and leaves comments and unknown symbols unchanged", () => {
  const source = [
    'basic = "${HOME}/basic"',
    "literal = '${HOME}/literal'",
    'codex = "${CODEX_HOME}/config"',
    'unknown = "${TOKEN}"',
    "# ${HOME}",
  ].join("\n");

  const actual = renderSharedConfig(source, {
    environment: { CODEX_HOME: "/opt/codex", HOME: "/home/alice" },
    platform: "linux",
  });

  assert.equal(actual, [
    'basic = "/home/alice/basic"',
    "literal = '/home/alice/literal'",
    'codex = "/opt/codex/config"',
    'unknown = "${TOKEN}"',
    "# ${HOME}",
  ].join("\n"));
});

test("renders USERPROFILE with TOML-safe escaping on Windows", () => {
  const source = [
    'basic = "${HOME}/config"',
    "literal = '${HOME}/config'",
  ].join("\n");

  const actual = renderSharedConfig(source, {
    environment: { HOME: "/wrong", USERPROFILE: "C:\\Users\\Alice" },
    platform: "win32",
  });

  assert.equal(actual, [
    'basic = "C:\\\\Users\\\\Alice/config"',
    "literal = 'C:\\Users\\Alice/config'",
  ].join("\n"));
});

test("renders symbols after multiline strings ending with four quotes", () => {
  const source = [
    'basic = """${HOME}""""',
    "literal = '''${HOME}''''",
    'after = "${HOME}/after"',
  ].join("\n");

  const actual = renderSharedConfig(source, {
    environment: { HOME: "/home/alice" },
    platform: "linux",
  });

  assert.equal(actual, [
    'basic = """/home/alice""""',
    "literal = '''/home/alice''''",
    'after = "/home/alice/after"',
  ].join("\n"));
});

test("rejects a supported symbol outside a TOML string", () => {
  assert.throws(
    () => renderSharedConfig("path = ${HOME}\n", {
      environment: { HOME: "/home/alice" },
      platform: "linux",
    }),
    /must appear inside a TOML string/,
  );
});

test("rejects CODEX_HOME when its environment variable is missing", () => {
  assert.throws(
    () => renderSharedConfig('path = "${CODEX_HOME}/config"\n', {
      environment: { HOME: "/home/alice" },
      platform: "linux",
    }),
    /CODEX_HOME is not set/,
  );
});

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

test("leaves config.toml unchanged when the HOME environment variable is missing", async (t) => {
  const fixture = await createFixture(t);
  const originalConfig = `model = "old"\n\n${DIVIDER}\n\n[local]\nvalue = "keep"\n`;
  const environment = { ...process.env };
  delete environment.HOME;
  delete environment.USERPROFILE;
  await writeFile(fixture.sharedConfigPath, 'path = "${HOME}/config"\n');
  await writeFile(fixture.localConfigPath, originalConfig);

  const result = runSync(fixture.scriptPath, environment);

  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /(?:HOME|USERPROFILE) is not set/);
  assert.equal(await readFile(fixture.localConfigPath, "utf8"), originalConfig);
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

function runSync(scriptPath, environment = process.env) {
  return spawnSync(process.execPath, [scriptPath], {
    encoding: "utf8",
    env: environment,
  });
}

async function temporaryFiles(fixture) {
  const names = await readdir(fixture.temporaryRoot);
  return names.filter(
    (name) => name.startsWith("config.toml.") && name.endsWith(".tmp"),
  );
}
