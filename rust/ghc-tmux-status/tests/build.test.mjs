// Run with: node --test rust/ghc-tmux-status/tests/build.test.mjs
import assert from "node:assert/strict"
import {
  chmodSync,
  closeSync,
  fstatSync,
  mkdirSync,
  mkdtempSync,
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

import { rendererInputs, replaceFileIfChanged, verifyRenderer } from "../../../script/build.mjs"

function withTempDir(fn) {
  const dir = mkdtempSync(join(tmpdir(), "tmux-build-test-"))
  try {
    fn(dir)
  } finally {
    rmSync(dir, { recursive: true, force: true })
  }
}

function writeRenderer(filepath, body) {
  writeFileSync(filepath, `#!/bin/sh\n${body}\n`)
  chmodSync(filepath, 0o755)
}

test("verifyRenderer accepts a renderer reporting the expected protocol", () => {
  withTempDir((dir) => {
    const renderer = join(dir, "renderer")
    writeRenderer(renderer, '[ "$1" = protocol ] && echo 7')

    verifyRenderer(renderer, "7")
  })
})

test("verifyRenderer rejects a renderer built for another protocol", () => {
  withTempDir((dir) => {
    const renderer = join(dir, "renderer")
    writeRenderer(renderer, "echo 6")

    assert.throws(() => verifyRenderer(renderer, "7"), /reports protocol "6", expected "7"/)
  })
})

test("verifyRenderer rejects a renderer without the protocol command", () => {
  withTempDir((dir) => {
    const renderer = join(dir, "old renderer")
    writeRenderer(renderer, 'echo "unknown command: $1" >&2; exit 1')

    assert.throws(() => verifyRenderer(renderer, "1"), (error) => {
      assert.equal(error.exitCode, 1)
      assert.match(error.message, /old renderer/)
      assert.match(error.message, /unknown command: protocol/)
      return true
    })
  })
})

test("rendererInputs covers the crate and protocol but not build output", () => {
  withTempDir((dir) => {
    const crate = join(dir, "rust", "ghc-tmux-status")
    mkdirSync(join(crate, "src"), { recursive: true })
    mkdirSync(join(crate, "target", "release"), { recursive: true })
    mkdirSync(join(dir, "script"))
    writeFileSync(join(crate, "src", "main.rs"), "fn main() {}\n")
    writeFileSync(join(dir, "script", "renderer-protocol"), "1\n")
    writeFileSync(join(dir, "script", "load-theme.sh"), "")

    const inputs = rendererInputs(dir)
    assert.deepEqual(Object.keys(inputs.files), [
      "rust/ghc-tmux-status/src/main.rs",
      "script/renderer-protocol",
    ])

    writeFileSync(join(crate, "target", "release", "ghc-tmux-status"), "artifact")
    assert.equal(rendererInputs(dir).sha256, inputs.sha256)

    writeFileSync(join(dir, "script", "renderer-protocol"), "2\n")
    assert.notEqual(rendererInputs(dir).sha256, inputs.sha256)
  })
})

test("replaceFileIfChanged preserves the inode held by a running process", () => {
  withTempDir((dir) => {
    const source = join(dir, "source")
    const destination = join(dir, "destination")
    writeFileSync(source, "new artifact")
    writeFileSync(destination, "running artifact")

    const running = openSync(destination, "r")
    try {
      const runningInode = fstatSync(running).ino
      assert.equal(replaceFileIfChanged(source, destination), true)

      assert.equal(readFileSync(destination, "utf8"), "new artifact")
      assert.notEqual(statSync(destination).ino, runningInode)
      assert.equal(readFileSync(running, "utf8"), "running artifact")
    } finally {
      closeSync(running)
    }
  })
})

test("replaceFileIfChanged keeps the executable mode", () => {
  withTempDir((dir) => {
    const source = join(dir, "source")
    const destination = join(dir, "destination")
    writeRenderer(source, "exit 0")

    assert.equal(replaceFileIfChanged(source, destination), true)
    assert.equal(statSync(destination).mode & 0o777, 0o755)
  })
})

test("replaceFileIfChanged skips an identical destination", () => {
  withTempDir((dir) => {
    const source = join(dir, "source")
    const destination = join(dir, "destination")
    writeFileSync(source, "same artifact")
    writeFileSync(destination, "same artifact")

    const destinationInode = statSync(destination).ino
    assert.equal(replaceFileIfChanged(source, destination), false)
    assert.equal(statSync(destination).ino, destinationInode)
    assert.deepEqual(readdirSync(dir).sort(), ["destination", "source"])
  })
})

test("replaceFileIfChanged replaces an identical destination when forced", () => {
  withTempDir((dir) => {
    const source = join(dir, "source")
    const destination = join(dir, "destination")
    writeFileSync(source, "same artifact")
    writeFileSync(destination, "same artifact")

    const destinationInode = statSync(destination).ino
    assert.equal(replaceFileIfChanged(source, destination, { force: true }), true)
    assert.notEqual(statSync(destination).ino, destinationInode)
    assert.deepEqual(readdirSync(dir).sort(), ["destination", "source"])
  })
})

test("replaceFileIfChanged removes its temporary file when replacement fails", () => {
  withTempDir((dir) => {
    const source = join(dir, "source")
    const destination = join(dir, "destination")
    writeFileSync(source, "new artifact")
    mkdirSync(destination)

    assert.throws(() => replaceFileIfChanged(source, destination))
    assert.deepEqual(readdirSync(dir).sort(), ["destination", "source"])
  })
})
