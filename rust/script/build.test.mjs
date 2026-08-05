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

import { replaceFileAtomically } from "./build.mjs"

function withTempDir(fn) {
  const dir = mkdtempSync(join(tmpdir(), "nvim-build-test-"))
  try {
    fn(dir)
  } finally {
    rmSync(dir, { recursive: true, force: true })
  }
}

test("replaceFileAtomically preserves the inode held by a running process", { skip: process.platform === "win32" }, () => {
  withTempDir((dir) => {
    const source = join(dir, "source.so")
    const destination = join(dir, "destination.so")
    writeFileSync(source, "new artifact")
    writeFileSync(destination, "loaded artifact")

    const loaded = openSync(destination, "r")
    try {
      const loadedInode = fstatSync(loaded).ino
      replaceFileAtomically(source, destination)

      assert.equal(readFileSync(destination, "utf8"), "new artifact")
      assert.notEqual(statSync(destination).ino, loadedInode)
      assert.equal(readFileSync(loaded, "utf8"), "loaded artifact")
    } finally {
      closeSync(loaded)
    }
  })
})

test("replaceFileAtomically removes its temporary file when replacement fails", () => {
  withTempDir((dir) => {
    const source = join(dir, "source.so")
    const destination = join(dir, "destination.so")
    writeFileSync(source, "new artifact")
    mkdirSync(destination)

    assert.throws(() => replaceFileAtomically(source, destination))
    assert.deepEqual(readdirSync(dir).sort(), ["destination.so", "source.so"])
  })
})
