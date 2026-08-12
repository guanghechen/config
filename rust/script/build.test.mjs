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

import { replaceFileIfChanged } from "./build.mjs"

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
