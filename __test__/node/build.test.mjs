// Run with: node --test __test__/node/build.test.mjs
import assert from "node:assert/strict"
import {
  closeSync,
  fstatSync,
  mkdtempSync,
  mkdirSync,
  openSync,
  readFileSync,
  readdirSync,
  rmSync,
  statSync,
  writeFileSync,
} from "node:fs"
import { tmpdir } from "node:os"
import { join } from "node:path"
import test from "node:test"

import { findWindowsSdkLibraries, isWslRuntime, replaceFileIfChanged } from "../../script/build.mjs"

function withTempDir(fn) {
  const dir = mkdtempSync(join(tmpdir(), "nvim-build-test-"))
  try {
    fn(dir)
  } finally {
    rmSync(dir, { recursive: true, force: true })
  }
}

test("replaceFileIfChanged preserves the inode held by a running process", { skip: process.platform === "win32" }, () => {
  withTempDir((dir) => {
    const source = join(dir, "source.so")
    const destination = join(dir, "destination.so")
    writeFileSync(source, "new artifact")
    writeFileSync(destination, "loaded artifact")

    const loaded = openSync(destination, "r")
    try {
      const loadedInode = fstatSync(loaded).ino
      assert.equal(replaceFileIfChanged(source, destination), true)

      assert.equal(readFileSync(destination, "utf8"), "new artifact")
      assert.notEqual(statSync(destination).ino, loadedInode)
      assert.equal(readFileSync(loaded, "utf8"), "loaded artifact")
    } finally {
      closeSync(loaded)
    }
  })
})

test("replaceFileIfChanged skips an identical destination", () => {
  withTempDir((dir) => {
    const source = join(dir, "source.so")
    const destination = join(dir, "destination.so")
    writeFileSync(source, "same artifact")
    writeFileSync(destination, "same artifact")

    const destinationInode = statSync(destination).ino
    assert.equal(replaceFileIfChanged(source, destination), false)
    assert.equal(statSync(destination).ino, destinationInode)
    assert.deepEqual(readdirSync(dir).sort(), ["destination.so", "source.so"])
  })
})

test("replaceFileIfChanged removes its temporary file when replacement fails", () => {
  withTempDir((dir) => {
    const source = join(dir, "source.so")
    const destination = join(dir, "destination.so")
    writeFileSync(source, "new artifact")
    mkdirSync(destination)

    assert.throws(() => replaceFileIfChanged(source, destination))
    assert.deepEqual(readdirSync(dir).sort(), ["destination.so", "source.so"])
  })
})

test("findWindowsSdkLibraries selects the newest complete x64 SDK", () => {
  withTempDir((dir) => {
    const older = join(dir, "10.0.22000.0", "um", "x64")
    const newer = join(dir, "10.0.22621.0", "um", "x64")
    const incomplete = join(dir, "10.0.26100.0", "um", "x64")
    mkdirSync(older, { recursive: true })
    mkdirSync(newer, { recursive: true })
    mkdirSync(incomplete, { recursive: true })
    writeFileSync(join(older, "kernel32.lib"), "")
    writeFileSync(join(older, "user32.lib"), "")
    writeFileSync(join(newer, "Kernel32.Lib"), "")
    writeFileSync(join(newer, "User32.Lib"), "")
    writeFileSync(join(incomplete, "kernel32.lib"), "")

    const sdk = findWindowsSdkLibraries(dir)
    assert.equal(sdk.version, "10.0.22621.0")
    assert.equal(sdk.kernel32, join(newer, "Kernel32.Lib"))
    assert.equal(sdk.user32, join(newer, "User32.Lib"))
  })
})

test("isWslRuntime matches environment and kernel detection", () => {
  assert.equal(isWslRuntime({ WSL_INTEROP: "/run/WSL/1_interop" }, "6.8.0-generic"), true)
  assert.equal(isWslRuntime({ WSL_DISTRO_NAME: "Ubuntu" }, "6.8.0-generic"), true)
  assert.equal(isWslRuntime({}, "6.18.33.2-microsoft-standard-WSL2"), true)
  assert.equal(isWslRuntime({}, "4.4.0-19041-Microsoft"), true)
  assert.equal(isWslRuntime({}, "6.8.0-generic"), false)
})
